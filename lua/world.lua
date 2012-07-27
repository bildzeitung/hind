--[[
	world.lua
	
	Created JUL-23-2012
]]

local Object = (require 'object').Object

require 'inventory_actor'
require 'static_actor'
require 'actor_item'
require 'actor'

local pq = require 'priority_queue'

local factories = require 'factories'
require 'thread_communicator'

require 'renderer'

--	@TODO this is required only because we aren't doing
--  real procedural generation yet!
require 'dialog_generator'

local marshal = require 'marshal'

local log = require 'log'

local pairs, ipairs, type, table, math, tostring, tonumber, love, collectgarbage, string
	= pairs, ipairs, type, table, math, tostring, tonumber, love, collectgarbage, string
			
module('objects')

World = Object{ _init = { '_profiler' } }

World.largeFont = love.graphics.newFont(24)
World.smallFont = love.graphics.newFont(12)
World.saveActorsPerFrame = 1
World.loadActorsPerFrame = 1
World.actorsToCleanPerFrame = 1

--
--  World constructor
--
function World:_clone(values)
	local o = Object._clone(self,values)
			
	o._renderer = Renderer{}
	o._visibleIds = {}
	o._visibleActors = {}	
	o._visibleObjects = {}
	o._floatingTexts = {}		
	
	o._zoom = 1
	o._showCollisionBoundaries = false	
	o._drawInfoText = true			

	-- actors that are to be permanent removed from
	-- the game world
	o._removals = {}	
	-- actors that still need to be saved to disk
	-- at the rate of saveActorsPerFrame per frame
	o._actorsToSave = {}
	-- actors that are in memory waiting for their	
	-- corresponding map cells to be loaded
	o._actorsToRegister = {}
	-- functions that should be executed
	-- on actors when they are loaded
	o._functionsOnLoad = {}
	-- actors that are being loaded just to
	-- execute functions on them and then
	-- save them again
	o._actorsBeingCleanedUp = {}
	-- timed functions that have been scheduled
	o._timedEvents = pq.new()
	
	local thread = love.thread.getThread('fileio')
	o._communicator = ThreadCommunicator{ thread }

	return o
end

--
--  Sets actors to be loaded so that any
--  functions that need to be executed on them
--  will be executed
--
function World:cleanUpActorFunctions()
	local actorsCleanedUp = 0
	for id, _ in pairs(self._functionsOnLoad) do
		self._actorsBeingCleanedUp[id] = true
		self._communicator:send('loadActor',id)
		
		actorsCleanedUp = actorsCleanedUp + 1
		if actorsCleanedUp >= World.actorsToCleanPerFrame then
			break
		end
	end
end

--
--  Adds a function to the list of functions to perform when 
--	an actor is loaded
--
function World:addFunctionOnLoad(id, fn)
	if not self._functionsOnLoad[id] then
		self._functionsOnLoad[id] = {}
	end
	
	table.insert(self._functionsOnLoad[id], fn)
end

--
--  Performs all of the functions for a given
--  actor id
--
function World:performOnLoadFunctions(actor)
	if not self._functionsOnLoad[actor._id] then return end
	for _, fn in ipairs(self._functionsOnLoad[actor._id]) do
		fn(actor)		
	end
	self._functionsOnLoad[actor._id] = nil
end

--
--  Add a timed event to the world. After ms ms fn will be executed 
--  with this as argument
--
--  Inputs:
--		ms - the number of milliseconds from now to execute the function
--		fn - the function to execute
--		id - id of the actor making the request (or nil)
--
function World:timer(ms, fn, id)
	local executionTime = love.timer.getMicroTime() + (ms / 1000)
	self._timedEvents:push({fn, id}, executionTime)
end

--
--  Fires any timed events that are equal to or past their execution time
--
--	See notes re: World:timer for discussion on using a
--	priority queue here
--
function World:executeTimedEvents()
	local notReady
	repeat
		if self._timedEvents:isempty() then break end
		notReady = true
		local t, ms = self._timedEvents:pop()
		if ms <= love.timer.getMicroTime() then
			notReady = false
			local fn = t[1]
			local id = t[2]			
			if id then
				local actor = self:actor(id)
				if not actor then
					self:addFunctionOnLoad(id, fn)
				else
					fn(actor)
				end
			else
				fn()
			end
		else
			self._timedEvents:push(t,ms)
		end		
	until notReady 
