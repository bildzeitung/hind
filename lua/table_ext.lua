--[[
	table_ext.lua
	
	Created JUN-26-2012
]]

--
-- Make a copy of table t 
--
--  Unless opts.nometa is set, it copies t's metatable also
--  Unless opts.deep is set, it makes a shallow copy
--
--  WARNING: Deep copies do not allow for cycles
--
--  @TODO: account for cycles in deep copies
--
-- Parameters
--  t:    table to copy
--  opts: table containing optional keys { nometa, deep} 
--
-- Returns
--  table
--
function table.clone(t,opts)
   opts = opts or {}

   local res = {}   
   for k,v in pairs(t) do
      if type(v) == 'table' and opts.deep then
         res[k] = table.clone(v,opts)
      else
         res[k] = v
      end
   end

   if not opts.nometa then setmetatable(res,getmetatable(t)) end
   
   return res
end