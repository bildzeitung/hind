--[[
	pathfind.lua
	
	Created JUL-28-2012
]]

require 'table_ext'
require 'love.timer'
require 'thread_communicator'
local log = require 'log'
local marshal = require 'marshal'
local thread = love.thread.getThread()
local communicator = objects.ThreadCommunicator{ thread }
local pathfinder = nil

local commands = 
{
	'setMatrix',
	'findPath'
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
--  Set the matrix for pathfinding
--
function setMatrix(coords)
	log.log('Set Path Matrix')
	
	local matrix = communicator:demand('setMatrix')
	local coords = marshal.decode(coords)
end

--
--  Add an actor to a cell
--
function findPath(points)
	log.log('Find Path')	
end

-- LOOP FOREVER!
log.log('Pathfind server waiting for input...')
while true do
	local cmd, msg = receiveAll()
	if cmd == 'setMatrix' then
		setMatrix(msg)
	elseif cmd == 'findPath' then
		findPath(msg)
	else
		love.timer.sleep(0.001)
	end
end