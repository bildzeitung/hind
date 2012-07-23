--[[
	actor.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

local factories = require 'factories'

local pairs, table, print
	= pairs, table, print
	
module('objects')

ActorItem = Object{}

--
--  Returns a new actor item loaded
--	from the provided data file
--
--  Inputs:
--		filename - the name of the data file
--		that describes the actor
--		existing - a table with existing information to merge into
--		the actor (for deserialization)
--
function ActorItem.create(filename, existing)
	local t = factories.prepareActor(filename, existing)
	local a = ActorItem(t)
	return a
end

--
--  ActorItem constructor
--
function ActorItem:_clone(values)
	local o = table.merge(
		table.merge(Collidable(values),Drawable(values)),
		Object._clone(self,values))		
			
	return o
end

--
--  Update function
--
function ActorItem:update(dt)
	self._position[1] = self._actor._position[1]
	self._position[2] = self._actor._position[2]
	
	-- update the current animation
	self._currentAnimation:update(dt)
	
	-- calculate the bounding boxes
	self:calculateBoundary()
end