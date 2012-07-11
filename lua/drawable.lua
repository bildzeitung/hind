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
	
	o._screenPos = { 0, 0 }
	o._position = { 0, 0 }
	
	return o
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
	
	self._currentAnimation = self._animations[a]
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
	
	object[#object+1] = { 
		self._position[2] + of[2] - (self._position[1] * 1e-14),
		tq[frame], self._screenPos[1], self._screenPos[2],
		zoomX, zoomY, of[1], of[2] }
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
--  Set or get the screen position
--
function Drawable:screenPos(x, y)
	if not x then
		return self._screenPos
	end
		
	self._screenPos[1] = x
	self._screenPos[2] = y
end