--[[
	map_cell.lua
	
	Created JUL-12-2012
]]

local Object = (require 'object').Object

local log = require 'log'

local string, pairs, table, ipairs, tonumber, math, tostring, love 
	= string, pairs, table, ipairs, tonumber, math, tostring, love

module('objects')

MapCell = Object{ _init = { '_tileSet', '_size', '_coords', '_layers' } }

--
--  MapCell constructor
--
function MapCell:_clone(values)
	local o = Object._clone(self,values)
				
	-- create memory to hold the tiles
	o._totalTiles = o._size[1] * o._size[2] * o._layers	
	-- a table for the tiles in layers	
	-- info about objects is stored in layer Map.layers + 1
	o._tiles = {}
	-- holds the objects that are created
	-- from the info in the tile structure
	o._objects = {}
	-- holds the actors that should be in this cell
	o._actors = {}
	-- list of colliders from tiles and objects
	-- that will be added to the collision buckets
	o._colliders = {}	
	-- the left, top, right, and bottom tile that
	-- the cell encompasses
	o._extents = { o._coords[1], o._coords[2],
		o._coords[1] + o._size[1] - 1,
		o._coords[2] + o._size[2] - 1 }	
	-- the canvas that will hold the rendered version
	-- of this cell
	local tss = o._tileSet:size()
	o._canvas = love.graphics.newCanvas(
		o._size[1] * tss[1], o._size[2] * tss[2])
	-- the canvas is only rendered once - or 
	-- if the base tiles somehow change
	o._rendered = false
	-- whether this cell is currently visible
	o._visible = false
	-- the number of frames the cell has remained unused
	o._framesNotUsed = 0	
	-- the spatial hash for the cell
	o._hash = false
	-- the area that the map cell belongs to
	o._area = false
	
	o.__tostring = function()
		return string.format('Map Cell -> l: %d, t: %d, r: %d, b: %d', 
			o._extents[1], o._extents[2], 
			o._extents[3], o._extents[4])
	end		
	
	return o
end

--
--  Renders the cell's tiles to the canvas
--
function MapCell:render()
	local tss = self._tileSet:size()	
	local tq = self._tileSet:quads()
	
	local s = love.timer.getMicroTime()
	self._canvas:renderTo( 
		function()
			local width = self._canvas:getWidth() - 1
			local height = self._canvas:getHeight() - 1		
			local sizeX = tss[1]
			local sizeY = tss[2]
			local sx, sy
			-- draw the tiles!
			for z = 1, self._layers do
				sy = 0
				for y = 1, Map.cellSize do
					sx = 0
					for x = 1, Map.cellSize do
						local tile = self._tiles[z][y][x]
						if tile then				
							-- @TODO we should be using quads for map rendering with ONE sprite atlas
							-- for the map tiles as it is WAY faster
							--love.graphics.drawq(tq[tile]._image, tq[tile]._quad, x, y)
							love.graphics.draw(tq[tile], sx, sy)
						end
						sx = sx + sizeX
					end
					sy = sy + sizeY
				end
			end
		end)
	local e = love.timer.getMicroTime()
	log.log('Rendering the map cell "' .. self._hash .. '" took ' .. (e-s))
	
	self._rendered = true
end

--
--  Sets the tile data for this map cell
--
function MapCell:data(tiles, area, actors)
	self._tiles = tiles
	self._area = area

	local objs = self._tiles[Map.layers+1]
	for i = 1, #objs do
		table.insert(self._objects, self:createObject(objs[i]))
	end
	
	self._actors = actors
end

--
--  Returns the canvas for the MapCell
--
function MapCell:canvas()
	if not self._rendered then self:render() end
	return self._canvas
end

-- 
--  Returns the map cell size
--
function MapCell:size()
	return self._size
end

