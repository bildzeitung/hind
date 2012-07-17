--[[
	dialog_viewer.lua
	
	Created JUL-16-2012
	
	This object will be responsible for creating the view of a dialog
	that the player will interact with, including handling input and output.
]]

local Object = (require 'object').Object

local log = require 'log'
	
module('objects')

DialogViewer = Object{ _init = { '_dialog' } }

--
--  DialogViewer constructor
--
function DialogViewer:_clone(values)
	local o = Object._clone(self,values)

	o.DIALOGVIEWER = true
	
	return o
end