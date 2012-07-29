--[[
	drawable.lua
	
	Created JUL-11-2012
]]

local Object = (require 'object').Object

require 'animation'

local pairs, math
	= pairs, math
	
module('objects')

Drawable = Object{}

--
--  Drawable constructor
--
function Drawable:_clone(values)
	local o = Object._clone(self,values)
	
	o._screenPos = values._screenPos or { 0, 0 }
	o._position = values._position or { 0, 0 }
	o._drawTableEntry = { true, true, true, true, 
		true, true, true, true }
	o._direction = values._direction or 'right'
	
	return o
end

--
--  Sets or gets the current direction
--  
function Drawable:direction(d)
	if not d then return self._direction end
	
	if self._direction ~= d then
		self._changeDirection = true
	end
	
	self._direction = d
end

--
--  Sets or gets the current animation
--
--  Inputs:
--		a - an animation index or nil
--		r - true if the animation should be reset
--
function Drawable:animation(a, r)
	if not a then 
		return self._currentAnimation
	end
	
	-- switch to the new animation
	if self._animations[a] then
		self._currentAnimation = self._animations[a]
	else
		self._currentAnimation = self._animations[a .. self._direction]
	end				
	
	if r then
		self._currentAnimation:reset()
	end	
end

--
--  Draw the drawable
--
function Drawable:draw(camera, drawTable)
	local cw, cv, zoomX, zoomY, cwzx, cwzy =
		drawTable.cw, drawTable.cv, 
		drawTable.zoomX, drawTable.zoomY,
		drawTable.cwzx, drawTable.cwzy		

	local object = drawTable.object
		
	local of = self._currentAnimation:offset()
	
	self._screenPos[1] = math.floor((self._position[1] * zoomX) 
		- cwzx)
	self._screenPos[2] = math.floor((self._position[2] * zoomY)
		- cwzy)
	
	local ts = self._currentAnimation:tileSet()
	local tq = ts:quads()
	local frame = self._currentAnimation:frame()
	
	self._drawTableEntry[1] = self._position[2] + of[2] - (self._position[1] * 1e-14)
	self._drawTableEntry[2] = tq[frame]
	self._drawTableEntry[3] = self._screenPos[1]
	self._drawTableEntry[4] = self._screenPos[2]
	self._drawTableEntry[5] = zoomX
	self._drawTableEntry[6] = zoomY
	self._drawTableEntry[7] = of[1]
	self._drawTableEntry[8] = of[2]
			
	object[#object+1] = self._drawTableEntry
end

--
--  Set or get the position
--
function Drawable:position(x, y)
	if not x then
		return self._position
	end
		
	self._position[1] = x
	self._position[2] = y
end

--
--  Get the distance from another drawable
--
function Drawable:distanceFrom(other)
	local x = self._position[1] - other._position[1]
	local y = self._position[2] - other._position[2]
	return math.sqrt(x*x+y*y)
end


--
--  Set or get the screen position
--
function Drawable:screenPos(x, y)
	if not x then
		return self._screenPos
	end
		
	self._screenPos[1] = x
	self._screenPos[2] = y
end