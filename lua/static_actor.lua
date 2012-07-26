--[[
	static_actor.lua
	
	Created JUL-15-2012
]]

local Object = (require 'object').Object

require 'drawable'
require 'collidable'

local factories = require 'factories'

local table, pairs, ipairs, print
	= table, pairs, ipairs, print
	
module('objects')

StaticActor = Object{}

--
--  Returns a new static actor loaded
--	from the provided data file
--
--  Inputs:
--		filename - the name of the data file
--		that describes the actor
--		existing - a table with existing information to merge into
--		the actor (for deserialization)
--
function StaticActor.create(filename, existing)
	local t = factories.prepareActor(filename, existing)
	local a = StaticActor(t)
	return a
end

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

--
--  Defines serialization / deserialization
--
function StaticActor:__persistTable()
	return 
	{
		_filename = self._filename,
		_id = self._id,
		_name = self._name,
		_currentAnimation = self._currentAnimation._name,
		_position = { self._position[1], self._position[2] },
		_collidees = table.clone(self._collidees, { nometa = true })		
	}
end

--
--  Used for marshal to define serialization
--
function StaticActor:__persist()
	local t = self:__persistTable()
	return function()
		local a = objects.StaticActor.create(t._filename, t)		
		a:animation(a._currentAnimation)		
		return a
	end
end