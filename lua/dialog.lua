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
	
	self._currentBranch = false
	
	return o
end

--
--  Start the dialog
--
function Dialog:start()
end

--
--  Finish the dialog
--
function Dialog:finish()
end

--
--  Get or set the current branch of the dialog
--
--  Inputs:
--		b - the numeric or string key of the branch to set
--
--	Outputs:
--		if no key is provided, returns the current branch (table entry)
--	 	of the dialog
--
function Dialog:branch(b)
	if not b then 
		-- start the dialog if it hasn't been started
		if self._currentBranch == false then
			self:start()
		end

		-- check to see if we should be automatically moving to the next branch
		if self._continuations[self._currentBranch] then
			local retval, b = self._continuations[self._currentBranch](self)
			if retval then
				self._currentBranch = b
			end
		end
		
		-- return the current branch
		return self._branches[self._currentBranch]
	end
	
	-- set the current branch
	self._currentBranch = b		
end