--
--  Creates the collidable objects 
--
function MapCell:createColliders(buckets)
	-- register any collidable tiles
	local bs = self._tileSet:boundaries()
	local ts = self._tileSet:size()
	
	for z = 1, self._layers do
		local sx = self._extents[1] * ts[1]
		local sy = self._extents[2] * ts[2]
		for y = 1, Map.cellSize do	
		sx = self._extents[1] * ts[1]
			for x = 1, Map.cellSize do
				local tile = self._tiles[z][y][x]
				if tile then				
					local boundary = bs[tile]
					if boundary and (boundary[3] > 0 or boundary[4] > 0) then
						-- @TODO fix this, should just be able to use a collidable object, but
						-- collidables currently require an animation :-(
						local o = {}				
						o._position = { sx, sy }		
						o._boundary = {}
						o._boundary[1] = o._position[1] + boundary[1] - (ts[1] / 2)
						o._boundary[2] = o._position[2] + boundary[2] - (ts[2] / 2)
						o._boundary[3] = o._position[1] + boundary[3] - (ts[1] / 2)
						o._boundary[4] = o._position[2] + boundary[4] - (ts[2] / 2)		
						o._bucketIds = {}				
						o._bucketIds[buckets.hash(o._boundary[1], o._boundary[2])] = true
						o._bucketIds[buckets.hash(o._boundary[1], o._boundary[4])] = true
						o._bucketIds[buckets.hash(o._boundary[3], o._boundary[2])] = true
						o._bucketIds[buckets.hash(o._boundary[3], o._boundary[4])] = true	
						self._colliders[#self._colliders + 1] = o
					end
				end
				sx = sx + ts[1]
			end
			sy = sy + ts[2]
		end
	end	
	
	-- add colliders for objects
	for k, v in ipairs(self._objects) do
		v._bucketIds = {}
		v._bucketIds[buckets.hash(v._boundary[1], v._boundary[2])] = true
		v._bucketIds[buckets.hash(v._boundary[1], v._boundary[4])] = true
		v._bucketIds[buckets.hash(v._boundary[3], v._boundary[2])] = true
		v._bucketIds[buckets.hash(v._boundary[3], v._boundary[4])] = true
				
		self._colliders[#self._colliders + 1] = v
	end
end

--
--  Returns the spatial buckets 
--  that the object currently occupies
--
function MapCell:spatialBuckets(buckets)
	local tss = self._tileSet:size()
	
	local ids = {}

	for y = self._extents[2] * tss[2], self._extents[4] * tss[2], Map.bucketCellSize do
		for x = self._extents[1] * tss[1], self._extents[3] * tss[1], Map.bucketCellSize do
			ids[buckets.hash(x, y)] = true
		end
	end
	
	return ids
end

--
--  Registers the map cell in the proper
--	collision buckets - creating them if necessary
--
function MapCell:registerBuckets(buckets)
	-- calculates the spatial buckets
	self._bucketIds = self:spatialBuckets(buckets)
	
	-- register the new buckets ids
	for k, _ in pairs(self._bucketIds) do
		if not buckets[k] then
			buckets[k] = {}
			buckets['count' .. k] = 1
		else
			buckets['count' .. k] = buckets['count' .. k] + 1
		end		
	end	
	
	self:createColliders(buckets)
	self:registerColliders(buckets)	
end

--
--  Registers the map cells collidable objects in the proper
--	collision buckets
--
function MapCell:registerColliders(buckets)
	for _, v in pairs(self._colliders) do
		for k, _ in pairs(v._bucketIds) do	
			if buckets[k] then		
				table.insert(buckets[k], v)
			end
		end
	end
end

--
--  Unregisters the map cell from the proper 
--	collision buckets - removing them if necessary
--
function MapCell:unregisterBuckets(buckets)
	-- unregister the buckets ids
	for k, _ in pairs(self._bucketIds) do
		buckets['count' .. k] = buckets['count' .. k] - 1
		if buckets['count' .. k] == 0 then
			buckets['count' .. k] = nil
			buckets[k] = nil
		end		
	end	
end

--
--  Creates a static object from
--  a name and a position
-- 
function MapCell:createObject(obj)	
	local o = table.clone(self._tileSet._objects[obj.name], { deep = true })
	o._position = { obj.x, obj.y }

	local b = { }
	b[1] = o._position[1] + o._boundary[1] - o._offset[1]
	b[2] = o._position[2] + o._boundary[2] - o._offset[2]
	b[3] = o._position[1] + o._boundary[3] - o._offset[1]
	b[4] = o._position[2] + o._boundary[4] - o._offset[2]		
	o._boundary = b
	
	o._objectDrawEntry = { true,  o._image[1], true, true, 
		true, true, true, true }
	o._roofDrawEntry = { true,  o._image[2], true, true, 
		true, true, true, true }
	
	--
	--  Draw the object
	--
	function o:draw(camera, drawTable)
		local cw, cv, zoomX, zoomY, cwzx, cwzy =
			drawTable.cw, drawTable.cv, 
			drawTable.zoomX, drawTable.zoomY,
			drawTable.cwzx, drawTable.cwzy	
			
		local sx = math.floor((self._position[1] * zoomX) - cwzx)
		local sy = math.floor((self._position[2] * zoomY) - cwzy)
		local z = self._position[2] + 
			self._height - (self._position[1] * 0.0000000001)
		
		local object = drawTable.object
		self._objectDrawEntry[1] = z
		self._objectDrawEntry[3] = sx
		self._objectDrawEntry[4] = sy
		self._objectDrawEntry[5] = zoomX
		self._objectDrawEntry[6] = zoomY
		self._objectDrawEntry[7] = self._offset[1]
		self._objectDrawEntry[8] = self._offset[2]				
		object[#object+1] = self._objectDrawEntry
		
		local roof = drawTable.roof
		self._roofDrawEntry[1] = z
		self._roofDrawEntry[3] = sx
		self._roofDrawEntry[4] = sy
		self._roofDrawEntry[5] = zoomX
		self._roofDrawEntry[6] = zoomY
		self._roofDrawEntry[7] = self._offset[1]
		self._roofDrawEntry[8] = self._offset[2]						
		roof[#roof+1] = self._roofDrawEntry		
	end
	
	return o
end