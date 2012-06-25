--[[
	animation.lua
	
	Created JUN-21-2012
]]

module(..., package.seeall)

--
--  Creates a new animation from a table of values
--
function _M:new(t)
	self.__index = self    
	setmetatable(t, self)
		
	t._currentFrame = t._frameStart
	t._frameCounter = 0
	t._frameDir = 1
	
	return t
end


--
--  Updates an animation
--
--  Outputs:
--		the new frame number if the frame should change
--
function _M:update(dt)
	self._frameCounter = self._frameCounter + dt
	if self._frameCounter >= self._frameDuration then		
		self._frameCounter = 0
		
		self._currentFrame = self._currentFrame + self._frameDir
		if self._currentFrame > self._frameEnd or self._currentFrame < 1 then
			if self._looping == 'pingpong' then
				self._currentFrame = self._currentFrame 
					- (self._frameDir * 2)
				self._frameDir = -self._frameDir				
			elseif self._looping == 'loop' then
				self._currentFrame = self._frameStart
			elseif self._looping == 'once' then
			end
		end		
	end
end

--
--  Resets the animation
--
function _M:reset()
	self._frameCounter = 0
	self._currentFrame = self._frameStart
end

--
--  Returns the name of this animation
--
function _M:name()
	return self._name
end

--
--  Returns the current frame of the animation
--
function _M:frame()
	return self._currentFrame
end

--
--  Returns the tile set for this animation
--
function _M:tileSet()
	return self._tileSet
end

--
--  Returns the offset of the animation
--
function _M:offset()
	return self._offset
end