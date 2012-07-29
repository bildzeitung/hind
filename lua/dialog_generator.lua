--[[
	dialog_generator.lua
	
	Created JUL-16-2012
	
	This object generates a dialog object from a given dialog script. 
	It is responsible for filling in the dynamic parts of the dialog.
]]

local Object = (require 'object').Object

require 'dialog'

local log = require 'log'

local io, tostring, tonumber, loadstring, math, pairs, type, table
	= io, tostring, tonumber, loadstring, math, pairs, type, table
	
module('objects')

DialogGenerator = Object{ _init = { '_filename' } }

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
function DialogGenerator:dialog(params)
	local quest = params.quest
	local npc = params.npc
	local hero = params.hero

	-- load the script file
	local f = io.open(self._filename, 'r')
	if not f then return nil, 
		'There was an error reading the dialog file "' .. self._filename .. '"'
	end
	local dialogScript = f:read('*all')
	f:close()

	-- replace npc and hero names
	dialogScript = dialogScript:gsub('%@NPC%@', npc)
	dialogScript = dialogScript:gsub('%@HERO%@', hero)
	
	-- replace quest giver name
	if quest then
		dialogScript = dialogScript:gsub('%@QUEST_GIVER%@', quest:giver():name())
	end
	-- generate all phrases
	local phrasesToReplace = {}
	local phraseNumber = {}
	local i = 1
	repeat
		_, i, t, n = dialogScript:find('%@(_.-)%#%#(.-)%@', i)
		if i == nil then break end		
		if not phrasesToReplace[n] then
			phrasesToReplace[n] = {}
		end		
		phrasesToReplace[n][t] = true
	until not i
	
	for n, phraseList in pairs(phrasesToReplace) do
		for phrase, _ in pairs(phraseList) do
			local key = phrase .. '_' .. n
			local _, _, phraseTable = dialogScript:find(phrase .. '%s*%=%s*(%{.-%})')
			phraseTable = loadstring('return ' .. phraseTable)()
			if not phraseNumber[n] then
				phraseNumber[n]  = math.floor(math.random() * #phraseTable) + 1
			end			
			
			dialogScript = dialogScript:gsub('%@' .. phrase .. '%#%#' .. n .. '%@', phraseTable[phraseNumber[n]])
		end
	end
	-- replace && with _
	dialogScript = dialogScript:gsub('%&%&', '_')
	
	--log.log(dialogScript)
	
	-- generate a table from the dialog script
	local t = loadstring('return ' .. dialogScript)()
	
	-- strip out the phrase tables
	for n, phraseList in pairs(phrasesToReplace) do
		for phrase, _ in pairs(phraseList) do
			t[phrase] = nil
		end
	end

	-- change string only entries in the branch table
	-- to table entries with the text key	
	local function addTextKey(k, v, t)
		if type(v) == 'string' then
			local r = { text = v }
			t[k] = r
		end		
	end
	
	for k, v in pairs(t._branches) do
		local opts = v.options 
		if opts then
			for opk, opv in pairs(opts) do
				addTextKey(opk, opv, opts)
			end					
		else
			addTextKey(k, v, t._branches)
		end			
	end
	
	-- replace @NEXT@ @END@ and @SKIP@ text with events
	local function replaceEvent(t, fn)
		if not t.event then
			t.event = fn
		else
			local old_event = t.event
			t.event = function(self)
				old_event(self)
				fn(self)
			end		
		end
	end
		
	local function replaceMacros(t)
		local text = t.text
		if text:find('%@NEXT%@') then 
			replaceEvent(t, 
				function(self)
					self:branch(self._currentBranch + 1)
				end
			)
			
			t.text = text:gsub('%@NEXT%@', '')
		end		

		if text:find('%@END%@') then 
			replaceEvent(t, 
				function(self)
					self:finish()
				end
			)
			
			t.text = text:gsub('%@END%@', '')
		end			
		
		local _, _, cap = text:find('%@SKIP(%d+)%@')
		if cap then
			if tonumber(cap) then cap = tonumber(cap) end
			replaceEvent(t, 
				function(self)				
					self:branch(cap)
				end
			)
			
			t.text = text:gsub('%@SKIP%d+%@', '')
		end
	end
	
	for _, v in pairs(t._branches) do
		local opts = v.options 
		if opts then
			for _, op in pairs(opts) do
				replaceMacros(op)
			end					
		else
			replaceMacros(v)
		end		
	end

	-- change continuations to numbered keys where appropriate
	for k, v in pairs(t._continuations) do
		if tonumber(k) then
			t._continuations[tonumber(k)] = v
			t._continuations[k] = nil
		end
	end
	
	--log.log(table.dump(t))
	
	local d = Dialog(t)
	
	d._quest = quest
	
	return d
end