end

--
--  Saves an actor to disk using fileio thread
--
function World:saveActor(actor)
	local s = marshal.encode(actor)
	self._communicator:send('saveActor',actor._id)
	self._communicator:send('saveActor',s)
end

--
--  Loads an actor from disk using fileio thread
--
function World:loadActor(id)
	self._communicator:send('loadActor',id)
end

--
--  Receives any actors that have been loaded
--	by the file io thread
--
function World:receiveLoadedActors()
	local actorsLoaded = 0
	local received = false
	repeat
		received = false
		local s = self._communicator:receive('loadedActor')
		if s then
			received = true
			local actor = marshal.decode(s)
			
			-- perform any actions that have been waiting for this actor
			self:performOnLoadFunctions(actor)
			
			-- was this actor loaded just to clean up functions that needed
			-- to be executed?
			if self._actorsBeingCleanedUp[actor._id] then
				-- save the actor again
				self._actorsToSave[actor._id] = actor
				-- no need to clean up this actor anymore
				self._actorsBeingCleanedUp[actor._id] = nil
			else			
				-- if an actor wanders off the currently loaded map
				-- it needs to be saved to disk and added to cell that it wandered
				-- off to
				actor.on_no_buckets = function(actor)
					self:addActorToCell(actor)
				end
				
				-- update the actor and register it in collision buckets
				actor:update(0)
				actor:registerBuckets(self._map._buckets)
			end
						
			actorsLoaded = actorsLoaded + 1
			if actorsLoaded >= World.loadActorsPerFrame then 
				break
			end
		end
	until not received 
end

--
--  Adds an actor to the register table
-- 
function World:addActorToRegister(actor,hash)
	if not self._actorsToRegister[hash] then
		self._actorsToRegister[hash] = { actor }
	else
		table.insert(self._actorsToRegister[hash], actor)	
	end
end

--
--  Adds an actor to a map cell
--
function World:addActorToCell(actor)
	-- figure out the new map cell
	-- hash value for this actor
	local tileX, tileY = 
		self._map:posToTile(actor._boundary[1], actor._boundary[2])
	local hash = Map.hash(tileX, tileY)
	
	-- is this map cell being loaded 
	if self._map._cellsLoading[hash] then
		-- the map cell is being loaded already so just
		-- register the actor again when the map cell is loaded
		self:addActorToRegister(actor, hash)
	else	
		-- save the actor 
		self._actorsToSave[actor._id] = actor
		self:disposeActor(actor)						

		-- add the actor to the cell
		self._communicator:send('addActorToCell',actor._id)	
		self._communicator:send('addActorToCell',hash)
	end
end


--
--  Returns true if an actor exists in the game world
--	false otherwise
--
function World:actor(id)
	return self._visibleActors[id]
end

