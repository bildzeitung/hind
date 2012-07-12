--[[
	main.lua
	
	Created JUN-21-2012
]]

require 'profiler'
require 'factories'
require 'renderer'
require 'floating_text'

function love.load()	
	profiler = objects.Profiler{}	
	
	largeFont = love.graphics.newFont(24)
	smallFont = love.graphics.newFont(12)
	
	screenWidth = 800
	screenHeight = 600
	local success = love.graphics.setMode( 
		screenWidth,screenHeight, false, false, 0 )		
	love.graphics.setColorMode('replace')

	tileSets = {}
	
	local load = {
		'outdoor', 'male_human', 
		'chain_armour', 'chain_helmet', 'plate_shoes', 
		'plate_pants', 'longsword', 'monster' 
	}
		
	for _, v in ipairs(load) do
		local ts = factories.createTileset('content/tilesets/' .. v .. '.dat')
		tileSets[ts:name()] = ts
	end
	
	-- the size of the world
	local worldX = 500 * 32
	local worldY = 500 * 32
	buckets = createBuckets(250, worldX, worldY)
		
	daMap = factories.createMap('outdoor', { worldX / 32, worldY / 32 })
	daMap:generate()
	daMap:transitions()

	daMap:createColliders(buckets)
	
	daCamera = factories.createCamera()
	daCamera:window(2000,2000,screenWidth,screenHeight)
	daCamera:viewport(0,0,screenWidth,screenHeight)
	
	shadowCanvas = love.graphics.newCanvas(screenWidth,screenHeight)
	
	createActors()
		
	zoom = 1
	showCollisionBoundaries = false
	
	visibleIds = {}
	visibleActors = {}	
	visibleObjects = {}

	-- add the actors to the collision buckets
	for k, v in pairs(actors) do
		v:update(0.16)
		v:registerBuckets(buckets)
	end	
	-- add the map collision items
	daMap:registerBuckets(buckets)	
	
	--@TODO in a cave with a flashlight or similar
	--[[
	setSpotLight{ idx = 1, pos = {400,300} },
								size = {300,225},
								angle = {0,6.3},
								color = {2,2,2} }
	]]
	
	drawInfoText = true
	floatingTexts = {}		
	removals = {}	
	renderer = objects.Renderer{}
end

--
--  Creates and returns the collision buckets
--
function createBuckets(cellSize, worldX, worldY)
	local b = {}

	b.cellSize = cellSize
	b.columns = math.floor(worldX / b.cellSize)
	b.rows = math.floor(worldY / b.cellSize)	
	b.hash = function(x,y)
		return math.floor(math.floor(x / b.cellSize) +
				(math.floor(y / b.cellSize) * b.columns)) + 1
	end		
	
	-- create new collision buckets
	for i = 1, b.columns * b.rows do
		b[i] = {}
	end
	
	return b
end

--
--  Creates a damage text
--
function createDamageText(actor, damage)
	local ft = factories.createFloatingText( damage, largeFont,
		{ 255, 0, 0, 255 }, { actor._position[1], actor._position[2] },
		{ 0, -120 }, 1 )
	ft.on_expired = function(self)
		floatingTexts[self] = nil
	end
	floatingTexts[ft] = true
end

