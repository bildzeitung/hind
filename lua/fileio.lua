--[[
	fileio.lua
	
	Created JUL-23-2012
]]

require 'table_ext'

local log = require 'log'

local marshal = require 'marshal'

require 'thread_communicator'

local thread = love.thread.getThread()
local communicator = objects.ThreadCommunicator{ thread }

local commands = 
{
	'saveMapCell',
	'saveActor',
	'addActorToCell',	
	'loadMapCell',
	'loadActor',
	'deleteActor'
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
--  Deletes an actor from disk
--
function deleteActor(id)
	log.log('Delete Actor: ' .. id)		

	local result, err = os.remove('map/' .. id .. '.act')	
	
	if not result and not err:find('No such file or directory') then
		log.log('There was a problem deleting actor #' .. id)
		log.log(err)
	end
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
--  Load a map cell from disk
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

--
--  Add an actor to a cell
--
function addActorToCell(id)
	local hash = communicator:demand('addActorToCell')
	log.log('Add actor "' .. id .. '" to cell "' .. hash .. '"')		
	
	local f = io.open('map/act-' .. hash .. '.dat' ,'rb')		
	if not f then 
		log.log('There was a problem reading the actors for cell #' .. hash)
		return
	end
	local actors = f:read('*all')
	f:close()
	
	-- add the actor id to the table of actors for this cell
	actors = marshal.decode(actors)		
	actors[#actors + 1] = id
	actors = marshal.encode(actors)
	
	local f = io.open('map/act-' .. hash .. '.dat' ,'wb')		
	if not f then 
		log.log('There was a problem writing the actors for cell #' .. hash)
		return
	end	
	f:write(actors)				
	f:close()		
end

-- LOOP FOREVER!
log.log('File io server waiting for input...')
while true do
	local cmd, msg = receiveAll()
	if cmd == 'saveActor' then
		saveActor(msg)
	elseif cmd == 'loadActor' then
		loadActor(msg)
	elseif cmd == 'deleteActor' then
		deleteActor(msg)
	elseif cmd == 'saveMapCell' then
		saveMapCell(msg)
	elseif cmd == 'loadMapCell' then
		loadMapCell(msg)
	elseif cmd == 'addActorToCell' then
		addActorToCell(msg)
	end
end