--
--  Returns a table of actors that are close to the
--	supplied actor
--
function World:closeActors(actor, filter)
	local as = {}
	
	local filter = filter or function(v)
		return v._id and v._id ~= actor._id and not v._actor
	end
	
	for k, v in pairs(actor._bucketIds) do
		for id, other in pairs(self._map._buckets[k]) do
			if filter(other) then
				as[#as+1] = other
			end
		end
	end
	
	return as
end

--
--  Returns the actor that is closest to the
--	supplied actor and the distance to the closest actor
--
function World:closestActor(actor)
	local as = self:closeActors(actor)
	local closestActor
	local minDistance = math.huge
	for k, v in ipairs(as) do
		local distance = actor:distanceFrom(v)
		if distance < minDistance then
			minDistance = distance
			closestActor = v
		end
	end
	
	return closestActor, minDistance
end

--
--  Initialize the world
--
--	@TODO replace this with actual procedural generation
--
function World:initialize()
	local width, height, fullscreen, vsync, fsaa = love.graphics.getMode( )
	self._camera = factories.createCamera()
	self._camera:window(500000*32,500000*32,width,height)
	self._camera:viewport(0,0,width,height)
	
	self._terrainGenerator = factories.createTerrainGenerator('outdoor')		
	self._terrainGenerator:generate(499904,499904,256,256)
	self._terrainGenerator:generate(500160,499904,256,256)
	
	self._map = factories.createMap('outdoor')	
	
	self._map.on_cell_dispose = function(map, mc)
		-- look at the ids that are going to be removed
		for k, _ in pairs(mc._bucketIds) do
			if map._buckets['count' .. k] == 1 then
				-- get rid of visible actors and objects that were in 
				-- the buckets that will be disposed
				for _, v in pairs(map._buckets[k]) do
					if v._id then
						self._actorsToSave[v._id] = v
						self:disposeActor(v)
					end
				end
			end		
		end			
	end
	
	self._map.on_cell_load = function(map, mc)
		-- load all of the actors saved in this map cell
		for i = 1, #mc._actors do
			local id = mc._actors[i]
			if not self:actor(id) then
				-- if actors were being loaded just to
				-- clean up their functions then
				-- we want them for real now!
				self._actorsBeingCleanedUp[id] = nil
				-- load the actor
				self:loadActor(id)
			end
		end
		-- register all of the actors that were not saved to the cell
		-- because they wandered into the cell's space as it was loading
		if self._actorsToRegister[mc._hash] then
			for _, actor in ipairs(self._actorsToRegister[mc._hash]) do
				actor:update(0)
				actor:registerBuckets(self._map._buckets)
			end
			self._actorsToRegister[mc._hash] = nil
		end
	end	
	
	self:createHero()
	
	--@TODO in a cave with a flashlight or similar
	--[[
	setSpotLight{ idx = 1, pos = {400,300} },
								size = {300,225},
								angle = {0,6.3},
								color = {2,2,2} }
	]]
end

--
--  Create a hero
--  
function World:createHero()
	local hero = InventoryActor.create('content/actors/hero.dat')
	
	for k, v in pairs(hero._attributes) do
		hero['_'..k] = v
		hero[k] = function(hero, value, absolute)
			if not value then
				return hero['_'..k]
			end
			
			if absolute then
				hero['_'..k] = value
			else
				hero['_'..k] = hero['_'..k] + value
			end
			
			if hero['on_set_' .. k]  then
				return hero['on_set_' .. k](hero, hero['_'..k], value) 
			end
		end
	end	
	hero._attributes = nil
	
	for k, v in pairs(hero._personality) do
		hero['_'..k] = 0		
		hero[k] = function(hero, value, absolute)
			if not value then
				return hero['_'..k]
			end
			
			if absolute then
				hero['_'..k] = value
			else
				hero['_'..k] = hero['_'..k] + value
			end
			
			if hero['on_set_' .. k]  then
				return hero['on_set_' .. k](hero, hero['_'..k], value) 
			end
		end
	end
	
	hero:name('Sir Gallahad')
	local chainArmour = ActorItem.create('content/actors/chain_armour.dat')
	local chainHelmet = ActorItem.create('content/actors/chain_helmet.dat')
	local plateShoes = ActorItem.create('content/actors/plate_shoes.dat')
	local platePants = ActorItem.create('content/actors/plate_pants.dat')
	local longSword = ActorItem.create('content/actors/longsword.dat')

	hero:addItem(longSword)
	hero:addItem(platePants)
	hero:addItem(plateShoes)
	hero:addItem(chainHelmet)
	hero:addItem(chainArmour)	
	
	hero:animation('standright')	
	
	--[[
	hero:equipItem('weapon',longSword)		
	hero:equipItem('legs',platePants)	
	hero:equipItem('head',chainHelmet)	
	hero:equipItem('torso',chainArmour)	
	hero:equipItem('feet',plateShoes)	
	]]
	
	hero.on_set_greed = function(hero, newValue, justSet)
		self:createFloatingText({0,255,255,255}, hero, 'Greed: ' .. justSet)
	end
	
	hero.on_set_likeable = function(hero, newValue, justSet)
		self:createFloatingText({0,255,255,255}, hero, 'Likeable: ' .. justSet)
	end	

	hero.on_set_luck = function(hero, newValue, justSet)
		self:createFloatingText({0,255,255,255}, hero, 'Luck: ' .. justSet)
	end	
	
	--[[
	-- give the hero items that will complete the dialogs
	table.insert(hero._inventory, { name = 'questItem_Bilbo_puppy'})
	table.insert(hero._inventory, { name = 'questItem_Bilbo_kitten'})
	table.insert(hero._inventory, { name = 'questItem_Bilbo_mojo'})
	table.insert(hero._inventory, { name = 'questItem_Bilbo_mind'})
	]]
	
	-- put the hero in the middle of the map for fun
	local tileX = 500032
	local tileY = 500032
	local ts = self._map._tileSet:size()	
	hero:position(tileX*ts[1], tileY*ts[2])
	hero:update(0.16)
	local hash = Map.hash(tileX, tileY)
	self._actorsToRegister[hash] = { hero }		
	
	hero.on_no_buckets = function(actor)
		local tileX, tileY = 
			self._map:posToTile(actor._boundary[1], actor._boundary[2])
		local hash = Map.hash(tileX, tileY)
		self:addActorToRegister(actor, hash)
	end
	
	self._hero = hero		
