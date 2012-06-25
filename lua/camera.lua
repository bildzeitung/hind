--[[
	camera.lua
	
	Created JUN-24-2012
]]

module (...,package.seeall)

--
--  Creats a new camera from the provided table
--
function _M:new(t)
	self.__index = self    
	setmetatable(t, self)
		
	t._window = { 0, 0, 800, 600 }
	t._viewport = { 0, 0, 800, 600 }
			
	return t
end

--
--  String representation of a camera
--
function _M:__tostring()
	return 'Window x:' .. self._window[1] .. ', y:'..
		self._window[2] .. ', w:'..
		self._window[3] .. ', h:'..
		self._window[4] .. 
		' Viewport w:' .. self._viewport[1] .. ', y:'..
		self._viewport[2] .. ', w:'..
		self._viewport[3] .. ', h:'..
		self._viewport[4] 	
end

--
--  Sets or gets  the camera viewport
--
function _M:viewport(x, y, w, h)
	if not w then
		return self._viewport
	end
	
	self._viewport[1] = x
	self._viewport[2] = y
	self._viewport[3] = w
	self._viewport[4] = h
end

--
--  Sets or gets  the camera window
--
function _M:window(x, y, w, h)
	if not w then
		return self._window
	end
	
	self._window[1] = x
	self._window[2] = y
	self._window[3] = w
	self._window[4] = h
end

--
--  Centers the window at a position
--
function _M:center(x, y)
	self:window(x - self._window[3] / 2, 
		y - self._window[4] / 2,
		self._window[3], self._window[4])
end

--
--  Sets the zoom level of the camera
function _M:zoom(z)
	self:window(self._window[1], 
		self._window[2], 
		self._viewport[3] / z, 
		self._viewport[4] / z)
end
