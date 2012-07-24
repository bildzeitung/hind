--[[
	fileio.lua
	
	Created JUL-23-2012
]]

local log = require 'log'

require 'thread_communicator'

local thread = love.thread.getThread()
local communicator = objects.ThreadCommunicator{ thread }

local commands = 
{
	'saveActor',
	'loadActor',
	'saveMapCell',
	'loadMapCell'
}

--
--  Receives any message
--
function receiveAll()
	for _, v in ipairs(commands) do
		local msg = communicator:receive(v)
		if msg then		
			return v, msg
		end
	end		
end

--
--  Saves actors to disk
--
function saveActor(id)
	log.log('Save Actor: ' .. id)		
	local msg = communicator:demand('saveActor')
	log.log('Recieved actor string')
	log.log(msg)
	
	local f = io.open('map/act_' .. id .. '.act', 'wb')	
	if not f then 
		log.log('There was a problem saving the actor #' .. id)
	end	
	
	f:write(msg)	
	f:close()
end

-- LOOP FOREVER!
log.log('File io server waiting for input...')
while true do
	local cmd, msg = receiveAll()
	if cmd == 'saveActor' then
		saveActor(msg)
	end
end
