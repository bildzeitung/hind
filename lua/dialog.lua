--[[
	dialog.lua
	
	Created JUL-16-2012
	
	This object represents a generated dialog tree. It will be responsible for
	keeping track of the current state of the dialog, and running any scripts that
	the dialog defines as the user makes dialog choices.
]]

local Object = (require 'object').Object

local log = require 'log'
	
module('objects')

Dialog = Object{}

--
--  Dialog constructor
--
function Dialog:_clone(values)
	local o = Object._clone(self,values)

	o.DIALOG = true
	o._currentBranch = 1
	
	return o
end