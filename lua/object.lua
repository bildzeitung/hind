--[[
	object.lua
	
	Created JUL-11-2012

	The object model has been replicated from an article in Lua Programming Gems
	(p. 129). This is a simple object model that provides inheritance and member
	function and field semantics.
  
--]]

local table        = require('table_ext')
local setmetatable = setmetatable
--local types        = require('types')

module(...)

Object = {
	_init = {},

	_clone = function (self, values)
        --types.check( {'table', 'table'}, {self, values}, _NAME..'._clone:' )
        
				local object = table.merge(self, table.rearrange(values,self._init))
				return setmetatable(object, object)
			 end,
	__call =  function (...)
				return (...)._clone(...)
			 end,
}

setmetatable(Object,Object)