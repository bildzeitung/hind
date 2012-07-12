--[[
	actor.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

local pairs, table, print
	= pairs, table, print
	
module('objects')

ActorItem = Object{}

--
--  Actor constructor
--
function ActorItem:_clone(values)
	local o = table.merge(
		Drawable(values),
		table.merge(
			Collidable(values),
			Object._clone(self,values)
		))		
			
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