--[[
	collidable.lua
	
	Created JUL-11-2012
]]

local Object = (require 'object').Object

local pairs
	= pairs
	
module('objects')

Collidable = Object{}

--
--  Collidable constructor
--
function Collidable:_clone(values)
	local o = Object._clone(self,values)
	
	o._position = { 0, 0 }
	
	o._boundary = { 0, 0, 0, 0 }
	o._lastPosUpdate = { 0, 0 }
	o._bucketIds = {}	
	
	return o
end

--
--  Set or get the position
--
function Collidable:position(x, y)
	if not x then
		return self._position
	end
		
	self._position[1] = x
	self._position[2] = y
end

--
--  Called when the actor collides 
--  with another object
--
function Collidable:collide(other)
	if self._lastPosUpdate[1] ~= 0 or 
		self._lastPosUpdate[2] ~= 0 then		
			-- check if reversing the last update moves the
			-- actor farther away from the other object
			local xdiff = other._position[1] - self._position[1]
			local ydiff = other._position[2] - self._position[2]			
			local currentDist = xdiff * xdiff + ydiff * ydiff

			local xdiff = other._position[1] - 
				(self._position[1] - self._lastPosUpdate[1])
			local ydiff = other._position[2] - 
				(self._position[2] - self._lastPosUpdate[2])
			local possibleDist = xdiff * xdiff + ydiff * ydiff

			if currentDist < possibleDist then
				self._position[1] = self._position[1] - self._lastPosUpdate[1]		
				self._position[2] = self._position[2] - self._lastPosUpdate[2]
				self._lastPosUpdate[1] = 0
				self._lastPosUpdate[2] = 0
			end
	end
	
	self._collidee = other
	
	-- calculate the bounding boxes
	self:calculateBoundary()	
end

--
--  Checks for collision with nearby objects
--
function Collidable:checkCollision(b)
	self._collidee = nil
	
	for k, _ in pairs(self._bucketIds) do
		for _, v in pairs(b[k]) do
			if v ~= self then
				local hit = true		
				if v._boundary[1] > self._boundary[3] or
					v._boundary[3] < self._boundary[1] or
					v._boundary[2] > self._boundary[4] or
					v._boundary[4] < self._boundary[2] then
					hit = false
				end			
				if hit then	
					self:collide(v)
					if v.collide then	
						v:collide(self)
					end
				end
			end
		end
	end
end


--
--  Returns the spatial buckets 
--  that the object currently occupies
--
function Collidable:spatialBuckets(b)
	local ids = {}
		
	ids[b.hash(self._boundary[1], self._boundary[2])] = true
	ids[b.hash(self._boundary[1], self._boundary[4])] = true
	ids[b.hash(self._boundary[3], self._boundary[2])] = true
	ids[b.hash(self._boundary[3], self._boundary[4])] = true
	
	return ids
end

--
--  Registers the actor in the proper
--	collision buckets
--
function Collidable:registerBuckets(buckets)	
	-- unregister the old bucket ids
	for k, _ in pairs(self._bucketIds) do
		buckets[k][self._id] = nil
	end	
	
	-- calculates the spatial buckets
	self._bucketIds = self:spatialBuckets(buckets)
	
	-- register the new buckets ids
	for k, _ in pairs(self._bucketIds) do
		buckets[k][self._id] = self
	end	
end

--
--  Performs a collision calculation
--
function Collidable:calculateBoundary()	
	-- update the boundary box 
	local ts = self._currentAnimation:tileSet()
	local bs = ts:boundaries()
	local boundary = bs[self._currentAnimation:frame()]
	local of = self._currentAnimation:offset()	
	self._boundary[1] = self._position[1] + boundary[1] - of[1]
	self._boundary[2] = self._position[2] + boundary[2] - of[2]
	self._boundary[3] = self._position[1] + boundary[3] - of[1]
	self._boundary[4] = self._position[2] + boundary[4] - of[2]
end