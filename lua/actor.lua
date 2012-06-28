--[[
	actor.lua
	
	Created JUN-21-2012
]]

local animation = require 'animation'

module(..., package.seeall)

--
--  Creats a new actor from the provided table
--
function _M:new(t)
	self.__index = self    
	setmetatable(t, self)
		
	t._inventory = {}

	t._screenPos = { 0, 0 }
	t._position = { 0, 0 }
	t._velocity = { 0, 0 }
	t._boundary = { 0, 0, 0, 0 }
	t._lastPosUpdate = { 0, 0 }
	t._bucketIds = {}
	t._map = nil
				
	return t
end

--
--  Sets or gets the current animation
--
--  Inputs:
--		a - an animation index or nil
--		r - true if the animation should be reset
--
function _M:animation(a, r)
	if not a then 
		return self._currentAnimation
	end
	
	self._currentAnimation = self._animations[a]
	if r then
		self._currentAnimation:reset()
	end	
end

--
--  Sets the map that the actor is acting on
--
function _M:map(m)
	self._map = m
end

--
--  Draw the actor
--
function _M:draw(camera, drawTable)
	local cw, cv, zoomX, zoomY, cwzx, cwzy =
		drawTable.cw, drawTable.cv, 
		drawTable.zoomX, drawTable.zoomY,
		drawTable.cwzx, drawTable.cwzy		

	local of = self._currentAnimation:offset()
	
	self._screenPos[1] = math.floor((self._position[1] * zoomX) 
		- cwzx)
	self._screenPos[2] = math.floor((self._position[2] * zoomY)
		- cwzy)
	
	local ts = self._currentAnimation:tileSet()
	local tq = ts:quads()
	local frame = self._currentAnimation:frame()
	
	table.insert(drawTable.object, 
		{ self._position[2] + of[2] - (self._position[1] * 0.0000000001), tq[frame], 
		self._screenPos[1], self._screenPos[2],
		zoomX, zoomY, of[1], of[2] })
end

--
--  Set or get the position
--
function _M:position(x, y)
	if not x then
		return self._position
	end
		
	self._position[1] = x
	self._position[2] = y
end


--
--  Set or get the screen position
--
function _M:screenPos(x, y)
	if not x then
		return self._screenPos
	end
		
	self._screenPos[1] = x
	self._screenPos[2] = y
end

--
--  Set or get the velocity 
--
function _M:velocity(x, y)
	if not x then
		return self._velocity[1], self._velocity[2]
	end
	
	self._velocity[1] = x
	self._velocity[2] = y
end

--
--  Called when the actor collides 
--  with another object
--
function _M:collide(other)
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
function _M:checkCollision(b)
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
function _M:spatialBuckets(b)
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
function _M:registerBuckets(buckets)	
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
function _M:calculateBoundary()	
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

--
--  Update function
--
function _M:update(dt)
	self._latestDt = dt
	
	self._lastPosUpdate[1] = (dt * self._velocity[1])
	self._lastPosUpdate[2] = (dt * self._velocity[2])
	
	self._position[1] = self._position[1] + self._lastPosUpdate[1]		
	self._position[2] = self._position[2] + self._lastPosUpdate[2]
	
	-- @TODO do we want to do bounds checking on position
	-- or just let map boundaries handle that by
	-- not letting the character go past a certain point
	local x, y = 800, 600
	local ms = self._map:size()
	if self._position[1] < x then self._position[1] = x end
	if self._position[1] > ms[1] - x then self._position[1] = ms[1] - x end
	if self._position[2] < y then self._position[2] = y end
	if self._position[2] > ms[2] - y then self._position[2] = ms[2] - y end	
	
	-- update the current animation
	self._currentAnimation:update(dt)
	
	-- calculate the bounding boxes
	self:calculateBoundary()
end

function _M:attack()
	-- can only attack once
	if self._isAttacking then
		return 
	end
	
	self._isAttacking = true
	
	self:velocity(0,0)
	
	local currentAnim = self:animation():name()
	local attackAnim = currentAnim:gsub('walk','attack')
	attackAnim = attackAnim:gsub('stand','attack')
	self:animation(attackAnim, true)
	self._currentAnimation.done_cb = function()
		self:animation(currentAnim)
		self._currentAnimation.done_cb = nil			
		self._isAttacking = false
	end
end