--[[
	world.lua
	
	Created JUL-23-2012
]]

local Object = (require 'object').Object

require 'inventory_actor'
require 'static_actor'
require 'actor_item'
require 'actor'

local factories = require 'factories'

require 'renderer'

--	@TODO this is required only because we aren't doing
--  real procedural generation yet!
require 'dialog_generator'

local marshal = require 'marshal'

local log = require 'log'

local pairs, ipairs, type, table, math, tostring, tonumber, io, love
	= pairs, ipairs, type, table, math, tostring, tonumber, io, love
	
module('objects')

World = Object{ _init = { '_profiler' } }

World.largeFont = love.graphics.newFont(24)
World.smallFont = love.graphics.newFont(12)

--
--  World constructor
--
function World:_clone(values)
	local o = Object._clone(self,values)
			
	o._renderer = Renderer{}
	o._removals = {}
	o._visibleIds = {}
	o._visibleActors = {}	
	o._visibleObjects = {}
	o._floatingTexts = {}		
	o._zoom = 1
	o._showCollisionBoundaries = false	
	o._drawInfoText = true			

	o._actorsToSave = {}
	o._actorsToLoad = {}
	
	return o
end

--
--  Saves an actor to disk
--
function World:saveActor(actor)
	log.log('Saving actor: ' .. actor._id)
	
	self._profiler:profile('Save actor', 
		function()
			local s = marshal.encode(actor)
			local f = io.open('map/act_' .. actor._id .. '.act', 'wb')	
			if not f then 			
				return nil, 'There was a problem saving the actor #' .. actor._id
			end	
			f:write(s)	
			f:close()
		end)	
	
	log.log('Saving actor complete')
end

--
--  Loads an actor from disk
--
function World:loadActor(id)
	log.log('Loading actor: ' .. id)
	
	local actor
	
	self._profiler:profile('Load actor', 
		function()
			local f = io.open('map/act_' .. id .. '.act', 'rb')	
			if not f then 			
				return nil, 'There was a problem saving the actor #' .. actor._id
			end	
			local s = f:read('*all')
			f:close()		
			actor = marshal.decode(s)
		end)		
	
	log.log('Loading actor complete')
	
	return actor
end

--
--  Returns true if an actor exists in the game world
--	false otherwise
--
function World:actorExists(id)
	return self._visibleActors[id] ~= nil
end

--
--  Returns a table of actors that are close to the
--	supplied actor
--
function World:closeActors(actor)
	local as = {}
	
	for k, v in pairs(actor._bucketIds) do
		for id, other in pairs(self._map._buckets[k]) do
			if other._id and other._id ~= actor._id then
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
		
	self._map = factories.createMap('outdoor')
	self._map:generate(499808,499808,512,512)
	self._map:calculateMinMax(self._camera, {1,1,1,1})
	self._map:visibleCells()
	-- force the map to load the cells
	for i = 0, 20 do
		self._map:update(0, self._camera)
	end
	
	self._map.on_cell_dispose = function(map, mc)
		-- look at the ids that are going to be removed
		for k, _ in pairs(mc._bucketIds) do
			if map._buckets['count' .. k] == 1 then
				-- get rid of visible actors and objects that were in 
				-- the buckets that will be destroyed
				for _, v in pairs(map._buckets[k]) do
					if v._id then
						self._actorsToSave[v._id] = v
						self:removeActor(v)
					end
				end
			end		
		end			
	end
	
	self._map.on_cell_load = function(map, mc)
		log.log('=== on cell load ===')
		-- load all of the actors saved in this map cell
		local actorCount = mc:actorCount()
		
		log.log('actorCount')
		log.log(tostring(actorCount))
		
		for i = 0, actorCount - 1 do
			local id = tonumber(mc._actorData[i].id)
			
			log.log('id')
			log.log(tostring(id))
			log.log('self:actorExists(id)')
			log.log(tostring(self:actorExists(id)))
			
			self._actorsToLoad[id] = true
		end
		
		log.log('=== on cell load complete ===')
	end	
	
	self:createHero()
	self:createActors()
	
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
	hero:position(500008*32, 500000*32)
	hero:update(0.16)

	hero:registerBuckets(self._map._buckets)	

	self._hero = hero	
