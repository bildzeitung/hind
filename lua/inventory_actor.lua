--[[
	actor.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'actor'

local log = require 'log'

local table, pairs, ipairs, type, love
	= table, pairs, ipairs, type, love
	
module('objects')

InventoryActor = Object{}

--
--  InventoryActor constructor
--
function InventoryActor:_clone(values)
	local o = table.merge(Actor(values), Object._clone(self,values))
			
	o._itemDrawOrder = { 'weapon', 'hands', 'head', 'belt', 
		'torso', 'legs', 'feet', 'body', 'behind' }
  
	o._equipped = {}
	o._inventory = {}
	o.INVENTORYACTOR = true
	
	return o
end

--
--  Update function
--
function InventoryActor:update(dt)
	Actor.update(self, dt)

	for k, v in pairs(self._equipped) do
		v:update(dt)
	end
end

--
--  Sets or gets the current animation
--
--  Inputs:
--		a - an animation index or nil
--		r - true if the animation should be reset
--
function InventoryActor:animation(a, r)	
	if a and self._currentAnimation then
		self._currentAnimation.on_frame_change = nil
	end
	
	local ret = Drawable.animation(self, a, r)
	
	if a then
		-- set the animations for the equipped items
		for _, item in pairs(self._equipped) do
			item:animation(a, r)
		end
	
		-- sync the animations
		self._currentAnimation.on_frame_change = function(anim)
			for _, item in pairs(self._equipped) do
				if item._currentAnimation._frameStart == anim._frameStart and
					item._currentAnimation._frameEnd == anim._frameEnd then
					item._currentAnimation._frameCounter = anim._frameCounter
					item._currentAnimation._frameDir = anim._frameDir
					item._currentAnimation._currentFrame = anim._currentFrame
				end
			end
		end
	end
	
	return ret
end

--
--  Draw the actor
--
function InventoryActor:draw(camera, drawTable)
	Drawable.draw(self, camera, drawTable)
	
	for _, v in ipairs(self._itemDrawOrder) do
		if self._equipped[v] then
			self._equipped[v]:draw(camera, drawTable)
		end
	end
end

--  Registers the actor in the proper
--     collision buckets
--
function InventoryActor:registerBuckets(buckets)
   Collidable.registerBuckets(self, buckets)

   -- register items in the buckets too
   for k, item in pairs(self._equipped) do
	   item:registerBuckets(buckets)
   end
end

--
--  Called when a collidable collides with
--  another object
--
function InventoryActor:collide(other)		
	Actor.collide(self, other)	
	
	for _, item in pairs(self._equipped) do
		item:update(0)
	end	
end

--
--  Does damaga
--
function InventoryActor:doDamage(other)
	if self._damage then
		other:takeDamage(self._damage, self)
	else
		local weapon = self._equipped['weapon']
		if weapon then
			other:takeDamage(weapon._damage, self)
		end	
	end
end

--
--  Returns the actor's inventory
--
function InventoryActor:inventory()
	return self._inventory
end

--
--  Returns the actor's equipped inventory
--
function InventoryActor:equipped()
	return self._equipped
end

--
--  Returns true if the actor's inventory contains the 
--	provided item
--  
function InventoryActor:inventoryContains(item)
	for k, v in ipairs(self._inventory) do			
		if type(item) == 'string' then
			if v:name() == item then return true end
		elseif item.name then
			if v:name() == item:name() then return true end
		end
	end
	return false
end

--
--  Returns true if the provided item fits in the 
--	Actor's inventory, false otherwise
--  
function InventoryActor:itemFits(item)
	if #self._inventory < self._maxInventoryCount then
		return true
	end
		
	if item:stackable() then
		for k, v in ipairs(self._inventory) do
			if v:name() == item:name() and 
				v:count() < v:maxCount() then
					return true
			end
		end			
	end
	
	return false
end

--
--  Discards an item from the Actor's inventory
--  
function InventoryActor:removeItem(item)
	for k, v in ipairs(self._inventory) do
		if type(item) == 'string' then
			if v:name() == item then 
				table.remove(self._inventory, k)
				return
			end
		elseif type(item) == 'number' then
			if k == item then
				table.remove(self._inventory, k)
				return
			end
		elseif item.name then
			if v:name() == item:name() then
				table.remove(self._inventory, k)
				return
			end
		end
	end
end

--
--  Adds an item to the Actor's inventory
--	returns true if the item was added
--	false otherwise
--
function InventoryActor:addItem(item)
	if not self:itemFits(item) then			
		if self.on_add_item_fail then			
			self:on_add_item_fail(item)
		end
		return nil
	end
	
	local added = false

	if item:stackable() then
		for k, v in ipairs(self._inventory) do
			if v:name() == item:name() and 
				v:count() < v:maxCount() then
					v:count(1)
					added = true
					break				
			end
		end			
	end

	if not added then
		table.insert(self._inventory, item)
		item:count(1, true)
	end
	
	return true
end

--
--  Equips an item
--
function InventoryActor:equipItem(slot, item)
	-- ignore collisions between the items and the actor
	self:ignoreCollision(item)	
	item:ignoreCollision(self)	
	-- ignore collisions between the equipped items
	for _, i in pairs(self._equipped) do
		i:ignoreCollision(item)
		item:ignoreCollision(i)
	end
	
	self._equipped[slot] = item
	item._actor = self	
	
	if self._currentAnimation then
		item:animation(self._currentAnimation:name())
	end
	
	return true
end


--
--  Unequips an item
--
function InventoryActor:unequipItem(slot)
	local item = self._equipped[slot]
	
	-- allow collisions between the items and the actor
	self:allowCollision(item)	
	item:allowCollision(self)	
	-- allow collisions between the equipped items
	for _, i in pairs(self._equipped) do
		i:allowCollision(item)
		item:allowCollision(i)
	end
	
	self._equipped[slot] = nil
	item._actor = nil	
	
	return true
end