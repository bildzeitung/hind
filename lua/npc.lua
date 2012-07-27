--[[
	npc.lua
	
	Created JUL-27-2012
]]

local Object = (require 'object').Object

require 'actor'

local log = require 'log'

local factories = require 'factories'

local table, pairs, ipairs, type, love
	= table, pairs, ipairs, type, love
	
module('objects')

NPC = Object{}

--
--  Returns a new NPC loaded
--	from the provided data file
--
--  Inputs:
--		filename - the name of the data file
--		that describes the actor
--		existing - a table with existing information to merge into
--		the actor (for deserialization)
--
function NPC.create(filename, existing)
	local t = factories.prepareActor(filename, existing)
	local n = NPC(t)
		
	-- create new dialog objects
	for k, v in pairs(n._dialogs) do 
		n._dialogs[k] = Dialog(v)
		n._dialogs[k]._npc = n
	end
	
	return n
end

--
--  NPC constructor
--
function NPC:_clone(values)
	local o = table.merge(Actor(values), Object._clone(self,values))
			
	o.NPC = true
	o._dialogs = values._dialogs or {}	

	return o
end

--
--  Adds a dialog to the NPC
--
function NPC:addDialog(d)
	self._dialogs[d:name()] = d
end

--
--  Removes a dialog from the NPC
--
function NPC:removeDialog(d)
	if type(d) == 'string' then
		self._dialogs[d] = nil
	else
		self._dialogs[d:name()] = nil
	end
end

--
--  The list of dialogs this NPC currently owns
--
function NPC:dialogs()
	return self._dialogs
end

--
--  Defines serialization / deserialization
--
function NPC:__persistTable()
	local t = Actor.__persistTable(self)
	t._dialogs = {}
	for k, v in pairs(self._dialogs) do
		t._dialogs[v:name()] = Dialog.__persistTable(v)
	end
		
	return t
end

--
--  Used for marshal to define serialization
--
function NPC:__persist()
	local t = self:__persistTable()
	return function()
		local n = objects.NPC.create(t._filename, t)		
		n:animation(n._currentAnimation)	
		return n
	end
end