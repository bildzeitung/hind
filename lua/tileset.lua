--[[
	tileset.lua
	
	Created JUN-21-2012
]]

module(..., package.seeall)

--
--  Creates a new map
--
function _M:new(t)
	self.__index = self    
	setmetatable(t, self)
	
	t._quads = {}
	for y = 0, t._image:getHeight() - 1, t._size[2] do
		for x = 0, t._image:getWidth() - 1, t._size[1] do
			-- create a quad for the tile
			t._quads[#t._quads+1] = love.graphics.newQuad(
				x, y, t._size[1], t._size[2], 
				t._image:getWidth(), t._image:getHeight())
		end
	end
	
	-- if there is a default boundary value provided then
	-- fill the non specified boundaries
	if t._boundaries.default then
		for i = 1, #t._quads do
			if not t._boundaries[i] then
				t._boundaries[i] = t._boundaries.default
			end
		end
	end
	
	return t
end


--
--  Returns the tile size
--
function _M:size()
	return self._size
end

--
--  Returns the image for this tileset
--
function _M:image()
	return self._image
end

--
--  Returns the tiles for this tileset
--
function _M:quads()
	return self._quads
end

--
--  Returns the tile bounaries table
--
function _M:boundaries()
	return self._boundaries
end

--
--  Returns the tile height table
--
function _M:heights()
	return self._heights
end

--
--  Returns the name of this tileset
--
function _M:name()
	return self._name
end