--[[
	renderer.lua
	
	Created JUL-12-2012
]]

local Object = (require 'object').Object

local love, pairs, ipairs, type, table, unpack
	= love, pairs, ipairs, type, table, unpack
	
module('objects')

Renderer = Object{}

--
--  Actor constructor
--
function Renderer:_clone(values)
	local o = Object._clone(self,values)

	-- spot lights are in screen space coordinates
	-- origin, spotsize, falloff are in
	-- texture space? screen space?
	--
	o._maxLights = 6
	
	o._currentShader = nil
	o._shaders = {}
	
	o._lighting = {
		originMinMax = { 0.2, 0.8 },
		origin = { 0.2, 0.4 },
		spotSize = { 0.25 },
		fallOff = { 0.25 },		
		shadowSkewMinMax = { -2, 2 },
		shadowSkew = { -2, 0 },		
		spotLights = { pos = {}, screenPos = {}, size = {}, screenSize = {}, 
			angle = {}, lightColor = {}, world = {} }
	}
	
	for i = 1, o._maxLights do
		o._lighting.spotLights.pos[i] = {0,0}
		o._lighting.spotLights.screenPos[i] = {0,0}
		o._lighting.spotLights.size[i] = {0,0}
		o._lighting.spotLights.screenSize[i] = {0,0}
		o._lighting.spotLights.angle[i] = {0,0}
		o._lighting.spotLights.lightColor[i] = {0,0,0}
		o._lighting.spotLights.world[i] = false
	end
	
	o:loadShaders()
	
	o._drawTable = { 
		cw = true, cv = true, 
		zoomX = true, zoomY = true, 
		cwzx = true, cwzt = true,
		object = {},
		roof = {},
		text = {}	
	}	
	
	o._zSortFn = function(a,b) return a[1] < b[1] end

	return o
end

