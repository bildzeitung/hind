--[[
	fileio.lua
	
	Created JUL-23-2012
]]

local log = require 'log'

local marshal = require 'marshal'

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
	local actor = communicator:demand('saveActor')
	
	local f = io.open('map/' .. id .. '.act', 'wb')	
	if not f then 
		log.log('There was a problem saving the actor #' .. id)
	end	
	
	f:write(actor)	
	f:close()
end

--
--  Load an actor from disk
--
function loadActor(id)
	log.log('Load Actor: ' .. id)		
	
	local f = io.open('map/' .. id .. '.act', 'rb')	
	if not f then 			
		log.log('There was a problem loading the actor #' .. id)
	end	
	local s = f:read('*all')
	f:close()	
			
	communicator:send('loadedActor', s)
end

--
--  Save a map cell to disk
--
function saveMapCell(hash)
	log.log('Save Map Cell: ' .. hash)		
	local tiles = communicator:demand('saveMapCell')
	local actors = communicator:demand('saveMapCell')

	local f = io.open('map/' .. hash .. '.dat' ,'wb')		
	if not f then 
		log.log('There was a problem saving the map cell #' .. hash)
	end		
	f:write(tiles)	
	f:close()
	
	local f = io.open('map/act-' .. hash .. '.dat' ,'wb')		
	if not f then 
		log.log('There was a problem saving the actors for map cell #' .. hash)
	end		
	f:write(actors)	
	f:close()	
end

--
--  Save a map cell to disk
--
function loadMapCell(hash)
	log.log('Load Map Cell: ' .. hash)		
	
	local tiles, actors
	
	local f = io.open('map/' .. hash .. '.dat', 'rb')
	if not f then 
		log.log('There was a problem loading the cell #' .. hash)
		communicator:send('loadedMapCell', 0)
		return
	end		
	tiles = f:read('*all')
	f:close()	
	
	local f = io.open('map/act-' .. hash .. '.dat' ,'rb')		
	if not f then 
		log.log('There was a problem loading the actors for cell #' .. hash)
	else
		actors = f:read('*all')
		f:close()
	end
	
	communicator:send('loadedMapCell', hash)
	communicator:send('loadedMapCell', tiles)
	communicator:send('loadedMapCell', actors)
end

-- LOOP FOREVER!
log.log('File io server waiting for input...')
while true do
	local cmd, msg = receiveAll()
	if cmd == 'saveActor' then
		saveActor(msg)
	elseif cmd == 'loadActor' then
		loadActor(msg)
	elseif cmd == 'saveMapCell' then
		saveMapCell(msg)
	elseif cmd == 'loadMapCell' then
		loadMapCell(msg)
	end
end
