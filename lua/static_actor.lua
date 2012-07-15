--[[
	static_actor.lua
	
	Created JUL-15-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

local table, pairs, ipairs, print
	= table, pairs, ipairs, print
	
module('objects')

StaticActor = Object{}

--
--  Actor constructor
--
function StaticActor:_clone(values)
	local o = table.merge(
		Drawable(values),
		table.merge(
			Collidable(values),
			Object._clone(self,values)
		))
			
	o._map = nil
	o.STATICACTOR = true
	
	return o
end

--
--  Sets the map that the static actor is acting on
--
function StaticActor:map(m)
	self._map = m
end

--
--  Update function
--
function StaticActor:update(dt)
	-- update the current animation
	self._currentAnimation:update(dt)	
	-- calculate the bounding boxes
	self:calculateBoundary()
end