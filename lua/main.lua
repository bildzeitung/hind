--[[
	main.lua
	
	Created JUN-21-2012
]]

require 'factories'

local numActors = 100

function love.load()
	tileSets = {}
	
	local ts = factories.createTileset('outdoor.dat')
	tileSets[ts:name()] = ts
	local ts = factories.createTileset('fem1.dat')
	tileSets[ts:name()] = ts
	
	daMap = factories.createMap('outdoor', { 500, 500 })
	daMap:generate()
	daMap:createColliders()
	
	daCamera = factories.createCamera()
	daCamera:window(2000,2000,800,600)
	
	girls = {}
	local sx = 0
	local sy = 0
	for i = 1, numActors do		
		local girl = factories.createActor('princess.dat')
		girl:animation('standright')
		girl:position(math.random() * 7000 + 1000, math.random() * 7000 + 1000)
		girl:map(daMap)
		girls[i] = girl
	end
	
	girl = factories.createActor('princess.dat')
	girl:animation('standright')
	girl:position(2048,2016)
	girl:map(daMap)
	
	zoom = 1
	
	showCollisionBoundaries = false

	spotLightEffect = love.graphics.newPixelEffect [[
		extern vec2 pos[2];
		extern vec2 size[2];
		extern vec2 angle[2];
		extern vec3 lightColor[2];
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
		{
			float PI2 = 3.14159265358979323846264 * 2;
			float d = 0;
			vec3 l = vec3(0,0,0);
			float a;
			int i;
			for (i=0;i<2;i++) {				
				vec2 toObj = screen_coords - pos[i];
				a = atan(toObj.y, toObj.x);
				if ( a < 0 )
					a = a + PI2;
				if (a > angle[i].x && a < angle[i].y) {
					vec2 hv = toObj / size[i];
					d = clamp((1 - sqrt(hv.x*hv.x + hv.y*hv.y)), 0, 1);
					l += (d * lightColor[i]) * 0.5;
				}
			}
			
			color = Texel( texture, texture_coords);
			color.rgb *= l;
			color = clamp(color, 0, 1);
			return color;
		}	
	]]
	
	currentShader = nil
end

function love.draw()
	local drawTable = {}
	local cw = daCamera:window()
	local cv = daCamera:viewport()	
	local zoomX = cv[3] / cw[3] 
	local zoomY = cv[4] / cw[4]	
	
	daMap:draw(daCamera, drawTable)
	for k, v in ipairs(girls) do
		v:draw(daCamera, drawTable)
	end

	girl:draw(daCamera, drawTable)
	
	table.sort(drawTable, function(a,b)
		return a[1] < b[1] end)

	love.graphics.setPixelEffect(currentShader)
	
	for k, v in ipairs(drawTable) do
		love.graphics.drawq(v[2], v[3], 
			v[4], v[5], 0, zoomX, zoomY,
			v[6], v[7])
	end
	
	if showCollisionBoundaries then
		for k, v in ipairs(girls) do
			local b = v._boundary
			love.graphics.rectangle( 'line', b[1] - cw[1], b[2] - cw[2], b[3] - b[1], b[4] - b[2])		
		end	
		
		local b = girl._boundary
		love.graphics.rectangle( 'line', b[1] - cw[1], b[2] - cw[2], b[3] - b[1], b[4] - b[2])		

		for k, v in ipairs(daMap._colliders) do
			love.graphics.rectangle( 'line', v[1] - cw[1], v[2] - cw[2], v[3] - v[1], v[4] - v[2])
		end
	end
	
	love.graphics.setPixelEffect()
	
	love.graphics.print('FPS: '..love.timer.getFPS(), 10, 20)
end

function love.update(dt)
	local vx, vy = 0, 0

	if love.keyboard.isDown('up') then
        girl:animation('walkup')		
		vy = -125
    elseif
		love.keyboard.isDown('down') then
        girl:animation('walkdown')		
		vy = 125
	end
	
	if love.keyboard.isDown('left') then
        girl:animation('walkleft')		
		vx = -125
    elseif
		love.keyboard.isDown('right') then
        girl:animation('walkright')		
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
	
	if love.keyboard.isDown('e') then
		showCollisionBoundaries = true
	end		

	if love.keyboard.isDown('d') then
		showCollisionBoundaries = false
	end		
	
	if love.keyboard.isDown('l') then
		spotLightEffect:send('pos', unpack({{400,300},{0,0}}))
		spotLightEffect:send('size', unpack({{300,225},{0,0}}))
		spotLightEffect:send('angle', unpack({{0,6.3},{0,0}}))
		spotLightEffect:send('lightColor', unpack({{2,2,2},{0,0,0}}))
		
		currentShader = spotLightEffect
	end
	
	if love.keyboard.isDown('o') then
		currentShader = nil
	end
	
	girl:velocity(vx, vy)
	
	if vx == 0 and vy == 0 then
		local anim = girl:animation():name():gsub('walk','stand')
		girl:animation(anim)
	end
	
	girl:update(dt)
	
	for k, v in ipairs(girls) do
		if math.random() > 0.95 then
			v:velocity(math.random()*200-100,math.random()*200-100)
		end
		v:update(dt)
	end
	
	-- @TODO collision detection
	-- amongst all actors and
	-- collidable objects	
	for k, v in pairs(daMap._colliders ) do
		local hit = true
		if v[1] > girl._boundary[3] or
			v[3] < girl._boundary[1] or
			v[2] > girl._boundary[4] or
			v[4] < girl._boundary[2] then
				hit = false
			end		
		if hit then
			girl:collide()
		end
	end
	
	daCamera:zoom(zoom)
	daCamera:center(girl._position[1], girl._position[2])
end
