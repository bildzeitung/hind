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
	
	--
	-- Mark all of the object tiles for exclusion from regular tile set
	--
	local excludeTiles = {}
	for _, def in pairs(t._definitions) do
		for _, layer in pairs(def._tiles) do
			for k, v in pairs(layer) do
				excludeTiles[v] = true
			end
		end
	end
	
	-- build the regular tiles
	t._quads = {}
	local tile = 1
	for y = 0, t._image:getHeight() - 1, t._size[2] do
		for x = 0, t._image:getWidth() - 1, t._size[1] do			
			if not excludeTiles[tile] then			
				local im = love.image.newImageData(t._size[1], t._size[2])
				im:paste(t._image,0,0,x,y,t._size[1],t._size[2])
				t._quads[tile] = love.graphics.newImage(im)
			end
			tile = tile + 1
		end
	end
	
	-- build the objects
	t._objects = {}		
	
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