--[[
	log.lua
	
	Created JUL-12-2012
]]

local io = io

module(...)

function log(msg)
	local f = io.open('out.txt', 'a')
	f:write(msg .. '\n')
	f:close()	
end