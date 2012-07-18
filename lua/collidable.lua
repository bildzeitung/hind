--[[
	collidable.lua
	
	Created JUL-11-2012
]]

local Object = (require 'object').Object

local pairs, table, print
	= pairs, table, print
	
module('objects')

Collidable = Object{}

--
--  Collidable support the following Events:
--		on_collide(other) - will be called when the collidable collides
--							with another collidable
--

--
--  Collidable constructor
--
function Collidable:_clone(values)
	local o = Object._clone(self,values)
	
	o._position = { 0, 0 }	
	o._boundary = { 0, 0, 0, 0 }
	o._bucketIds = {}	
	o._ignores = {}
	o._collidees = {}
	o:ignoreCollision(o)
	
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
--  Called when a collidable collides with
--  another object
--
function Collidable:collide(other)
	if self.on_collide then
		self:on_collide(other)
	end
end

--
--  Checks for collision with nearby objects
--
function Collidable:checkCollision(b)
	self._collidee = nil

	for k, _ in pairs(self._bucketIds) do
		for _, v in pairs(b[k]) do
			if not self._ignores[v._id] then
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
--  Adds an item to the collision ignore list
--
function Collidable:ignoreCollision(item)
	self._ignores[item._id] = true
end

--
--  Removes an item from the collision ignore list
--
function Collidable:allowCollision(item)
	self._ignores[item._id] = nil
end

--
--  Resets collision status
--
function Collidable:resetCollisions()
	self._collidees = {}
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