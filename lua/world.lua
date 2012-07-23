--[[
	world.lua
	
	Created JUL-23-2012
]]

local Object = (require 'object').Object

local factories = require 'factories'
require 'renderer'

--	@TODO this is required only because we aren't doing
--  real procedural generation yet!
require 'dialog_generator'

local log = require 'log'

local pairs, ipairs, type, table, math, tostring, love
	= pairs, ipairs, type, table, math, tostring, love
	
module('objects')

World = Object{}

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

	return o
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
	self._map:generate(499932,499932,256,256)
	--self._map:transitions()
	--self._map:createColliders()
	self._map:calculateMinMax(self._camera, {1,1,1,1})
	self._map:visibleCells()
	
	self._map.on_cell_dispose = function(map, mc)
		-- look at the ids that are going to be removed
		for k, _ in pairs(mc._bucketIds) do
			if map._buckets['count' .. k] == 1 then
				-- get rid of visible actors and objects that were in 
				-- the buckets that will be destroyed
				for _, v in pairs(map._buckets[k]) do
					if v._id then
						self:removeObject(v)
					end
				end
			end		
		end			
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
	local hero = factories.createInventoryActor('content/actors/hero.dat')
	
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
	local chainArmour = factories.createActorItem('content/actors/chain_armour.dat')
	local chainHelmet = factories.createActorItem('content/actors/chain_helmet.dat')
	local plateShoes = factories.createActorItem('content/actors/plate_shoes.dat')
	local platePants = factories.createActorItem('content/actors/plate_pants.dat')
	local longSword = factories.createActorItem('content/actors/longsword.dat')

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
	local numActors = 50
	
	local actors = {}

	--self:createBunchOPotions(self._hero:position())

	--[[
	local sx = 0
	local sy = 0
	for i = 1, numActors do		
		local a = factories.createActor('content/actors/slime.dat')
		a:animation('standright')
		a:position(math.random() * (50*32) + (499980*32), math.random() * (50*32) + (499980 * 32))
		actors[a._id] = a
	end	
	]]

	npc = factories.createActor('content/actors/male_human.dat')
	npc._health = 2000
	npc._maxHealth = 2000
	npc:animation('standright')
	npc:position(500000*32,500000*32)
	actors[npc._id] = npc
	npc:name('Bilbo')
	
	self._npc = npc
	
	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc, hero = self._hero }	
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end
	
	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc, hero = self._hero }	
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end

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
function World:draw(profiler)
	self._renderer:draw( 
		self._camera, 
		{ 	
			floatingTexts = self._floatingTexts, map = self._map,
			actors = self._visibleActors, objects = self._visibleObjects 
		}, 
		profiler )
		
	-- draw collision boundaries?		
	profiler:profile('drawing collision boundaries',
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
	profiler:profile('drawing info text', 	
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
--  Update the world
--
function World:update(dt, profiler)
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
function World:removeObject(object)
	-- unregister the actor from the buckets
	for b, _ in pairs(object._bucketIds) do
		self._map._buckets[b][object._id] = nil
	end				
	-- remove actor from list of visible actors
	self._visibleActors[object] = nil
	-- remove obejct from list of visible objects
	self._visibleObjects[object] = nil
end

--
--  Creates floating text
--
function World:createFloatingText(colour, actor, text)
	local ft = factories.createFloatingText( text, World.largeFont,
		colour, { actor._position[1], actor._position[2] },
		{ 0, -120 }, 1 )
	ft.on_expired = function(text)
		self._floatingTexts[text] = nil
	end
	self._floatingTexts[ft] = true
	
	-- @TODO find a better way to seperate floating texts!
	for k1, _ in pairs(self._floatingTexts) do
		for k2, _ in pairs(self._floatingTexts) do
			if k1 ~= k2 and k1._position[1] == k2._position[1] and
			k1._position[2] == k2._position[2] then
				k2._position[2] = k2._position[2] + 20
			end
		end
	end
end

--
--  Creates an item
--
function World:createItem(description, position, cb)
	item = factories.createStaticActor(description)
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
function World:update(dt, profiler)
	profiler:profile('updating lighting', 
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
		self:removeObject(v)
	end	
	
	-- do the actor's AI updates
	profiler:profile('updating AI', 
		function()
			for a, _ in pairs(self._visibleActors) do
				if a.AI then
					a:AI()
				end					
			end	
		end)

	-- update the floating texts
	profiler:profile('updating floating texts', 
		function()		
			for t, _ in pairs(self._floatingTexts) do
				t:update(dt)
			end
		end)
		
	-- update only the visible actors
	profiler:profile('updating actors', 
		function()		
			for a, _ in pairs(self._visibleActors) do
				a:update(dt)
			end
		end)	

	-- update the collision buckets
	profiler:profile('updating collision buckets', 
		function()			
			for a, _ in pairs(self._visibleActors) do
				a:registerBuckets(self._map._buckets)
			end	
	end)
	
	-- test collistions for all visible actors
	profiler:profile('testing collisions', 
		function()				
			for a, _ in pairs(self._visibleActors) do
				a:checkCollision(self._map._buckets)
			end	
		end)
		
	-- zoom and center the map on the main character
	profiler:profile('updating camera', 
		function()
			self._camera:zoom(self._zoom )
			self._camera:center(self._hero._position[1], self._hero._position[2])
		end)
	
	-- get the list of visible ids
	profiler:profile('getting list of ids near map centre', 
		function()
			self._visibleIds = self._map:visibleIds(self._camera)
		end)
	
	-- clear the list of visible items
	profiler:profile('wiping out old visible items',
		function()
			for k, _ in pairs(self._visibleObjects) do
				self._visibleObjects[k] = nil
			end	
			for k, _ in pairs(self._visibleActors) do
				self._visibleActors[k] = nil
			end	
		end)
		
	-- generate a list of visible items
	profiler:profile('generating list of visible items',
		function()				
			for k, _ in pairs(self._visibleIds) do
				for _, v in pairs(self._map._buckets[k]) do
					if v.ACTOR or v.STATICACTOR then
						self._visibleActors[v] = true
					end
					-- map objects that you can collide with but
					-- never interact with
					if v._image then
						self._visibleObjects[v] = true
					end	
				end
			end	
		end)
		
	self._map:update(dt, self._camera, profiler)
end
