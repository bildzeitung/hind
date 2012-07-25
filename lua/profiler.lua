--[[
	profiler.lua
	
	Created JUL-12-2012
]]

local Object = (require 'object').Object

local love, pairs
	= love, pairs

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
	local s = love.timer.getMicroTime()
	fn()
	local d = love.timer.getMicroTime() - s
	
	if d > 0.02 then
		p = '*L* ' .. p
	end
	
	-- track running average of this item
	local prof = self._profiles[p] or { sum = 0, count = 0 }
	prof.count = prof.count + 1
	prof.sum = prof.sum + d
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
