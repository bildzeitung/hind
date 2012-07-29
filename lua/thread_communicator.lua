--[[
	thread_communicator.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

local log = require 'log'

module('objects')

ThreadCommunicator = Object{ _init = { '_thread' } }

ThreadCommunicator.sent = {}
ThreadCommunicator.received = {}

--
--  Send a message
--
function ThreadCommunicator:send(command, msg)
	local commandCount = ThreadCommunicator.sent[command] or 1
	self._thread:set(command .. commandCount, msg)	
	commandCount = commandCount + 1
	ThreadCommunicator.sent[command] = commandCount	
end

--
--  Receive a message
--
function ThreadCommunicator:receive(command)
	local commandCount = ThreadCommunicator.received[command] or 1	
	local msg = self._thread:get(command .. commandCount)	
	if msg then
		commandCount = commandCount + 1
		ThreadCommunicator.received[command] = commandCount	
	end
	return msg
end

--
--	Block until receiving a message
--
function ThreadCommunicator:demand(command)
	local commandCount = ThreadCommunicator.received[command] or 1	
	local msg = self._thread:demand(command .. commandCount)	
	if msg then
		commandCount = commandCount + 1
		ThreadCommunicator.received[command] = commandCount	
	end
	return msg
end