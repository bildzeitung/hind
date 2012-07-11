--[[
	main.lua
	
	Created JUN-21-2012
]]

require 'factories'

local profiles = {}
local function profile(p, fn)
	-- profile the function
	local s = os.clock()
	fn()
	local d = os.clock() - s
	-- track running average of this item
	local prof = profiles[p] or { sum = 0, count = 0 }
	prof.count = prof.count + 1
	prof.sum = prof.sum + d
	profiles[p] = prof
end

function love.load()
	screenWidth = 800
	screenHeight = 600
	local success = love.graphics.setMode( 
		screenWidth,screenHeight, false, false, 0 )		
	love.graphics.setColorMode('replace')

	-- create the shader effects
	loadEffects()
	
	tileSets = {}
	
	local load = {
		'outdoor', 'male_human_tile', 'monster' 
	}
		
	for _, v in ipairs(load) do
		local ts = factories.createTileset(v .. '.dat')
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
	
	-- spot lights are in screen space coordinates
	-- origin, spotsize, falloff are in
	-- texture space? screen space?
	--
	maxLights = 6
	
	lighting = {
		originMinMax = { 0.2, 0.8 },
		origin = { 0.2, 0.4 },
		spotSize = { 0.25 },
		fallOff = { 0.25 },		
		shadowSkewMinMax = { -2, 2 },
		shadowSkew = { -2, 0 },		
		spotLights = { pos = {}, screenPos = {}, size = {}, screenSize = {}, 
			angle = {}, lightColor = {}, world = {} }
	}
	
	for i = 1, maxLights do
		lighting.spotLights.pos[i] = {0,0}
		lighting.spotLights.screenPos[i] = {0,0}
		lighting.spotLights.size[i] = {0,0}
		lighting.spotLights.screenSize[i] = {0,0}
		lighting.spotLights.angle[i] = {0,0}
		lighting.spotLights.lightColor[i] = {0,0,0}
		lighting.spotLights.world[i] = false
	end
	
	zoom = 1
	currentShader = nil
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
end

--
--  Set the directional light parameters
--
function setDirectionalLight(params)	
	for k, v in pairs(params) do
		lighting[k] = v
	end
end
	
--
--  Set the directional light parameters
--
function setSpotLight(params)	
	local idx = params.idx
	params.idx = nil
	for k, v in pairs(params) do
		lighting.spotLights[k][idx] = v
	end
end
	
--
--  Update the light effect
--
function updateLightEffect()
	lightEffect:send('origin', lighting.origin)
	lightEffect:send('fallOff', lighting.fallOff)
	lightEffect:send('spotSize', lighting.spotSize)
	
	local t = table.clone(lighting.spotLights,{deep = true})
	
	local cw = daCamera:window()
	local cv = daCamera:viewport()
	local zoomX = cv[3] / cw[3]
	
	-- convert world position to screen position
	for k, pos in ipairs(t.pos) do		
		-- convert to screen space
		if t.world[k] then
			t.pos[k][1] = (pos[1] - cw[1]) / cw[3] * cv[3]
			t.pos[k][2] = cv[4] - ((pos[2] - cw[2]) / cw[4] * cv[4])		
		end
		lighting.spotLights.screenPos[k] = { t.pos[k][1], t.pos[k][2] }
	end
	
	-- convert world size to screen size
	for k, size in ipairs(t.size) do
		-- convert to screen space
		if t.world[k] then
			t.size[k][1] = size[1] * (cv[3] / cw[3])
			t.size[k][2] = size[2] * (cv[4] / cw[4])			
		end
		lighting.spotLights.screenSize[k] = { t.size[k][1], t.size[k][2] }		
	end

	local paramsToSend = { pos = true, size = true, 
		angle = true, lightColor = true }
	
	-- send all of the parameters
	for k, v in pairs(t) do
		if paramsToSend[k] then
			lightEffect:send(k, unpack(v))
		end
	end
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
--  Creates the actors
--
function createActors()
	local numActors = 1000
	local size = daMap:size()
	
	actors = {}
	hero = factories.createActor('male_human.dat')
	hero:animation('standright')
	-- put the hero in the middle of the map for fun
	hero:position(size[1]/2,size[2]/2)
	hero:map(daMap)
	table.insert(actors, hero)
	hero.player = true
		
	local sx = 0
	local sy = 0
	for i = 1, numActors do		
		io.write('ACTORS ARE BEING GENERATED.. ' .. ((i / numActors) * 100) .. '%             \r')
		local a = factories.createActor('slime.dat')
		a:animation('standright')
		a:position(math.random() * (size[1]-1000) + 1000, math.random() * (size[2]-1000) + 1000)
		a:map(daMap)
		table.insert(actors, a)
	end	
	
	print()
end

