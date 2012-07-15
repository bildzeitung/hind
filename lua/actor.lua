--[[
	actor.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

require 'log'

local table, pairs, ipairs, love, print
	= table, pairs, ipairs, love, print
	
module('objects')

Actor = Object{}

--
--  Actors support the following Events:
--
--		on_begin_attack() - will be called when the actor begins attacking
--		on_end_attack() - will be called when the actor ends attacking
--		on_take_damage(damage) - will be called when the actor takes damage
--		on_begin_die(other) - will be called when the actor's health falls below 0
--							other is the actor that caused the health to fall below 0
--		on_end_die(other) - will be called when the actor's dyig animation is finished
--


--
--  Actor constructor
--
function Actor:_clone(values)
	local o = table.merge(
		Drawable(values),
		table.merge(
			Collidable(values),
			Object._clone(self,values)
		))
			
	o._itemDrawOrder = { 'weapon', 'hands', 'head', 'belt', 
		'torso', 'legs', 'feet', 'body', 'behind' }
  
	o._equipped = {}
	o._inventory = {}
  	o._lastPosUpdate = { 0, 0 }	
	o._velocity = { 0, 0 }
	o._map = nil
	o.ACTOR = true
	o._isAttacking = false
	o._health = 20
	o._isDying = false
	
	return o
end

--
--  Sets the map that the actor is acting on
--
function Actor:map(m)
	self._map = m
end

--
--  Set or get the velocity 
--
function Actor:velocity(x, y)
	if not x then
		return self._velocity[1], self._velocity[2]
	end
	
	self._velocity[1] = x
	self._velocity[2] = y
end

--
--  Update function
--
function Actor:update(dt)
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
	
	for _, v in pairs(self._equipped) do
		v:update(dt)
	end
end

--
--  Attack!
--  n.b. this function should probably live somewhere else
--  such as where the actors behaviour is defined (.dat file?)
-- 
function Actor:attack()
	-- can only attack when not already attacking
	if self._isAttacking then
		return 
	end
	
	self._isAttacking = true
						
	-- pick the correct attack animation
	local currentAnim = self:animation():name()
	local attackAnim = currentAnim:gsub('walk','attack')
	attackAnim = attackAnim:gsub('stand','attack')
	
	-- switch to the attack animation
	self:animation(attackAnim, true)
	self._currentAnimation.done_cb = function()
		self:animation(currentAnim, true)
		self._currentAnimation.done_cb = nil			
		self._isAttacking = false
		
		if self.on_end_attack then
			self:on_end_attack()
		end
	end
	
	if self.on_begin_attack then
		self:on_begin_attack()
	end	
end

--
--  Equips an item
--
function Actor:equipItem(slot, item)
	self._equipped[slot] = item
	item._actor = self
	
	-- ignore collisions between the items and the actor
	self:ignoreCollision(item)	
	item:ignoreCollision(self)	
	-- ignore collisions between the items themselves
	for _, i in pairs(self._equipped) do
		i:ignoreCollision(item)
		item:ignoreCollision(i)
	end
	
	if self._currentAnimation then
		item:animation(self._currentAnimation:name())
	end
end

--
--  Sets or gets the current animation
--
--  Inputs:
--		a - an animation index or nil
--		r - true if the animation should be reset
--
local base_animation = Drawable.animation
function Actor:animation(a, r)	
	local ret = base_animation(self, a, r)
	
	if a then
		-- set the animations for the equipped items
		for _, item in pairs(self._equipped) do
			item:animation(a, r)
		end
	end
	
	return ret
end

--
--  Draw the actor
--
local base_draw = Drawable.draw
function Actor:draw(camera, drawTable)
	base_draw(self, camera, drawTable)
	
	for _, v in ipairs(self._itemDrawOrder) do
		if self._equipped[v] then
			self._equipped[v]:draw(camera, drawTable)
		end
	end
end

--  Registers the actor in the proper
--     collision buckets
--
local base_registerBuckets = Collidable.registerBuckets
function Actor:registerBuckets(buckets)
   base_registerBuckets(self, buckets)

   -- register items in the buckets too
   for k, item in pairs(self._equipped) do
	   item:registerBuckets(buckets)
   end
end

--
--  Called when a collidable collides with
--  another object
--
local base_collide = Collidable.collide
function Actor:collide(other)	
	if self._lastPosUpdate[1] ~= 0 or self._lastPosUpdate[2] ~= 0 then
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
		
		self:calculateBoundary()		
		for _, item in pairs(self._equipped) do
			item:update(0)
		end	
	end
		
	base_collide(self, other)
end

--
--  Takes damage
--
function Actor:takeDamage(damage, other)
	print('==============================')
	print('HIT!')
	print('Health before: ' .. self._health)	

	self._health = self._health - damage	

	print('Health after: ' .. self._health)	
	print('------------------------------')

	if self.on_take_damage then
		self:on_take_damage(damage)
	end
	
	if self._health <= 0 then
		self._health = 0
		self._isDying = true
		if self.on_begin_die then
			self:on_begin_die(other)
		end
		self:die(other)
	end
end
	
--
--  Called when the actor's health reaches zero
--
function Actor:die(other)	
	self:velocity(0,0)	
	self:animation('die', true)
	self._currentAnimation.done_cb = function()
		self._currentAnimation.done_cb = nil	
		if self.on_end_die then
			self:on_end_die(other)
		end
	end
end	

--
--  Does damaga
--
function Actor:doDamage(other)
	if self._damage then
		print(other._id)
		other:takeDamage(self._damage, self)
	else
		local weapon = self._equipped['weapon']
		if weapon then
			other:takeDamage(weapon._damage, self)
		end	
	end
end