--[[
	double_queue.lua
	
	Created JUL-23-2012
]]

local setmetatable
	= setmetatable
	
module(...)

--
--  Returns a new double queue
--
function _M:new ()
	local t = {first = 0, last = -1}
	self.__index = self
	return setmetatable(t, self)
end

--
--  Returns the number of items in the queue
--
function _M:count()
	return (self.last - self.first) + 1
end

--
--  Pushes an item to the left side of the queue
--
function _M:pushleft(value)
	local first = self.first - 1
	self.first = first
	self[first] = value
end
  
--
-- Pushes an item to the right side of the queue  
--
function _M:pushright(value)
	local last = self.last + 1
	self.last = last
	self[last] = value
end
    
--
--  Returns the item at the left of the list
---
function _M:popleft()
	local first = self.first
	if first > self.last then return nil, 'Queue is empty' end
	local value = self[first]
	 -- to allow garbage collection
	self[first] = nil       
	self.first = first + 1
	return value
end

--
--  Returns the item at the right of the list
--    
function _M:popright()
	local last = self.last
	if self.first > last then return nil, 'Queue is empty' end
	local value = self[last]
	-- to allow garbage collection
	self[last] = nil         
	self.last = last - 1
	return value
end