--
--  Creates the actors
--
function createActors()
	local numActors = 1000
	local size = daMap:size()
	
	actors = {}
	hero = factories.createHero('content/actors/male_human.dat')
	local chainArmour = factories.createActorItem('content/actors/chain_armour.dat')
	local chainHelmet = factories.createActorItem('content/actors/chain_helmet.dat')
	local plateShoes = factories.createActorItem('content/actors/plate_shoes.dat')
	local platePants = factories.createActorItem('content/actors/plate_pants.dat')
	local longSword = factories.createActorItem('content/actors/longsword.dat')

	-- add a collide event to the sword
	longSword.on_collide = function(self, other)
		if self._actor._isAttacking and other._id then		
			if not self._collidees[other._id] then				
				self._actor:doDamage(other)				
				self._collidees[other._id] = true
			end
		end
	end	

	hero:equipItem('weapon',longSword)		
	hero:equipItem('legs',platePants)	
	hero:equipItem('head',chainHelmet)	
	hero:equipItem('torso',chainArmour)	
	hero:equipItem('feet',plateShoes)	
	hero:animation('standright')		
	
	-- put the hero in the middle of the map for fun
	hero:position(size[1]/2,size[2]/2)
	hero:map(daMap)
	table.insert(actors, hero)
	hero.player = true
	
	-- when the hero takes damage create 
	-- a floating text that shows the damage
	hero.on_take_damage = function(self, damage)
		createDamageText(self, damage)
	end
	
	-- when the hero dies
	-- the game is over?
	-- and credit the actor that
	-- defeated him
	hero.on_end_die = function(self, other)			
		hero.dead = true
	end	
		
	local sx = 0
	local sy = 0
	for i = 1, numActors do		
		io.write('ACTORS ARE BEING GENERATED.. ' .. ((i / numActors) * 100) .. '%             \r')
		local a = factories.createActor('content/actors/slime.dat')
		a:animation('standright')
		a:position(math.random() * (size[1]-1000) + 1000, math.random() * (size[2]-1000) + 1000)
		a:map(daMap)
		
		-- when an actor takes damage create 
		-- a floating text that shows the damage
		a.on_take_damage = function(self, damage)
			createDamageText(self, damage)
		end
		
		-- when an actor dies
		-- take him out of the game
		-- and credit the actor that
		-- defeated him
		a.on_begin_die = function(self, other)			
			if other.rewardExperience then
				other:rewardExperience(100)			
			end
			local ft = factories.createFloatingText( 100, largeFont,
				{ 0, 255, 255, 255 }, { other._position[1], other._position[2] },
				{ 0, -120 }, 1 )
			ft.on_expired = function(self)
				floatingTexts[self] = nil
			end
			floatingTexts[ft] = true			
		end
		
		-- when an actor has finished dying
		-- then remove him from the game
		a.on_end_die = function(self, other)			
			removals[a._id] = a				
		end		
			
		a.on_collide = function(self, other)
			-- if we are colliding with an actoritem
			-- then actually collide with the actor
			-- if this item doesn't ignore hits
			if other._actor and not other._ignoresHits then
				other = other._actor
			end
			if other._id and other.HERO then
				if not self._collidees[other._id] then
					self:doDamage(other)				
					self._collidees[other._id] = true
				end
			end
		end		
		
		actors[a._id] = a
	end	
	
	print()
end

function love.draw()
	if hero.dead then		
		love.graphics.setFont(largeFont)
		love.graphics.print('GAME OVER', 300, 300)
		return
	end

	renderer:draw( daCamera, { floatingTexts = floatingTexts, map = daMap,
			actors = visibleActors, objects = visibleObjects }, profiler )
		
	-- draw collision boundaries?		
	profiler:profile('drawing collision boundaries',
		function()
			if showCollisionBoundaries then
				local cw = daCamera:window()
				for k, _ in pairs(visibleIds) do
					for _, v in pairs(buckets[k]) do
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
			love.graphics.setPixelEffect()
			
			love.graphics.setFont(largeFont)
			love.graphics.print('EXPERIENCE: ' .. hero._experience, 10, 20)
			love.graphics.print('HEALTH: ' .. hero._health, 400, 20)
			love.graphics.setFont(smallFont)			
			love.graphics.print('FPS: '..love.timer.getFPS(), 10, 50)
			
			if drawInfoText then
				local y = 60
				for k, v in pairs(hero._bucketIds) do
					local count = table.count(buckets[k])
					love.graphics.print('ID: '..k.. ' NUM ITEMS: ' .. count, 10, y)		
					y = y + 20
				end
				
				love.graphics.print('DT: ' .. hero._latestDt, 10, y)		
				y=y+20		
				
				love.graphics.print('Position: ' .. hero._position[1] .. ', ' .. 
					hero._position[2], 10, y)		
				y=y+20
				
				love.graphics.print('Boundary: ' .. hero._boundary[1] .. ', ' .. 
					hero._boundary[2] .. ', ' .. 
					hero._boundary[3] .. ', ' .. 
					hero._boundary[4], 10, y)		
				y=y+20
				
				if hero._collidee then
					love.graphics.print('Collidee: ' .. hero._collidee._boundary[1] .. ', ' .. 
					hero._collidee._boundary[2] .. ', ' .. 
					hero._collidee._boundary[3] .. ', ' .. 
					hero._collidee._boundary[4], 10, y)		
					y=y+20
				end
				
				local cw = daCamera:window()
				local cv = daCamera:viewport()
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
		
				local total = 0	
				y = 200
				love.graphics.print('=== PROFILES ===', 10, y)
				y = y + 20
				
				for k, v in pairs(profiler:profiles()) do
					local avg = v.sum / v.count
					if avg > 0.0009 then
						love.graphics.print(k,10, y)				
						love.graphics.print(v.count, 280, y)				
						love.graphics.print(string.format('%.5f', v.sum / v.count),
							330, y)		
						y=y+15		
					end
					total = total + avg
				end	
				
				love.graphics.print('=== TOTAL AVG TIME ===', 10, y)
				y=y+15
				love.graphics.print(string.format('%.5f', total), 10, y)
				y=y+15
				love.graphics.print('=== EXPECTED FPS ===', 10, y)
				y=y+15
				love.graphics.print(string.format('%.5f', 1/total), 10, y)
			end
		end)