--
--  Creates the custom shaders
--
function loadEffects()
	lightEffect = love.graphics.newPixelEffect [[
		extern vec2 pos[6];
		extern vec2 size[6];
		extern vec2 angle[6];
		extern vec3 lightColor[6];
				
		extern vec2 origin;
		extern float fallOff;
		extern float spotSize;
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
		{
			float PI2 = 3.14159265358979323846264 * 2;
			float d = 0;			
			float a;
			vec3 l = vec3(0,0,0);
			int i;
			for (i=0;i<6;i++) 
			{
				vec2 toObj = screen_coords - pos[i];
				a = atan(toObj.y, toObj.x);
				if ( a < 0 )
					a = a + PI2;
				if (a > angle[i].x && a < angle[i].y) {
					vec2 hv = toObj / size[i];
					d = clamp(1 - length(hv), 0, 1);
					l += (d * lightColor[i]) * 0.5;
				}
			}
			
			d = pow(clamp(length(origin - texture_coords) - spotSize, 0, 1),fallOff);
			l *= (1 - d);
			
			color = Texel( texture, texture_coords);
			color.rgb *= l;
			color = clamp(color, 0, 1);
			return color;
		}	
	]]
	
	shadowEffect = love.graphics.newPixelEffect [[
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
		{
			color = Texel( texture, texture_coords );
			color.rgb *= 0;
			color.a /= 2;
			return color;
		}	
	]]	
end

