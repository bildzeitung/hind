--[[
	map_cell.lua
	
	Created JUL-12-2012
]]

local ffi = require 'ffi'
ffi.cdef
[[
	typedef struct 
	{
		char name[20];
		int64_t x;
		int64_t y;
	} map_object;
]]

local Object = (require 'object').Object

local log = require 'log'

local string, pairs, table, ipairs, tonumber, math, love 
	= string, pairs, table, ipairs, tonumber, math, love

module('objects')

MapCell = Object{ _init = { '_tileSet', '_size', '_coords', '_layers' } }

--
--  MapCell constructor
--
function MapCell:_clone(values)
	local o = Object._clone(self,values)
				
	-- create memory to hold the tiles
	o._totalTiles = o._size[1] * o._size[2] * o._layers	
	o._tiles = ffi.new('uint16_t[?]', o._totalTiles)
	
	o._extents = { o._coords[1], o._coords[2],
		o._coords[1] + o._size[1] - 1,
		o._coords[2] + o._size[2] - 1 }
	
	-- the canvas that will hold the rendered version
	-- of this cell
	local tss = o._tileSet:size()
	o._canvas = love.graphics.newCanvas(
		o._size[1] * tss[1], o._size[2] * tss[2])
		
	o._rendered = false
	
	o.__tostring = function()
		return string.format('Map Cell -> l: %d, t: %d, r: %d, b: %d', 
			o._extents[1], o._extents[2], 
			o._extents[3], o._extents[4])
	end
		
	o._visible = false
	o._framesNotUsed = 0	
	o._hash = false
	
	o._colliders = {}
	o._objects = {}	
	
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
			local currentTile = 0
			local width = self._canvas:getWidth() - 1
			local height = self._canvas:getHeight() - 1		
			local sizeX = tss[1]
			local sizeY = tss[2]
			-- draw the tiles!
			for z = 1, self._layers do
				for y = 0, height, sizeY do
					for x = 0, width, sizeX do
						local tile = self._tiles[currentTile]
						if tile > 0 then				
							-- @TODO we should be using quads for map rendering with one BIG sprite atlas
							-- it is WAY faster
							--love.graphics.drawq(tq[tile]._image, tq[tile]._quad, x, y)
							love.graphics.draw(tq[tile], x, y)
						end
						currentTile = currentTile + 1
					end
				end
			end
		end)
	local e = love.timer.getMicroTime()		
	--log.log('Rendering the map cell canvas took: ' .. e-s)
	
	self._rendered = true
end

--
--  Sets the tile data for this map cell
--
function MapCell:data(tiles, objs, acts)
	ffi.copy(self._tiles, tiles, Map.cellTileBytes)	

	if objs then
		local objCount = #objs / ffi.sizeof('map_object')	
		if objCount > 0 then
			self._objectData = ffi.new('map_object[?]', objCount)
			ffi.copy(self._objectData, objs, #objs)					
			for i = 0, objCount - 1 do
				table.insert(self._objects, self:createObject(self._objectData[i]))
			end
		end	
	end
	
	if acts then
		local actorCount = self:actorCount()
		self._actorData = ffi.new('map_actor[?]', actorCount)
		ffi.copy(self._actorData, acts, #acts)					
	end	
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
--  Creates the collidable objects 
--
function MapCell:createColliders(buckets)
	--log.log('==== CREATING COLLIDERS! ====')		
	-- register any collidable tiles
	local bs = self._tileSet:boundaries()
	local ts = self._tileSet:size()
	
	local currentTile = 0
	for z = 1, self._layers do
		local sx = self._extents[1] * ts[1]
		local sy = self._extents[2] * ts[2]
		for y = 1, Map.cellSize do	
		sx = self._extents[1] * ts[1]
			for x = 1, Map.cellSize do
				local tile = self._tiles[currentTile]
				if tile > 0 then				
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
				currentTile = currentTile + 1				
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
	
	--log.log('COUNT: ' .. #self._colliders)
	--log.log('==== CREATING COLLIDERS! ====')
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
			buckets[k] = nil
		end		
	end	
end

--
--  Creates a static object from
--  a name and a position
-- 
function MapCell:createObject(obj)
	local name = ffi.string(obj.name)
	
	--log.log('CreateObject')
	--log.log('name')
	--log.log(name)
	
	local o = table.clone(self._tileSet._objects[name], { deep = true })
	o._position = { tonumber(obj.x), tonumber(obj.y) }

	local b = { }
	b[1] = o._position[1] + o._boundary[1] - o._offset[1]
	b[2] = o._position[2] + o._boundary[2] - o._offset[2]
	b[3] = o._position[1] + o._boundary[3] - o._offset[1]
	b[4] = o._position[2] + o._boundary[4] - o._offset[2]		
	o._boundary = b
	
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
		
		table.insert(drawTable.object, 
			{ z, self._image[1], 
			sx, sy, 
			zoomX, zoomY, self._offset[1], self._offset[2] })
			
		table.insert(drawTable.roof, 
			{ z, self._image[2], 
			sx, sy, 
			zoomX, zoomY, self._offset[1], self._offset[2] })			
	end
	
	return o
end

--
--  Returns the number of actors saved in this map cell
--
function MapCell:actorCount()
	if not self._actorData then return 0 end
	return ffi.sizeof(self._actorData) / ffi.sizeof('map_actor')	
end