end

--
--  Draw the world
--
function World:draw()
	self._renderer:draw( 
		self._camera, 
		{ 	
			floatingTexts = self._floatingTexts, map = self._map,
			actors = self._visibleActors, objects = self._visibleObjects 
		}, 
		self._profiler )
	
	-- draw collision boundaries?		
	self._profiler:profile('drawing collision boundaries',
		function()
			if self._showCollisionBoundaries then
				local cw = self._camera:window()
				for k, _ in pairs(self._visibleIds) do
					for _, v in pairs(self._map._buckets[k]) do
						if v._boundary then
							local b = v._boundary
							love.graphics.rectangle('line', b[1] - cw[1], b[2] - cw[2], b[3] - b[1], b[4] - b[2])

							if v._equipped then
								for _, item in pairs(v._equipped) do
									local b = item._boundary
									love.graphics.rectangle('line', b[1] - cw[1], b[2] - cw[2], b[3] - b[1], b[4] - b[2])
								end						
							end
						end			
					end
				end		
			end
		end)
	
	love.graphics.print('FPS: '..love.timer.getFPS(), 10, 70)	
	love.graphics.print('MEMORY IN USE '.. string.format('%.2f', collectgarbage('count')), 10, 85)			
				
	-- draw info text
	self._profiler:profile('drawing info text', 	
		function()		
			if self._drawInfoText then
				love.graphics.setColor(255,255,255,255)		
				love.graphics.setPixelEffect()
				
				love.graphics.setFont(World.largeFont)
				love.graphics.print('HEALTH: ' .. self._hero:health() .. '/' .. self._hero._maxHealth, 10, 10)			
				love.graphics.print('GOLD: ' .. self._hero:gold(), 250, 10)
				love.graphics.print('EXPERIENCE: ' .. self._hero:experience(), 500, 10)			
				love.graphics.print('SPELL: ' .. self._hero._spells[self._hero._currentSpell][2], 0, 40)						
				love.graphics.print('MANA: ' .. self._hero:mana(), 250, 40)
				love.graphics.print('COST: ' .. self._hero._spells[self._hero._currentSpell][3], 500, 40)						
				
				love.graphics.setFont(World.smallFont)		

				local y = 105
				love.graphics.print('VISIBLE ID: '..table.count(self._visibleIds), 10, y)		
				y = y + 20			
				love.graphics.print('CELLS IN MEMORY '..table.count(self._map._cellsInMemory), 10, y)		
				y = y + 20				
				love.graphics.print('self._visibleActors '..table.count(self._visibleActors), 10, y)		
				y = y + 20		
				love.graphics.print('self._visibleObjects '..table.count(self._visibleObjects), 10, y)		
				y = y + 20		
				
				if self._hero._latestDt then
					love.graphics.print('DT: ' .. self._hero._latestDt, 10, y)		
					y=y+20		
				end
				
				love.graphics.print('Position: ' .. self._hero._position[1] .. ', ' .. 
					self._hero._position[2], 10, y)		
				y=y+20
				
				love.graphics.print('Boundary: ' .. self._hero._boundary[1] .. ', ' .. 
					self._hero._boundary[2] .. ', ' .. 
					self._hero._boundary[3] .. ', ' .. 
					self._hero._boundary[4], 10, y)		
				y=y+20
				
				if self._hero._collidee then
					love.graphics.print('Collidee: ' .. self._hero._collidee._boundary[1] .. ', ' .. 
					self._hero._collidee._boundary[2] .. ', ' .. 
					self._hero._collidee._boundary[3] .. ', ' .. 
					self._hero._collidee._boundary[4], 10, y)		
					y=y+20
				end
				
				local cw = self._camera:window()
				local cv = self._camera:viewport()
				love.graphics.print('Window: ' .. cw[1] .. ', ' .. 
					cw[2] .. ', ' .. 
					cw[3] .. ', ' .. 
					cw[4], 10, y)		
				y=y+20
				
				love.graphics.print('Viewport: ' .. cv[1] .. ', ' .. 
					cv[2] .. ', ' .. 
					cv[3] .. ', ' .. 
					cv[4], 10, y)		
				y=y+20

				y = 150
				love.graphics.print('ACTORS TO SAVE: '..table.count(self._actorsToSave), 400, y)		
				y = y + 20				

				love.graphics.print('CELLS TO DISPOSE '..table.count(self._map._cellsToDispose), 400, y)		
				y = y + 20				

				love.graphics.print('CELLS LOADING '..table.count(self._map._cellsLoading), 400, y)		
				y = y + 20				
			end
		end)		
