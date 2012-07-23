--[[
	actor.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

local log = require 'log'

local factories = require 'factories'

local table, pairs, ipairs, type, love
	= table, pairs, ipairs, type, love
	
module('objects')

Actor = Object{}

--
--  Returns a new actor loaded
--	from the provided data file
--
--  Inputs:
--		filename - the name of the data file
--		that describes the actor
--		existing - a table with existing information to merge into
--		the actor (for deserialization)
--
function Actor.create(filename, existing)
	local t = factories.prepareActor(filename, existing)
	local a = Actor(t)
	return a
end

--
--  Actors support the following Events:
--
--		on_begin_X() - will be called when the actor begins an action
--		on_end_X() - will be called when the actor begins an action
--		on_set_health() - will be called when health is updated
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
	o.ACTOR = true
	o._currentAction = nil	
	o._health = values._health or 0
	o._maxHealth = values._maxHealth or o._health
	
	return o
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

--
--  Sets or gets the Actor's health
--
function Actor:health(value, absolute, other)
	if not value then return self._health end
	
	if absolute then 
		self._health = value
	else
		self._health = self._health + value
	end
	
	if self._health > self._maxHealth then
		self._health = self._maxHealth		
	end
	
	if self._health <= 0 then
		self._health = 0
		self._killer = other
		self:action('die', true)
	end	
	
	if self.on_set_health then
		self:on_set_health(self._health, value)
	end	
end

--
--  Sets or gets the Actor's maxHealth
--
function Actor:maxHealth(value, absolute)
	if not value then return self._maxHealth end
	
	if absolute then 
		self._maxHealth = value
	else
		self._maxHealth = self._maxHealth + value
	end
end

--
--  Defines serialization / deserialization
--
function Actor:__persist()
	local t =
	{
		_filename = self._filename,
		_id = self._id,
		_name = self._name,
		_health = self._health,
		_maxHealth = self._maxHealth,
		_currentAnimation = self._currentAnimation._name,
		_lastPosUpdate = { self._lastPosUpdate[1], self._lastPosUpdate[2] },
		_position = { self._position[1], self._position[2] },
		_velocity = { self._velocity[1], self._velocity[2] },
		--_ignores,
		--_dialogs,
		--_collidees
	}
	return function()
		local a = objects.Actor.create(t._filename, t)		
		a:animation(a._currentAnimation)		
		return a
	end
end