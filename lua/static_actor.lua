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
--  StaticActor constructor
--
function StaticActor:_clone(values)
	local o = table.merge(		
		table.merge(Drawable(values),Collidable(values)),
		Object._clone(self,values))
			
	o.STATICACTOR = true
	
	return o
end

--
--  Update the StaticActor
--
function StaticActor:update(dt)
	-- update the current animation
	self._currentAnimation:update(dt)	
	-- calculate the bounding boxes
	self:calculateBoundary()
end