end

--
--  Removes an actor permanently from the game world
--
function World:removeActor(actor)
	self:disposeActor(actor)
	self._communicator:send('deleteActor',actor._id)	
end

--
--  Schedule an actor for permanent removal
--
function World:scheduleRemoval(actor)
	self._actorsToSave[actor._id] = nil				
	self._removals[actor._id] = actor
end

--
--  Disposes an actor from the game world
--  but doesn't delete the actor permanently
--
function World:disposeActor(actor)
	-- unregister the actor from the buckets
	for b, _ in pairs(actor._bucketIds) do
		if self._map._buckets[b] then
			self._map._buckets[b][actor._id] = nil
		end
	end				
	-- remove actor from list of visible actors
	self._visibleActors[actor._id] = nil
end

--
--  Creates floating text
--
function World:createFloatingText(colour, actor, text)
	local ft = factories.createFloatingText( text, World.largeFont,
		colour, { actor._position[1], actor._position[2] },
		{ 0, -120 }, 1 )
	ft.on_expired = function(ft)
		self._floatingTexts[ft._id] = nil
	end
	self._floatingTexts[#self._floatingTexts + 1] = ft
	ft._id = #self._floatingTexts
	
	-- @TODO find a better way to seperate floating texts!
	for _, txt1 in pairs(self._floatingTexts) do
		for _, txt2 in pairs(self._floatingTexts) do
			if txt1 ~= txt2 and txt1._position[1] == txt2._position[1] and
			txt1._position[2] == txt2._position[2] then
				txt2._position[2] = txt2._position[2] + 20
			end
		end
	end
end

--
--  Creates an item
--
function World:createItem(description, position, cb)
	item = StaticActor.create(description)
	item:position(position[1], position[2])
	if cb then cb(item) end
	item:update(0)
	item:registerBuckets(self._map._buckets)
end

--
--  Drop an item
--
function World:dropItem(actor)
	-- drop an item
	if math.random() > 0.25 then		
		if math.random() > 0.25 then
			self:createItem('content/actors/coins.dat', actor:position(),
				function(item)
					item:value(math.floor(math.random()*100))
				end)
		else
			self:createItem('content/actors/potions.dat', actor:position(),
				function(item)
					item:setType('weak','healing')
				end)
		end
	end
end

--
--  Updates the World
---
function World:update(dt)
	self._profiler:profile('executing timed events', 
		function()
			self:executeTimedEvents()
		end)

	self._profiler:profile('saving actors', 
		function()				
			-- save actors if there are any to save
			local actorsSaved = 0
			for k, v in pairs(self._actorsToSave) do
				self:saveActor(v)
				self._actorsToSave[k] = nil
				actorsSaved = actorsSaved + 1
				if actorsSaved >= World.saveActorsPerFrame then break end
			end	
		end)
		
	self._profiler:profile('receiving loaded actors', 
		function()			
			-- receive any actors that have been loaded
			self:receiveLoadedActors()
		end)
	
	-- load actors just so that the functions that are waiting to be
	-- executed on them can be executed and the actor saved to disk
	-- again
	self:cleanUpActorFunctions()
	
	self._profiler:profile('updating lighting', 
		function()
			-- @TODO proper day / night cycles with changing colour
			-- and direction of light
			self._renderer._lighting.origin[1] = self._renderer._lighting.origin[1] + 0.0001
			if self._renderer._lighting.origin[1] > self._renderer._lighting.originMinMax[2] then 
				self._renderer._lighting.origin[1] = self._renderer._lighting.originMinMax[1]
			end	
				
			local orange = self._renderer._lighting.originMinMax[2] - self._renderer._lighting.originMinMax[1]
			local srange = self._renderer._lighting.shadowSkewMinMax[2] - self._renderer._lighting.shadowSkewMinMax[1]
			local scaled = (self._renderer._lighting.origin[1]  - self._renderer._lighting.originMinMax[1]) / orange
			self._renderer._lighting.shadowSkew[1] = self._renderer._lighting.shadowSkewMinMax[1] + (scaled * srange)
		end)
	
	self._profiler:profile('permanently removing actors', 
		function()			
			-- remove all entities that were scheduled for removal
			for k, v in pairs(self._removals) do		
				self:removeActor(v)
				self._removals[k] = nil
			end	
		end)
	
	-- do the actor's AI updates
	self._profiler:profile('updating AI', 
		function()
			for _, a in pairs(self._visibleActors) do
				if a.AI then
					a:AI()
				end					
			end	
		end)

	-- update the floating texts
	self._profiler:profile('updating floating texts', 
		function()		
			for _, t in pairs(self._floatingTexts) do
				t:update(dt)
			end
		end)
		
	-- update only the visible actors
	self._profiler:profile('updating actors', 
		function()		
			for _, a in pairs(self._visibleActors) do
				a:update(dt)
			end
		end)	

	-- update the collision buckets
	self._profiler:profile('updating collision buckets', 
		function()			
			for _, a in pairs(self._visibleActors) do
				a:registerBuckets(self._map._buckets)
			end	
		end)
	
	-- test collistions for all visible actors
	self._profiler:profile('testing collisions', 
		function()				
			for _, a in pairs(self._visibleActors) do
				a:checkCollision(self._map._buckets)
			end	
		end)
		
	-- zoom and center the map on the main character
	self._profiler:profile('updating camera', 
		function()
			self._camera:zoom(self._zoom )
			self._camera:center(self._hero._position[1], self._hero._position[2])
		end)
	
	-- get the list of visible ids
	self._profiler:profile('getting list of ids near map centre', 
		function()
			self._map:visibleIds(self._visibleIds)
		end)
	
	-- clear the list of visible items
	self._profiler:profile('wiping out old visible items',
		function()
			for k, _ in pairs(self._visibleObjects) do
				self._visibleObjects[k] = nil
			end	
			for k, _ in pairs(self._visibleActors) do
				self._visibleActors[k] = nil
			end	
		end)
		
	-- generate a list of visible items
	self._profiler:profile('generating list of visible items',
		function()				
			for k, _ in pairs(self._visibleIds) do
				for _, v in pairs(self._map._buckets[k]) do
					if v.ACTOR or v.STATICACTOR then
						self._visibleActors[v._id] = v
					end
					-- map objects that you can collide with but
					-- never interact with
					if v._image then
						self._visibleObjects[#self._visibleObjects + 1] = v
					end	
				end
			end	
		end)
		
	self._map:update(dt, self._camera, self._profiler)
end