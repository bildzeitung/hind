--[[
	dialog.lua
	
	Created JUL-16-2012
	
	This object represents a generated dialog tree. It will be responsible for
	keeping track of the current state of the dialog, and running any scripts that
	the dialog defines as the user makes dialog choices.
]]

local Object = (require 'object').Object

local log = require 'log'
	
local pairs, math, type, table
	= pairs, math, type, table
	
module('objects')

Dialog = Object{}

--
--  Dialog constructor
--
function Dialog:_clone(values)
	local o = Object._clone(self,values)

	o.DIALOG = true
	
	o._currentBranch = values._currentBranch or false
	
	return o
end

--
--  Start the dialog
--
function Dialog:start()
	local startingType = nil
	if self._quest then
		startingType = 'quest'
	else
		startingType = 'random'
	end
	
	local psk = {}
	for k, v in pairs(self._branches) do
		local addPSK = true
		if type(k) == 'string' and k:find(startingType) then
			if v.available then
				if not v.available(self) then
					addPSK = false
				end
			end
			
			if addPSK then
				psk[#psk+1] = k				
			end
		end
	end
	
	local sk = math.floor(math.random() * #psk) + 1
	
	if self.on_start then
		self:on_start()
	end
	
	self:branch(psk[sk])
end

--
--  Finish the dialog
--
function Dialog:finish()
	if self.on_finish then
		self:on_finish()
	end
	
	self._currentBranch = -1
end

--
--  Called when the current branch has been viewed
--	Optional ption number identifies which branch option
--  was chosen
--
function Dialog:viewed(option)
	local branch = self._branches[self._currentBranch]
	
	-- was an option selected?
	if option then
		branch = branch.options[option]
	end	
	
	-- execute the event for this branch if one exists
	if branch.event then
		branch.event(self)
	end
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
	if self._currentBranch == -1 then return nil end

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

--
--  Returns the name of this dialog
--  
function Dialog:name()
	return self._name
end

--
--  Defines serialization / deserialization
--
function Dialog:__persistTable()
	return 
	{
		_branches = table.clone(self._branches, { deep = true, nometa = true }),
		_continuations = table.clone(self._continuations, { deep = true, nometa = true }),
		_currentBranch = self._currentBranch,
		_name = self._name
	}
end