function love.draw()
	local drawTable = {
		base = {},
		overlay = {},
		object = {},
		roof = {}
	}
	
	-- set up the draw table
	profile('pre-calculating draw stuff', 
		function()
			-- pre calculate what we can
			drawTable.cw = daCamera:window()
			drawTable.cv = daCamera:viewport()	
			drawTable.zoomX = drawTable.cv[3] / drawTable.cw[3] 
			drawTable.zoomY = drawTable.cv[4] / drawTable.cw[4] 
			drawTable.cwzx = drawTable.cw[1] * drawTable.zoomX
			drawTable.cwzy = drawTable.cw[2] * drawTable.zoomY
		end)
		
	-- draw the map tiles
	profile('pre-drawing map tiles', 
		function()	
			daMap:drawTiles(daCamera, drawTable)
		end)

	-- draw only the visible actors
	profile('pre-drawing visible actors', 
		function()					
			for a, _ in pairs(visibleActors) do
				if a.draw then
					a:draw(daCamera, drawTable)
				end
			end
		end)
	
	-- draw only the visible objects
	profile('pre-drawing visible objects', 
		function()						
			for o, _ in pairs(visibleObjects) do
				o:draw(daCamera, drawTable)
			end	
		end)	
			
	profile('updating lighting effect', 
		function()
			love.graphics.setPixelEffect(currentShader)				
			setDirectionalLight( { spotSize = 2 } )
			updateLightEffect()
		end)

	profile('drawing base tiles', 
		function()						
			for k, v in ipairs(drawTable.base) do
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8])
			end
		end)
	
	profile('drawing overlay tiles', 
		function()		
			for k, v in ipairs(drawTable.overlay) do
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8])
			end
		end)
	
	profile('z-sorting', 
		function()	
			table.sort(drawTable.object,function(a,b)
				return a[1] < b[1] end)

			table.sort(drawTable.roof,function(a,b)
				return a[1] < b[1] end)
		end)
		
	profile('updating ligthing for objects', 		
		function()
			setDirectionalLight( { spotSize = 0.3 } )
			updateLightEffect()
		end)
	
	-- @TODO the shadow direction
	-- should be calculated based on the position
	-- and size of all of the current spot lights
	-- in screen space

	-- draw the objects and their shadows
	profile('drawing objects and actors and shadows', 		
		function()
			for k, v in ipairs(drawTable.object) do
				love.graphics.setPixelEffect(shadowEffect)				
					
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8], 
					lighting.shadowSkew[1], lighting.shadowSkew[2])
			
				love.graphics.setPixelEffect(currentShader)			
			
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8])
			end	
	end)
	
	-- draw the roof shadows
	profile('drawing roof shadows', 		
		function()	
			love.graphics.setPixelEffect(shadowEffect)				
			for k, v in ipairs(drawTable.roof) do		
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8], 
					lighting.shadowSkew[1], lighting.shadowSkew[2])
			end
		end)
	
	-- draw the roof objects	
	profile('drawing roof tiles', 		
		function()	
			love.graphics.setPixelEffect(currentShader)		
			for k, v in ipairs(drawTable.roof) do	
				love.graphics.draw(v[2], 
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8])
			end		
		end)
		
	local cw = daCamera:window()
	if showCollisionBoundaries then
		for k, _ in pairs(visibleIds) do
			for _, v in pairs(buckets[k]) do
				if v._boundary then
					local b = v._boundary
					love.graphics.rectangle('line', b[1] - cw[1], b[2] - cw[2], b[3] - b[1], b[4] - b[2])							
				end			
			end
		end		
	end
	
	profile('drawing info text', 	
		function()
			love.graphics.setPixelEffect()
			
			love.graphics.print('FPS: '..love.timer.getFPS(), 10, 20)
			
			if drawInfoText then
				local y = 30
				for k, v in pairs(hero._bucketIds) do
					love.graphics.print('ID: '..k.. ' NUM ITEMS: ' .. #buckets[k], 10, y)		
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
				
				for k, v in pairs(profiles) do
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
	profile('updating lighting', 
		function()
			-- @TODO proper day / night cycles with changing colour
			-- and direction of light
			lighting.origin[1] = lighting.origin[1] + 0.0001
			if lighting.origin[1] > lighting.originMinMax[2] then 
				lighting.origin[1] = lighting.originMinMax[1]
			end	
				
			local orange = lighting.originMinMax[2] - lighting.originMinMax[1]
			local srange = lighting.shadowSkewMinMax[2] - lighting.shadowSkewMinMax[1]
			local scaled = (lighting.origin[1]  - lighting.originMinMax[1]) / orange
			lighting.shadowSkew[1] = lighting.shadowSkewMinMax[1] + (scaled * srange)
		end)
	
	profile('handling keyboard input', 
		function()
			if not hero._isAttacking then
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
					hero:animation(anim)
				end
			end
				
			if love.keyboard.isDown(' ') then
				hero:attack()
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
				currentShader = lightEffect		
				
				-- morning
				setDirectionalLight( { fallOff = 0.35 } )
				setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {1.7,1.4,1.1}, world = false }		
				for i = 2, maxLights do
					setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end				
			end
			
			if love.keyboard.isDown('2') then		
				currentShader = lightEffect		
				
				-- midday
				setDirectionalLight( { fallOff = 0.35 } )
				setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {2.5,2.5,2.5}, world = false }		
				for i = 2, maxLights do
					setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end			
			end
			
			if love.keyboard.isDown('3') then		
				currentShader = lightEffect		
				
				-- dusk
				setDirectionalLight( { fallOff = 0.35 } )
				setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {2.0,1.6,1.4}, world = false }		
				for i = 2, maxLights do
					setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end					
			end	
			
			if love.keyboard.isDown('4') then		
				currentShader = lightEffect		
				
				-- night
				setDirectionalLight( { fallOff = 0.35 } )
				setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {0.5,0.5,1.1}, world = false }
				-- random spot lights
				setSpotLight{ idx = 2, pos = {8000,8000}, size = {100,100}, 
						angle = {-1, 7}, lightColor = {3,3,3}, world = true }				
				setSpotLight{ idx = 3, pos = {7600,7600}, size = {75,75}, 
						angle = {-1, 7}, lightColor = {3,1,1}, world = true }
				setSpotLight{ idx = 4, pos = {8400,8400}, size = {400,400}, 
						angle = {1, 3}, lightColor = {0.5,0.5,2}, world = true }
				setSpotLight{ idx = 5, pos = {8500,7600}, size = {80,400}, 
						angle = {4,4.5}, lightColor = {2,2,2}, world = true }
						
				updateLightEffect()
			end		
				
			if love.keyboard.isDown('o') then
				currentShader = nil
			end
			
			if love.keyboard.isDown(',') then		
				for k, _ in pairs(profiles) do
					profiles[k] = { sum = 0, count = 0 }
				end
			end		

			if love.keyboard.isDown('[') then		
				drawInfoText = true
			end		
			
			if love.keyboard.isDown(']') then		
				drawInfoText = false
			end				
		end)
	
	-- @TODO AI!!! (DOH!)
	-- update the visible npcs with some crappy "AI"
	profile('updating AI', 
		function()
			for a, _ in pairs(visibleActors) do
				if a.velocity and not a.player then
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

	-- update only the visible actors
	profile('updating actors', 
		function()		
			for a, _ in pairs(visibleActors) do
				if a.update then
					a:update(dt)
				end
			end
		end)

	-- update the collision buckets
	profile('updating collision buckets', 
		function()			
			for a, _ in pairs(visibleActors) do
				if a.registerBuckets then
					a:registerBuckets(buckets)
				end
			end
	end)
	
	-- test collistions for all visible actors
	profile('testing collisions', 
		function()				
			for a, _ in pairs(visibleActors) do
				if a.checkCollision then
					a:checkCollision(buckets)
				end
			end	
		end)
		
	-- zoom and center the map on the main character
	profile('updating camera', 
		function()
			daCamera:zoom(zoom)
			daCamera:center(hero._position[1], hero._position[2])
		end)
	
	-- get the list of visible ids
	profile('getting list of ids near map centre', 
		function()
			visibleIds = daMap:nearIds(daCamera, buckets, 2)
		end)
	
	-- generate a list of visible actors and objects
	profile('wiping out old visible items',
		function()
			for k, _ in pairs(visibleObjects) do
				visibleObjects[k] = nil
			end	
			for k, _ in pairs(visibleActors) do
				visibleActors[k] = nil
			end	
		end)
		
	profile('generating list of visible items',
		function()				
			for k, _ in pairs(visibleIds) do
				for _, v in pairs(buckets[k]) do
					if v.checkCollision then
						visibleActors[v] = true
					end
					if v._image then
						visibleObjects[v] = true
					end			
				end
			end	
		end)
end
