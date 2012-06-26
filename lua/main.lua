--[[
	main.lua
	
	Created JUN-21-2012
]]

require 'factories'

function love.load()
	-- create the shader effects
	loadEffects()
	
	tileSets = {}
	
	local ts = factories.createTileset('outdoor.dat')
	tileSets[ts:name()] = ts
	local ts = factories.createTileset('fem1.dat')
	tileSets[ts:name()] = ts
	
	-- the size of the world
	local worldX = 500 * 32
	local worldY = 500 * 32
	buckets = createBuckets(500, worldX, worldY)
		
	daMap = factories.createMap('outdoor', { worldX / 32, worldY / 32 })
	daMap:generate()
	daMap:createColliders(buckets)
	
	daCamera = factories.createCamera()
	daCamera:window(2000,2000,800,600)
	
	shadowCanvas = love.graphics.newCanvas(800,600)
	
	createActors()
	
	lightOrigin = { 0, 0.4 }
	shadowSkew = -3
	
	angle = 0
	zoom = 1
	currentShader = nil
	showCollisionBoundaries = false
	
	visibleIds = {}
	visibleActors = {}	

	-- add the actors to the collision buckets
	for k, v in pairs(actors) do
		v:update(0.16)
		v:registerBuckets(buckets)
	end	
	-- add the map collision items
	daMap:registerBuckets(buckets)	
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
	hero = factories.createActor('princess.dat')
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
		local a = factories.createActor('princess.dat')
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
	outdoorLightEffect = love.graphics.newPixelEffect [[
		extern vec2 pos[2];
		extern vec2 size[2];
		extern vec2 angle[2];
		extern vec3 lightColor[2];
				
		extern vec2 origin;
		extern float dFallOff;
		extern float spotSize;
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
		{
			float PI2 = 3.14159265358979323846264 * 2;
			float d = 0;			
			float a;
			vec3 l = vec3(0,0,0);
			int i;
			for (i=0;i<2;i++) 
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
			
			d = pow(clamp(length(origin - texture_coords) - spotSize, 0, 1),dFallOff);
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
	
	directionalLightEffect = love.graphics.newPixelEffect [[
		extern vec2 origin;
		extern float dFallOff;
		extern float spotSize;
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
		{
			vec2 hv = origin - texture_coords;
			float d = pow(clamp(length(origin - texture_coords) - spotSize, 0, 1),dFallOff);
			color = Texel( texture, texture_coords );
			color.rgb *= (1-d);
			color = clamp(color, 0, 1);
			return color;
		}	
	]]
	
end

function love.draw()
	-- set up the draw table
	local drawTable = {
		base = {},
		object = {},
		roof = {} }
	
	-- draw the map
	daMap:draw(daCamera, drawTable)

	-- draw only the visible items
	for a, _ in pairs(visibleActors) do
		if a.draw then
			a:draw(daCamera, drawTable)
		end
	end	
			
	love.graphics.setPixelEffect(currentShader)			
	if currentShader then
		currentShader:send('origin', lightOrigin )
		currentShader:send('spotSize', 2 )	
	end	

	for k, v in ipairs(drawTable.base) do
		love.graphics.draw(v[2], 
			v[3], v[4], 0, v[5], v[6], 
			v[7], v[8])
	end
	
	table.sort(drawTable.object,function(a,b)
		return a[1] < b[1] end)
	
	if currentShader then
		currentShader:send('origin', lightOrigin )
		currentShader:send('spotSize', 0.25 )	
	end		
	
	for k, v in ipairs(drawTable.object) do
		love.graphics.setPixelEffect(shadowEffect)				
			
		love.graphics.draw(v[2],
			v[3], v[4], 0, v[5], v[6], 
			v[7], v[8], shadowSkew, 0)
	
		love.graphics.setPixelEffect(currentShader)			
	
		love.graphics.draw(v[2],
			v[3], v[4], 0, v[5], v[6], 
			v[7], v[8])
	end	
	
	for k, v in ipairs(drawTable.roof) do
		love.graphics.setPixelEffect(shadowEffect)			
			
		love.graphics.draw(v[2],
			v[3], v[4], 0, v[5], v[6], 
			v[7], v[8], shadowSkew, 0)
			
		love.graphics.setPixelEffect(currentShader)		
	
		love.graphics.draw(v[2], 
			v[3], v[4], 0, v[5], v[6], 
			v[7], v[8])
	end		
		
	local cw = daCamera:window()
	if showCollisionBoundaries then
		-- draw only the visible items
		for a, _ in pairs(visibleActors) do
			if a._boundary then
				local b = a._boundary
				love.graphics.rectangle(
					'line', b[1] - cw[1], b[2] - cw[2], b[3] - b[1], b[4] - b[2])		
			end
		end	
	end
	
	love.graphics.setPixelEffect()
	
	love.graphics.print('FPS: '..love.timer.getFPS(), 10, 20)
	
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
end

function love.update(dt)
	local vx, vy = 0, 0
	
	-- @TODO proper day / night cycles with changing colour
	-- and direction of light
	lightOrigin[1] = lightOrigin[1] + 0.001
	if lightOrigin[1] > 1 then 
		lightOrigin[1] = 0
	end	
	
	shadowSkew = shadowSkew + 0.006
	if shadowSkew > 3 then
		shadowSkew = -3
	end
	
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

	--@TODO in a cave with a flashlight or similar
	--[[
	outdoorLightEffect:send('pos', {400,300}, {})
	outdoorLightEffect:send('size', {300,225}, {})
	outdoorLightEffect:send('angle', {0,6.3}, {})
	outdoorLightEffect:send('lightColor', {2,2,2}, {})
	]]
	
	--@TODO coordinate the shadow and light position
	-- with the light color for day / night effect
	
	if love.keyboard.isDown('1') then		
		currentShader = outdoorLightEffect		
		outdoorLightEffect:send('pos', {400,300}, {0,0})
		outdoorLightEffect:send('size', {1600,1200}, {0,0})
		outdoorLightEffect:send('angle', {0,6.3}, {0,0})
		outdoorLightEffect:send('origin', lightOrigin)
		outdoorLightEffect:send('dFallOff', 0.8 )				
		-- morning
		outdoorLightEffect:send('lightColor', {2.0,2.0,1.7}, {0,0,0})
	end
	
	if love.keyboard.isDown('2') then		
		currentShader = outdoorLightEffect		
		outdoorLightEffect:send('pos', {400,300}, {0,0})
		outdoorLightEffect:send('size', {1600,1200}, {0,0})
		outdoorLightEffect:send('angle', {0,6.3}, {0,0})
		outdoorLightEffect:send('origin', lightOrigin)
		outdoorLightEffect:send('dFallOff', 0.8 )				
		-- midday
		outdoorLightEffect:send('lightColor', {2.5,2.5,2.5}, {0,0,0})
	end
	
	if love.keyboard.isDown('3') then		
		currentShader = outdoorLightEffect		
		outdoorLightEffect:send('pos', {400,300}, {0,0})
		outdoorLightEffect:send('size', {1600,1200}, {0,0})
		outdoorLightEffect:send('angle', {0,6.3}, {0,0})
		outdoorLightEffect:send('origin', lightOrigin)
		outdoorLightEffect:send('dFallOff', 0.8 )				
		-- dusk
		outdoorLightEffect:send('lightColor', {2.0,1.6,1.6}, {0,0,0})
	end	
	
	if love.keyboard.isDown('4') then		
		currentShader = outdoorLightEffect		
		outdoorLightEffect:send('pos', {400,300}, {200,400})
		outdoorLightEffect:send('size', {1600,1200}, {200,200})
		outdoorLightEffect:send('angle', {0,6.3}, {0,6.3})		
		outdoorLightEffect:send('origin', lightOrigin)
		outdoorLightEffect:send('dFallOff', 0.8 )				
		-- night
		outdoorLightEffect:send('lightColor', {0.7,0.7,1.4}, {2,2,2})
	end		
		
	if love.keyboard.isDown('m') then		
		currentShader = directionalLightEffect
		outdoorLightEffect:send('origin', lightOrigin)
		currentShader:send('dFallOff', 0.9 )		
	end
	
	if love.keyboard.isDown('o') then
		currentShader = nil
	end
	
	hero:velocity(vx, vy)
	
	if vx == 0 and vy == 0 then
		local anim = hero:animation():name():gsub('walk','stand')
		hero:animation(anim)
	end
		
	-- @TODO AI!!! (DOH!)
	-- update the visible npcs with some crappy "AI"
	for a, _ in pairs(visibleActors) do
		if a.velocity and not a.player then
			if math.random() > 0.95 then
				a:velocity(math.random()*200-100,math.random()*200-100)
			end
		end	
	end	

	-- update only the visible actors
	for a, _ in pairs(visibleActors) do
		if a.update then
			a:update(dt)
		end
	end

	-- update the collision buckets
	for a, _ in pairs(visibleActors) do
		if a.registerBuckets then
			a:registerBuckets(buckets)
		end
	end
	
	--	
	-- test collistions for all visible actors
	--
	for a, _ in pairs(visibleActors) do
		if a.checkCollision then
			a:checkCollision(buckets)
		end
	end	
		
	-- zoom and center the map on the main character
	daCamera:zoom(zoom)
	daCamera:center(hero._position[1], hero._position[2])
	
	-- get the list of visible ids
	visibleIds = daMap:nearIds(daCamera, buckets, 1)
	
	-- generate a list of visible actors
	for k, _ in pairs(visibleActors) do
		visibleActors[k] = nil
	end	
	for k, _ in pairs(visibleIds) do
		for _, v in pairs(buckets[k]) do
			if v.checkCollision then
				visibleActors[v] = true
			end
		end
	end	
end