end

function love.update(dt)
	if hero.dead then		
		return
	end

	profiler:profile('updating lighting', 
		function()
			-- @TODO proper day / night cycles with changing colour
			-- and direction of light
			renderer._lighting.origin[1] = renderer._lighting.origin[1] + 0.0001
			if renderer._lighting.origin[1] > renderer._lighting.originMinMax[2] then 
				renderer._lighting.origin[1] = renderer._lighting.originMinMax[1]
			end	
				
			local orange = renderer._lighting.originMinMax[2] - renderer._lighting.originMinMax[1]
			local srange = renderer._lighting.shadowSkewMinMax[2] - renderer._lighting.shadowSkewMinMax[1]
			local scaled = (renderer._lighting.origin[1]  - renderer._lighting.originMinMax[1]) / orange
			renderer._lighting.shadowSkew[1] = renderer._lighting.shadowSkewMinMax[1] + (scaled * srange)
		end)
	
	profiler:profile('handling keyboard input', 
		function()
			if not hero._isAttacking and not hero._isDying then
				local vx, vy = 0, 0
			
				if love.keyboard.isDown('up') then
					hero:animation('walkup')		
					vy = -125
				elseif
					love.keyboard.isDown('down') then
					hero:animation('walkdown')		
					vy = 125
				end
				
				if love.keyboard.isDown('left') then
					hero:animation('walkleft')
					vx = -125
				elseif
					love.keyboard.isDown('right') then
					hero:animation('walkright')		
					vx = 125
				end
				
				hero:velocity(vx, vy)
				
				if vx == 0 and vy == 0 then
					local anim = hero:animation():name():gsub('walk','stand')
					hero:animation(anim, true)
				end
				
				if love.keyboard.isDown(' ') then
					hero:attack()
				end
			end
							
			if love.keyboard.isDown('q') then
				zoom = 1
			end
			
			if love.keyboard.isDown('w') then
				zoom = 2
			end
			
			if love.keyboard.isDown('e') then
				zoom = 3
			end	
			
			if love.keyboard.isDown('r') then
				zoom = 4
			end		

			if love.keyboard.isDown('t') then
				zoom = 0.5
			end		
			
			if love.keyboard.isDown('a') then
				zoom = zoom + 0.01
			end
			
			if love.keyboard.isDown('z') then
				zoom = zoom - 0.01
			end	
			
			if love.keyboard.isDown('h') then
				showCollisionBoundaries = true
			end		

			if love.keyboard.isDown('n') then
				showCollisionBoundaries = false
			end
	
			--@TODO coordinate the shadow and light position
			-- with the light color for day / night effect
			-- each light could also generate it's own shadow
			-- redraw!!!!!!	
			if love.keyboard.isDown('1') then		
				renderer:shader('light')
				
				-- morning
				renderer:setDirectionalLight( { fallOff = 0.35 } )
				renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {1.7,1.4,1.1}, world = false }		
				for i = 2, renderer:maxLights() do
					renderer:setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end				
			end
			
			if love.keyboard.isDown('2') then		
				renderer:shader('light')
				
				-- midday
				renderer:setDirectionalLight( { fallOff = 0.35 } )
				renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {2.5,2.5,2.5}, world = false }		
				for i = 2, renderer:maxLights() do
					renderer:setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end			
			end
			
			if love.keyboard.isDown('3') then		
				renderer:shader('light')
				
				-- dusk
				renderer:setDirectionalLight( { fallOff = 0.35 } )
				renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {2.0,1.6,1.4}, world = false }		
				for i = 2, renderer:maxLights() do
					renderer:setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end					
			end	
			
			if love.keyboard.isDown('4') then		
				renderer:shader('light')
				
				-- night
				renderer:setDirectionalLight( { fallOff = 0.35 } )
				renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {0.5,0.5,1.1}, world = false }
				-- random spot lights
				renderer:setSpotLight{ idx = 2, pos = {8000,8000}, size = {100,100}, 
						angle = {-1, 7}, lightColor = {3,3,3}, world = true }				
				renderer:setSpotLight{ idx = 3, pos = {7600,7600}, size = {75,75},
						angle = {-1, 7}, lightColor = {3,1,1}, world = true }
				renderer:setSpotLight{ idx = 4, pos = {8400,8400}, size = {400,400}, 
						angle = {1, 3}, lightColor = {0.5,0.5,2}, world = true }
				renderer:setSpotLight{ idx = 5, pos = {8500,7600}, size = {80,400}, 
						angle = {4,4.5}, lightColor = {2,2,2}, world = true }
						
				renderer:updateLightEffect(daCamera)
			end		
				
			if love.keyboard.isDown('o') then
				renderer:shader(nil)
			end
			
			if love.keyboard.isDown(',') then		
				profiler:reset()
			end		

			if love.keyboard.isDown('[') then		
				drawInfoText = true
			end		
			
			if love.keyboard.isDown(']') then		
				drawInfoText = false
			end				
		end)
	
	-- remove all entities that were scheduled for removal
	for k, v in pairs(removals) do		
		-- unregister the actor from the buckets
		for b, _ in pairs(v._bucketIds) do
			buckets[b][v._id] = nil
		end				
		-- remove actor from actor list
		actors[k] = nil
		-- remove actor from list of visible actors
		visibleActors[v] = nil
	end	
	
	-- @TODO AI!!! (DOH!)
	-- update the visible npcs with some crappy "AI"
	profiler:profile('updating AI', 
		function()
			for a, _ in pairs(visibleActors) do
				if not a.HERO and not a._isDying then
					if math.random() > 0.95 then
						local xv = math.random()*200-100
						local yv = math.random()*200-100
						
						if math.abs(xv) < 50 then xv = 0 end
						if math.abs(yv) < 50 then yv = 0 end
						
						a:velocity(xv, yv)				
					
						if yv > 0 then
							a:animation('walkdown')
						elseif yv < 0 then
							a:animation('walkup')
						end
						
						if xv > 0 then 
							a:animation('walkright')
						elseif xv < 0 then
							a:animation('walkleft')
						end
					end						
				end	
			end	
		end)

	-- update the floating texts
	profiler:profile('updating floating texts', 
		function()		
			for t, _ in pairs(floatingTexts) do
				t:update(dt)
			end
		end)
		
	-- update only the visible actors
	profiler:profile('updating actors', 
		function()		
			for a, _ in pairs(visibleActors) do
				a:update(dt)
			end
		end)

	-- update the collision buckets
	profiler:profile('updating collision buckets', 
		function()			
			for a, _ in pairs(visibleActors) do
				a:registerBuckets(buckets)
			end	
	end)
	
	-- test collistions for all visible actors
	profiler:profile('testing collisions', 
		function()				
			for a, _ in pairs(visibleActors) do
				a:checkCollision(buckets)
			end	
		end)
		
	-- zoom and center the map on the main character
	profiler:profile('updating camera', 
		function()
			daCamera:zoom(zoom)
			daCamera:center(hero._position[1], hero._position[2])
		end)
	
	-- get the list of visible ids
	profiler:profile('getting list of ids near map centre', 
		function()
			visibleIds = daMap:nearIds(daCamera, buckets, 2)
		end)
	
	-- clear the list of visible items
	profiler:profile('wiping out old visible items',
		function()
			for k, _ in pairs(visibleObjects) do
				visibleObjects[k] = nil
			end	
			for k, _ in pairs(visibleActors) do
				visibleActors[k] = nil
			end	
		end)
		
	-- generate a list of visible items
	profiler:profile('generating list of visible items',
		function()				
			for k, _ in pairs(visibleIds) do
				for _, v in pairs(buckets[k]) do
					if v.ACTOR then
						visibleActors[v] = true
					end
					if v._image then
						visibleObjects[v] = true
					end	
				end
			end	
		end)
end