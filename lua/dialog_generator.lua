--[[
	dialog_generator.lua
	
	Created JUL-16-2012
	
	This object generates a dialog object from a given dialog script. 
	It is responsible for filling in the dynamic parts of the dialog.
]]

local Object = (require 'object').Object

local log = require 'log'
	
module('objects')

DialogGenerator = Object{ init = { '_filename' } }

--
--  DialogGenerator constructor
--
function DialogGenerator:_clone(values)
	local o = Object._clone(self,values)

	o.DIALOGGENERATOR = true
	
	return o
end

--
--  Returns a new Dialog
--
function DialogGenerator:Dialog()
	
end