--[[
	string_ext.lua
	
	Created JUL-11-2012
]]

--local types = require 'types'

-- Split a string
--
-- Given a string and delimiter, split the string.
-- When given "a,,," returns a table { 'a', '', '', '' }
-- Parameters:
--     s    The string to split. Note that instead of string.split(s, sep), you
--          can use s:split(sep).
--     sep  The separator, a Lua pattern string. In the same spirit as
--          string.gmatch, if this is '', a table of 1+#s empty strings will be
--          returned.
-- Return values:
--     A table of the strings between separator matches.
function string.split(s,sep)
	--types.check('string', s)
	--types.check('string', sep)
	pat = '(.-)(' .. sep .. ')'
	local t = {}
	local n = 1
	for p, q in s:gmatch(pat) do
		-- There is weird behaviour from gmatch given an empty separator
		-- pattern. To quote from the docs:
		--     "As a special case, the empty capture () captures the current
		--      string position (a number)."
		if type(q) == 'number' then q = '' end
	
		t[#t+1] = p
		n = n + #p + #q
	end
	if sep ~= '' then
		t[#t+1] = s:sub(n)
	end
	return t
end

return string