end

--
--  Create some actors
--
--	@TODO replace this with actual procedural generation
--
function World:createActors()
	local numActors = 10
	
	local actors = {}

	--self:createBunchOPotions(self._hero:position())

	--[[
	local sx = 0
	local sy = 0
	for i = 1, numActors do		
		local a = Actor.create('content/actors/slime.dat')
		--local a = Actor.create('content/actors/male_human.dat')	
		a:animation('standright')
		a:position(math.random() * (20*32) + (500000*32), math.random() * (20*32) + (500000 * 32))
		actors[a._id] = a
	end	
	]]

	local npc = Actor.create('content/actors/male_human.dat')
	npc._health = 2000
	npc._maxHealth = 2000
	npc:animation('standright')
	npc:position(500000*32,500000*32)
	npc:name('Bilbo')
	actors[npc._id] = npc	
	
	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc, hero = self._hero }	
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end
	
	local npc = Actor.create('content/actors/male_human.dat')
	npc._health = 2000
	npc._maxHealth = 2000
	npc:animation('standright')
	npc:position(499990*32,500000*32)
	npc:name('Larry')
	actors[npc._id] = npc	
	
	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc, hero = self._hero }	
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end

	local npc = Actor.create('content/actors/male_human.dat')
	npc._health = 2000
	npc._maxHealth = 2000
	npc:animation('standright')
	npc:position(499980*32,500000*32)
	npc:name('Jimbo')
	actors[npc._id] = npc	
	
	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc, hero = self._hero }	
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end
	
	-- add the actors to the collision buckets
	for k, v in pairs(actors) do
		v:update(0.16)
		v:registerBuckets(self._map._buckets)
	end	
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
		
	-- draw info text
	self._profiler:profile('drawing info text', 	
		function()		
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

			local y = 0
			for k, v in ipairs(self._hero._inventory) do
				love.graphics.print(k .. ' ' .. v:name() .. ' ' .. v:count(), 750, y)
				y=y+20
			end
			
			local y = 0
			for k, v in pairs(self._hero._equipped) do
				love.graphics.print(k .. ' ' .. v:name() .. ' ' .. v:count(), 900, y)
				y=y+20
			end
			
			love.graphics.print('FPS: '..love.timer.getFPS(), 10, 70)
			
			if self._drawInfoText then
				local y = 85
				for k, v in pairs(self._hero._bucketIds) do
					local count = table.count(self._map._buckets[k])
					love.graphics.print('HERO BUCKET ID: '..k.. ' NUM ITEMS: ' .. count, 10, y)		
					y = y + 20
				end

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
			end
		end)		
end

--
--  Schedule an item for removal
--
function World:scheduleRemoval(item)
	self._removals[item._id] = item
end

--
--  Removes an object or actor from the game world
--
function World:removeActor(object)
	-- unregister the actor from the buckets
	for b, _ in pairs(object._bucketIds) do
		if self._map._buckets[b] then
			self._map._buckets[b][object._id] = nil
		end
	end				
	-- remove actor from list of visible actors
	self._visibleActors[object._id] = nil
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
--  @TODO get rid of this!
--
function World:createBunchOPotions(pos)
	-- create bunch o' potions
	for y = -300, -50, 34 do
		for x = -400, 400, 34 do
			local pos = { pos[1], pos[2] }
			pos[1] = pos[1] + x
			pos[2] = pos[2] + y
			self:createItem('content/actors/potions.dat', pos,
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
	-- save one actor per frame
	for k, v in pairs(self._actorsToSave) do
		self:saveActor(v)
		self._actorsToSave[k] = nil
		break
	end
	
	-- load one actor per frame
	for id, _ in pairs(self._actorsToLoad) do
		if not self:actorExists(id) then
			local a = self:loadActor(id)
			a:update(0)
			a:registerBuckets(self._map._buckets, true)
			self._actorsToLoad[id] = nil
			break
		end
	end
	
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
	
	-- remove all entities that were scheduled for removal
	for k, v in pairs(self._removals) do		
		self:removeActor(v)
	end	
	
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
			self._visibleIds = self._map:visibleIds(self._camera)
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
		
	self._map:update(dt, self._camera, profiler)
end