--
--  Creates the custom shaders
--
function Renderer:loadShaders()	
	self._shaders.light = love.graphics.newPixelEffect [[
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
	
	self._shaders.shadow = love.graphics.newPixelEffect [[
		vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
		{
			color = Texel( texture, texture_coords );
			color.rgb *= 0;
			color.a /= 2;
			return color;
		}	
	]]	
end

--
--  Set the directional light parameters
--
function Renderer:setDirectionalLight(params)	
	for k, v in pairs(params) do
		self._lighting[k] = v
	end
end
	
--
--  Set the directional light parameters
--
function Renderer:setSpotLight(params)	
	local idx = params.idx
	params.idx = nil
	for k, v in pairs(params) do
		self._lighting.spotLights[k][idx] = v
	end
end
	
--
--  Update the light effect
--
-- 	@TODO
--	cloning a table like this every frame is horrific
--  this code needs to change if we are going to use dynamic lighting!!!
--
function Renderer:updateLightEffect(camera)
	--[[
	self._shaders.light:send('origin', self._lighting.origin)
	self._shaders.light:send('fallOff', self._lighting.fallOff)
	self._shaders.light:send('spotSize', self._lighting.spotSize)
	
	local t = table.clone(self._lighting.spotLights,{deep = true})
	
	local cw = camera:window()
	local cv = camera:viewport()
	local zoomX = cv[3] / cw[3]
	
	-- convert world position to screen position
	for k, pos in ipairs(t.pos) do		
		-- convert to screen space
		if t.world[k] then
			t.pos[k][1] = (pos[1] - cw[1]) / cw[3] * cv[3]
			t.pos[k][2] = cv[4] - ((pos[2] - cw[2]) / cw[4] * cv[4])		
		end
		self._lighting.spotLights.screenPos[k] = { t.pos[k][1], t.pos[k][2] }
	end
	
	-- convert world size to screen size
	for k, size in ipairs(t.size) do
		-- convert to screen space
		if t.world[k] then
			t.size[k][1] = size[1] * (cv[3] / cw[3])
			t.size[k][2] = size[2] * (cv[4] / cw[4])			
		end
		self._lighting.spotLights.screenSize[k] = { t.size[k][1], t.size[k][2] }		
	end

	local paramsToSend = { pos = true, size = true, 
		angle = true, lightColor = true }
	
	-- send all of the parameters
	for k, v in pairs(t) do
		if paramsToSend[k] then
			self._shaders.light:send(k, unpack(v))
		end
	end
	]]
end

--
--  Render a list of drawable items
-- 
function Renderer:draw(camera, drawables, profiler)	
	local drawTable = self._drawTable
	
	for k, v in pairs(drawTable.object) do
		drawTable.object[k] = nil
	end
	for k, v in pairs(drawTable.roof) do
		drawTable.roof[k] = nil
	end
	for k, v in pairs(drawTable.text) do
		drawTable.text[k] = nil
	end

	-- set up the draw table
	--profiler:profile('pre-calculating draw stuff', function()
			-- pre calculate what we can
			drawTable.cw = camera:window()
			drawTable.cv = camera:viewport()	
			drawTable.zoomX = drawTable.cv[3] / drawTable.cw[3] 
			drawTable.zoomY = drawTable.cv[4] / drawTable.cw[4] 
			drawTable.cwzx = drawTable.cw[1] * drawTable.zoomX
			drawTable.cwzy = drawTable.cw[2] * drawTable.zoomY
		--end) -- profile
			
	--[[			
	--profiler:profile('updating lighting effect', function()
			love.graphics.setPixelEffect(self._currentShader)				
			self:setDirectionalLight( { spotSize = 2 } )
			self:updateLightEffect(camera)
		--end) -- profile
	]]
		
	-- pre draw the drawable items
	for k, t in pairs(drawables) do		
		--profiler:profile('pre-drawing ' .. k .. ' drawables', function()	
				if type(t) == 'table' and t.draw then
					t:draw(camera, drawTable)
				else
					for _, i in pairs(t) do
						i:draw(camera, drawTable)
					end
				end
			--end) -- profile
	end
	
	--profiler:profile('z-sorting', function()	
			table.sort(drawTable.object,self._zSortFn)
			table.sort(drawTable.roof,self._zSortFn)
		--end) -- profile
	
		--[[
	--profiler:profile('updating lighting for objects', 		
		function()
			self:setDirectionalLight( { spotSize = 0.3 } )
			self:updateLightEffect(camera)
		--end) -- profile
		]]
	
	-- @TODO the shadow direction
	-- should be calculated based on the position
	-- and size of all of the current spot lights
	-- in screen space

	-- draw the objects and their shadows
	--profiler:profile('drawing objects and actors and shadows', function()
			for k, v in ipairs(drawTable.object) do
				love.graphics.setPixelEffect(self._shaders.shadow)				
					
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8], 
					self._lighting.shadowSkew[1], 
					self._lighting.shadowSkew[2])
			
				love.graphics.setPixelEffect(self._currentShader)			
			
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8])
			end	
	--end) -- profile
	
	-- draw the roof shadows
	--profiler:profile('drawing roof shadows', function()	
			love.graphics.setPixelEffect(self._shaders.shadow)				
			for k, v in ipairs(drawTable.roof) do		
				love.graphics.draw(v[2],
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8], 
					self._lighting.shadowSkew[1], 
					self._lighting.shadowSkew[2])
			end
		--end) -- profile
	
	-- draw the roof objects	
	--profiler:profile('drawing roof tiles', function()	
			love.graphics.setPixelEffect(self._currentShader)		
			for k, v in ipairs(drawTable.roof) do	
				love.graphics.draw(v[2], 
					v[3], v[4], 0, v[5], v[6], 
					v[7], v[8])
			end		
		--end) -- profile

	-- render all of the text objects
	--profiler:profile('drawing text objects', function()		
			for k, v in ipairs(drawTable.text) do
				love.graphics.setFont(v[2])
				love.graphics.setColor(unpack(v[3]))
				love.graphics.print(v[1], v[4], v[5], 0, 
					drawTable.zoomX, drawTable.zoomY)	
			end
		--end) -- profile
end

--
--  Returns the maximum number of lights
--
function Renderer:maxLights()
	return self._maxLights
end

--
--  Sets the current shader
--
function Renderer:shader(s)
	self._currentShader = self._shaders[s]
end