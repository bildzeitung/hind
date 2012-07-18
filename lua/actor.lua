--[[
	actor.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

local log = require 'log'

local table, pairs, ipairs, type, love
	= table, pairs, ipairs, type, love
	
module('objects')

Actor = Object{}

--
--  Actors support the following Events:
--
--		on_begin_X() - will be called when the actor begins an action
--		on_end_X() - will be called when the actor begins an action
--		on_take_damage(damage) - will be called when the actor takes damage
--

--
--  Actor constructor
--
function Actor:_clone(values)
	local o = table.merge(
		table.merge(Collidable(values), Drawable(values)),
		Object._clone(self,values))
			
	o._dialogs = {}	
  	o._lastPosUpdate = { 0, 0 }	
	o._velocity = { 0, 0 }
	o._map = nil
	o.ACTOR = true
	o._currentAction = nil	
	o._health = 20	
	
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
end

--
--  Returns the direction the actor is facing
--  
function Actor:direction()
	local currentAnim = self:animation():name()
	if currentAnim:find('left') then return 'left' end
	if currentAnim:find('right') then return 'right' end
	if currentAnim:find('up') then return 'up' end
	if currentAnim:find('down') then return 'down' end
end

--
--  Do an action
-- 
function Actor:action(name, cancel)
	if not name then return self._currentAction end
	
	-- can only do an action when not doing an action
	if self._currentAction and not cancel then
		return 
	end
	
	-- an action is cancelled if 
	-- on_begin_X returns false	
	local retval	
	if self['on_begin_' .. name] then
		retval = self['on_begin_' .. name](self)
	end		
	if retval == false then return end
	
	-- set the current action
	self._currentAction = name
						
	-- save old animation
	local currentAnim
	if self._currentAnimation then
		currentAnim = self._currentAnimation:name()
	end
	-- switch to the new animation
	if self._animations[name] then
		self:animation(name, true)
	else
		self:animation(name .. self:direction(), true)
	end	
	-- set the callback for when the animation ends
	self._currentAnimation.done_cb = function()
		if currentAnim then
			self:animation(currentAnim, true)
		end
		
		self._currentAnimation.done_cb = nil			
		self._currentAction = nil
		
		if self['on_end_' .. name] then
			self['on_end_' .. name](self)
		end
	end	
end

--
--  Called when a collidable collides with
--  another object
--
function Actor:collide(other)	
	-- only adjust positions for blocking items
	if not other._nonBlocking then
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
		end
	end
	
	Collidable.collide(self, other)
end

--
--  Takes damage
--
function Actor:takeDamage(damage, other)
	self._health = self._health - damage	

	if self.on_take_damage then
		self:on_take_damage(damage)
	end
	
	if self._health <= 0 then
		self._health = 0
		self._killer = other
		self:action('die', true)
	end
end

--
--  Does damaga
--
function Actor:doDamage(other)
	if self._damage then
		other:takeDamage(self._damage, self)
	end	
end

--
--  Sets or gets the actors name
--
function Actor:name(n)
	if not n then return self._name end
	self._name = n
end

--
--  Adds a dialog to the actor
--
function Actor:addDialog(d)
	self._dialogs[d:name()] = d
end

--
--  Removes a dialog from the actor
--
function Actor:removeDialog(d)
	if type(d) == 'string' then
		self._dialogs[d] = nil
	else
		self._dialogs[d:name()] = nil
	end
end

--
--  The list of dialogs this actor currently owns
--
function Actor:dialogs()
	return self._dialogs
end