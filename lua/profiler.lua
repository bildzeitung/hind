--[[
	profiler.lua
	
	Created JUL-12-2012
]]

local Object = (require 'object').Object

local love, pairs, collectgarbage
	= love, pairs, collectgarbage

module('objects')

Profiler = Object{}

--
--  Actor constructor
--
function Profiler:_clone(values)
	local o = Object._clone(self,values)

	o._profiles = {}
	
	return o
end

--
--  Profiles some code
--
function Profiler:profile(p, fn)
	-- profile the function
	local b = collectgarbage('count')
	local s = love.timer.getMicroTime()
	fn()
	local d = love.timer.getMicroTime() - s
	local m = collectgarbage('count') - b
		
	if d > 0.02 then
		p = '*L* ' .. p
	end
	
	-- track running average of this item
	local prof = self._profiles[p] or { time_sum = 0, mem_sum = 0, count = 0 }
	prof.count = prof.count + 1
	prof.time_sum = prof.time_sum + d
	prof.mem_sum = prof.mem_sum + m
	self._profiles[p] = prof
end

--
--  Returns a table of profiled items
--
function Profiler:profiles()
	return self._profiles
end

--
--  Resets the profiler
--
function Profiler:reset()
	for k, _ in pairs(self._profiles) do
		self._profiles[k] = nil
	end
end		
