--[[
	hero.lua
	
	Created JUL-12-2012
]]

local Object = (require 'object').Object

local table
	= table
	
module('objects')

Hero = Object{}

--
--  Hero constructor
--
function Hero:_clone(values)
	local o = table.merge( Actor(values), Object._clone(self,values))
			
	o.HERO = true
	o._experience = 0
	o._gold = 0
	
	return o
end

--
--  Rewards experience
--
function Hero:rewardExperience(experience)
	self._experience = self._experience + experience
end