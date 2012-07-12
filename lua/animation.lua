--[[
	animation.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

module('objects')

Animation = Object{}

--
--  Animation constructor
--
function Animation:_clone(values)
	local o = Object._clone(self,values)
	
	o:reset()
	
	return o
end


--
--  Updates an animation
--
--  Outputs:
--		the new frame number if the frame should change
--
function Animation:update(dt)
	self._frameCounter = self._frameCounter + dt
	if self._frameCounter >= self._frameDuration then		
		self._frameCounter = 0
		
		self._currentFrame = self._currentFrame + self._frameDir
		if self._currentFrame > self._frameEnd or 
			self._currentFrame < self._frameStart then
			if self._looping == 'pingpong' then
				self._currentFrame = self._currentFrame 
					- (self._frameDir * 2)
				self._frameDir = -self._frameDir				
			elseif self._looping == 'loop' then
				self._currentFrame = self._frameStart
			elseif self._looping == 'onceboth' then
				if self._currentFrame < self._frameStart then
					-- end the animation
					if self.done_cb then
						self.done_cb(self)
					end
					self._frameDir = 0
				else
					self._currentFrame = self._currentFrame 
						- (self._frameDir * 2)
					self._frameDir = -self._frameDir
				end
			elseif self._looping == 'once' then
				self._currentFrame = self._frameEnd
				self._frameDir = 0
				-- end the animation
				if self.done_cb then
					self.done_cb(self)
				end
			end
		end		
	end
end

--
--  Resets the animation
--
function Animation:reset()
	self._frameCounter = 0
	self._frameDir = 1
	self._currentFrame = self._frameStart
end

--
--  Returns the name of this animation
--
function Animation:name()
	return self._name
end

--
--  Returns the current frame of the animation
--
function Animation:frame()
	return self._currentFrame
end

--
--  Returns the tile set for this animation
--
function Animation:tileSet()
	return self._tileSet
end

--
--  Returns the offset of the animation
--
function Animation:offset()
	return self._offset
end