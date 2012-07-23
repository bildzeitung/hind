--[[
	map.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'map_cell'

local ffi = require 'ffi'	

local log = require 'log'

local table, pairs, ipairs, math, io, print, love, 	collectgarbage
	= table, pairs, ipairs, math, io, print, love, 	collectgarbage
	
module('objects')

Map = Object{}

-- the size in tiles of the individual map cells
Map.cellSize = 32
-- the number of maximum layers in the map
Map.layers = 4
-- the number of uint16s in a map cell
Map.cellTileShorts = Map.cellSize * Map.cellSize * Map.layers
-- the number of bytes in one cell
Map.cellTileBytes = Map.cellTileShorts * 2
-- the number of frames to keep a map cell around for before it is disposed
Map.unusedFrames = 1200
-- the number of tile to generate ahead
Map.lookAhead = Map.cellSize * 4
-- the size of a bucket cell
Map.bucketCellSize = Map.cellSize * 32

--
--  Returns a hash value of the supplied coordinates
--  to the nearest coordinates in the map cell structure
--
--  Also returns the x and y coordinates that are the
--	the closest cell coordinates to the ones requested
--
--  n.b. very naive implementation
--  assumes that coordinates will never be bigger than
--  1000000 in the first dimension... which is hopefully
--  true for now
--
function Map.hash(coords)
	local x = math.floor(coords[1] / Map.cellSize) * Map.cellSize
	local y = math.floor(coords[2] / Map.cellSize) * Map.cellSize
	return y * 1000000 + x, x, y
end

--
--  Map constructor
--
function Map:_clone(values)
	local o = Object._clone(self,values)
			
	-- the cells this map contains
	o._cellsInMemory = {}
	o._generated = {}
	o._minMax = {}
	o._cellMinMax = {} 
	o._zoom = {}	
	
	o:createBuckets()
	
	return o
end

--
--  Creates the collision buckets for this map
--
function Map:createBuckets()
	local ts = self._tileSet:size()	
	
	local columns = 1000000 * ts[1] / Map.bucketCellSize
	
	self._buckets = {}
	self._buckets.hash = function(x,y)
		return math.floor(math.floor(x / Map.bucketCellSize) +
				(math.floor(y / Map.bucketCellSize) * columns)) + 1
	end		
end

--
--  Calculates the minimum and maximum tile range given the
--	camera and padding
--
function Map:calculateMinMax(camera, padding)
	local cw = camera:window()
	local cv = camera:viewport()
	
	self._zoom[1] = cv[3] / cw[3]
	self._zoom[2] = cv[3] / cw[3]
	
	local ts = self._tileSet:size()	
	
	-- get the left, top, right, and bottom
	-- tiles that the camera can see plus some value that looks for further tiles
	self._minMax[1] = math.floor(cw[1] / ts[1]) - padding[1]
	self._minMax[2] = math.floor(cw[2] / ts[2])	- padding[2]
	self._minMax[3] = math.floor((cw[1] + cw[3]) / ts[1]) + padding[3]
	self._minMax[4] = math.floor((cw[2] + cw[4]) / ts[2]) + padding[4]
	-- convert these to the tiles that correspond to map cell boundaries
	self._cellMinMax[1] = math.floor(self._minMax[1] / Map.cellSize) * Map.cellSize
	self._cellMinMax[2] = math.floor(self._minMax[2] / Map.cellSize) * Map.cellSize
	self._cellMinMax[3] = math.floor(self._minMax[3] / Map.cellSize) * Map.cellSize
	self._cellMinMax[4] = math.floor(self._minMax[4] / Map.cellSize) * Map.cellSize		
end

--
--  Update map
--
function Map:update(dt, camera, profiler)
	--[[
	profiler:profile('Map first part of update',
		function()		
			self:calculateMinMax(camera, {Map.lookAhead,  Map.lookAhead,  Map.lookAhead,  Map.lookAhead})
		end)
	]]
	
		--[[
	profiler:profile('Map second part of update',
		function()				
			local generate = {}	
			-- check to see if the cells we may need shortly have been generated
			for y = self._cellMinMax[2], self._cellMinMax[4], Map.cellSize do
				for x = self._cellMinMax[1], self._cellMinMax[3], Map.cellSize do	
					local coords = {x,y}
					local hash = Map.hash(coords)								
					-- check if the cell exists
					if not self._cellsInMemory[hash] and not self._generated[hash] then
						if not self:cellExists(coords,hash) then
							log.log('Cell doesnt exist: ' .. hash)
							generate[#generate+1] = coords			
						end													
						self._generated[hash] = true
					end														
				end		
			end
					
			if #generate > 0 then
				log.log('Number of cells to generate: ' .. #generate)
				self:generateMapCells(generate)
			end
		end)
			]]
			
	profiler:profile('Map third part of update',	
		function()
			-- go through all cells and get rid of ones that are no longer required
			for k, v in pairs(self._cellsInMemory) do
				if not v._visible then
					v._framesNotUsed = v._framesNotUsed + 1
					if v._framesNotUsed > Map.unusedFrames then
						self:disposeMapCell(v)
					end
				end
			end	
		end)
end

--
--  Returns a table of visible cells
--
function Map:visibleCells()			
	-- get all of the visible cells
	local cells = {}		
	for y = self._cellMinMax[2], self._cellMinMax[4], Map.cellSize do
		for x = self._cellMinMax[1], self._cellMinMax[3], Map.cellSize do			
			local mc = self:mapCell{x,y}
			if mc then
				mc._visible = true
				mc._framesNotUsed = 0
				cells[#cells+1] = mc
			else
				cells[#cells+1] = false
			end
		end		
	end
	
	return cells
end

--
--  Draw map
--
function Map:draw(camera, profiler)	
	--[[profiler:profile('Map draw',
		function()]]
			local cw = camera:window()
			local cv = camera:viewport()
			local ts = self._tileSet:size()		
			
			self:calculateMinMax(camera, {1,1,1,1})

			-- set all map cells to not visible
			for k, mc in pairs(self._cellsInMemory) do
				mc._visible = false
			end
			
			local cells = self:visibleCells()
			
			-- coarse adjustment
			local diffX = (self._minMax[1] - self._cellMinMax[1]) + 1
			local diffY = (self._minMax[2] - self._cellMinMax[2]) + 1
			local fineX = math.floor((cw[1] % 32) * self._zoom[1])
			local fineY = math.floor((cw[2] % 32) * self._zoom[2])
			-- the starting positions so the cells will be centered in the proper location
			local startX = (-diffX * ts[1] * self._zoom[1]) - 
				fineX - (ts[1] / 2 * self._zoom[1])
			local startY = (-diffY * ts[2] * self._zoom[2]) 
				- fineY - (ts[2] / 2 * self._zoom[2])
			-- the current screen position for the cells
			local screenX = startX
			local screenY = startY
			-- the amount to move on the screen after each cell
			local screenIncX = Map.cellSize * ts[1] * self._zoom[1]
			local screenIncY = Map.cellSize * ts[2]	* self._zoom[2]
			-- draw the cells
			local currentCell = 1
			for y = self._cellMinMax[2], self._cellMinMax[4], Map.cellSize do
				screenX = startX
				for x = self._cellMinMax[1], self._cellMinMax[3], Map.cellSize do	
					-- draw the cell if it exists
					local cell = cells[currentCell]
					if cell ~= false then
						local canvas = cells[currentCell]:canvas()
						love.graphics.draw(canvas, screenX, screenY, 
							0, self._zoom[1], self._zoom[2])				
					end
					currentCell = currentCell + 1
					screenX = screenX + screenIncX
				end		
				screenY = screenY + screenIncY
			end
		--[[end)]]
end

--
--  Returns the map cell that starts at the given
--  top left coordinates
--
--  Inputs:
--		coords - an indexed table
--			[1] - horizontal coordinate of leftmost tile
--			[2] - vertcial coordinate of topmost tile
--
--	Outputs:
--		the map cell that is closest to the coordinates
--
function Map:mapCell(coords)
	local hash, x, y = Map.hash(coords)
	local mc = self._cellsInMemory[hash]
	
	if mc then 
		return mc 
	else
		mc = self:loadMapCell({x,y}, hash)
	end
	
	if mc then
		mc._hash = hash
		self._cellsInMemory[hash] = mc
		self._generated[hash] = nil
		mc:registerBuckets(self._buckets)
	end
	
	return mc
end

--
--  Does a cell exist?
--
function Map:cellExists(coords, hash)
	--log.log('Checking if cell exists: ' .. hash)
	local hash = hash or Map.hash(coords)	
	
	local exists = false	
	local f = io.open('map/' .. hash .. '.dat', 'rb')
	if f then 
		exists = true
		f:close()
	end
	return exists	
end

--
--  Loads a map cell from disk
--	
function Map:loadMapCell(coords, hash)
	--log.log('Loading map cell: ' .. hash)	
	local hash = hash or Map.hash(coords)
	
	local f = io.open('map/' .. hash .. '.dat', 'rb')
	if not f then 
		-- cell does not yet exist!
		return nil
	end
	-- read cell from file
	local tileData = f:read('*all')
	f:close()
	
	local mc = MapCell{ self._tileSet, 
		{Map.cellSize, Map.cellSize}, 
		{coords[1], coords[2]}, 
		Map.layers }
		
	-- store the tile data
	mc:setTileData(tileData, Map.cellTileBytes)	
	
	return mc	
end

--
--  Disposes of a map cell
--	
function Map:disposeMapCell(mc)
	--log.log('Disposing map cell: ' .. mc._hash)	
	-- save the map cell to disk
	self:saveMapCell(mc)
	
	if self.on_cell_dispose then
		self:on_cell_dispose(mc)
	end
	
	-- unregister the map cell from the collision buckets
	mc:unregisterBuckets(self._buckets)
	-- remove the references to all resources
	self._cellsInMemory[mc._hash] = nil	
	collectgarbage('collect')
end

--
--  Saves a map cell to disk
--	
function Map:saveMapCell(mc)
	--log.log('Saving map cell: ' .. mc._hash)
	local bytes = ffi.string(mc._tiles, Map.cellTileBytes)
	local f = io.open('map/' .. mc._hash .. '.dat' ,'wb')
	f:write(bytes)
	f:close()
end

--
--  Generates a list of map cells
--
function Map:generateMapCells(cells)
	local cmd = 'generate#'	
	for k, v in ipairs(cells) do	
		--log.log('Signalling generating thread to generate: ' .. v[1] .. ',' .. v[2])
		cmd = cmd .. v[1] .. '#' .. v[2] .. '#'
	end	
	local thread = love.thread.getThread('terrainGenerator')	
	thread:set('cmd',cmd)
end

--[[
--
--  Adds transition (overlay tiles)
--  between base terrain types
--
--  This function assumes that each base tile type 
--	consists of 18 tiles with the following and that the base tile 
--	types start at index 1 and are contiguous in 
--	a tileset
--  
function Map:transitions()
	local tilesPerType = 18
	
	--  a table that maps the edge number
	--  to a tile index in the tileset
	--  n.b. this table describes some assumptions about the
	--  layout of the tiles 
	local edgeToTileIndex = {}
	
	-- top edge
	edgeToTileIndex[4] = 14
	edgeToTileIndex[6] = 14
	edgeToTileIndex[12] = 14
	edgeToTileIndex[14] = 14
	
	-- bottom edge
	edgeToTileIndex[128] = 8
	edgeToTileIndex[192] = 8
	edgeToTileIndex[384] = 8
	edgeToTileIndex[448] = 8	
		
	-- left edge	
	edgeToTileIndex[16] = 12
	edgeToTileIndex[18] = 12
	edgeToTileIndex[80] = 12
	edgeToTileIndex[82] = 12
	
	-- right edge
	edgeToTileIndex[32] = 10
	edgeToTileIndex[40] = 10
	edgeToTileIndex[288] = 10
	edgeToTileIndex[296] = 10
	
	-- top left edge	
	edgeToTileIndex[20] = 2
	edgeToTileIndex[22] = 2
	edgeToTileIndex[24] = 2
	edgeToTileIndex[28] = 2
	edgeToTileIndex[30] = 2
	edgeToTileIndex[68] = 2
	edgeToTileIndex[72] = 2
	edgeToTileIndex[76] = 2
	edgeToTileIndex[84] = 2
	edgeToTileIndex[86] = 2
	edgeToTileIndex[88] = 2
	edgeToTileIndex[92] = 2
	edgeToTileIndex[94] = 2
	edgeToTileIndex[126] = 2	
	
	-- top right edge
	edgeToTileIndex[34] = 3
	edgeToTileIndex[36] = 3
	edgeToTileIndex[38] = 3
	edgeToTileIndex[44] = 3
	edgeToTileIndex[46] = 3
	edgeToTileIndex[258] = 3	
	edgeToTileIndex[260] = 3
	edgeToTileIndex[262] = 3
	edgeToTileIndex[290] = 3
	edgeToTileIndex[292] = 3
	edgeToTileIndex[294] = 3
	edgeToTileIndex[298] = 3		
	edgeToTileIndex[300] = 3
	edgeToTileIndex[302] = 3	
	edgeToTileIndex[318] = 3
	
	-- bottom left edge
	edgeToTileIndex[130] = 5
	edgeToTileIndex[144] = 5
	edgeToTileIndex[146] = 5
	edgeToTileIndex[208] = 5
	edgeToTileIndex[210] = 5
	edgeToTileIndex[218] = 5
	edgeToTileIndex[272] = 5	
	edgeToTileIndex[274] = 5	
	edgeToTileIndex[386] = 5
	edgeToTileIndex[400] = 5
	edgeToTileIndex[402] = 5	
	edgeToTileIndex[464] = 5
	edgeToTileIndex[466] = 5		
		
	-- bottom right edge
	edgeToTileIndex[96] = 6
	edgeToTileIndex[104] = 6	
	edgeToTileIndex[136] = 6	
	edgeToTileIndex[160] = 6	
	edgeToTileIndex[168] = 6	
	edgeToTileIndex[200] = 6
	edgeToTileIndex[224] = 6
	edgeToTileIndex[232] = 6
	edgeToTileIndex[416] = 6	
	edgeToTileIndex[424] = 6
	edgeToTileIndex[480] = 6
	edgeToTileIndex[488] = 6	
	
	-- bottom right inner edge
	edgeToTileIndex[2] = 15	
		
	-- bottom left inner edge
	edgeToTileIndex[8] = 13
	
	-- top right inner edge
	edgeToTileIndex[64] = 9
	
	-- top left inner edge
	edgeToTileIndex[256] = 7
	
	self._tiles.edges = {}
	for y = 1, self._sizeInTiles[2] do
		self._tiles.edges[y] = {}
		for x = 1, self._sizeInTiles[1] do	
			self._tiles.edges[y][x]	= {}
		end
	end
			
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP TILE TRANSITIONS ARE BEING CALCULATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do			
			local tile = self._tiles.base[y][x]
			local thisType = math.floor((tile - 1)/tilesPerType)

			local edges = 0			
			local count = 8
			-- considsr all neighbouring tiles
			for yy = y - 1, y + 1 do
				for xx = x - 1, x + 1 do
					-- only work to edge of map
					if yy >= 1 and yy <= self._sizeInTiles[2] and
						xx >= 1 and xx <= self._sizeInTiles[1] and
						not (y == yy and x == xx) then
							local neighbourTile = self._tiles.base[yy][xx]
							local neighbourType = math.floor((neighbourTile-1)/tilesPerType)							
							if neighbourType > thisType then								
								local edgeType = self._tiles.edges[yy][xx][2 ^ count]
								if (not edgeType) or (edgeType > thisType) then
									self._tiles.edges[yy][xx][2 ^ count] = thisType
								end
							end
							count = count - 1
					end										
				end
			end		
		end	
	end
	
	for y = 1, self._sizeInTiles[2] do
		for x = 1, self._sizeInTiles[1] do	
			local edges = self._tiles.edges[y][x]	
			local sum = 0
			local edgeType = 0
			local minEdgeType = 99
			for k, v in pairs(edges) do
				sum = sum + k
				if v < minEdgeType then
					edgeType = v
					minEdgeType = v
				end
			end
			
			if sum > 0 then
				local idx = edgeToTileIndex[sum] or 4
				self._tiles.overlay[y][x] = (edgeType * tilesPerType) + idx
			end
		end	
	end	
	
	for y = 1, self._sizeInTiles[2] do
		for x = 1, self._sizeInTiles[1] do	
			self._tiles.edges[y][x] = nil
		end
		self._tiles.edges[y] = nil
	end
	self._tiles.edges = nil
	
	print()
end
]]

--[[
function Map:createObject(name, x, y)
	local ts = self._tileSet:size()
		
	-- insert objet
	local o = table.clone(self._tileSet._objects[name], { deep = true })

	o._position = { x * ts[1], y * ts[2] }
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
]]

--
--  Generates a map
--
function Map:generate(xpos, ypos, sx, sy)

	-- create a table to hold all of the tiles
	local tiles = {}
	for i = 1, Map.layers do
		tiles[i] = {}
	end
	for y = 1, sy do		
		for i = 1, Map.layers do
			tiles[i][y] = {}
		end
	end
		
	-- start with all water	
	for y = 1, sy do
		io.write('MAP WATER TILES ARE BEING GENERATED... ' .. ((y / sy) * 100) .. '%             \r')
		for x = 1, sx do
			tiles[1][y][x] = 1
			if math.random() > 0.5 then
				tiles[1][y][x] = math.floor(math.random() * 3) + 16
			end
		end
	end			
	print()
	
	-- now add some land
	for y = Map.cellSize, sy - Map.cellSize - 1, Map.cellSize do
		for x = Map.cellSize, sx - Map.cellSize - 1, Map.cellSize do
			local tt = math.floor(math.random(3)) + 3
			for yy = y, y + Map.cellSize - 1 do
				for xx = x, x + Map.cellSize - 1 do
					tiles[1][yy][xx] = 11 + (tt*18)
					--[[
					if math.random() > 0.5 then
						tiles[1][yy][xx] = math.floor(math.random() * 3) + 16 + (tt*18)
					end
					]]
				end
			end
		end
	end
			
	local hash, xcoord, ycoord = Map.hash{xpos,ypos}
	
	local cx = xcoord
	local cy = ycoord
	
	for y = 1, sy - 1, Map.cellSize do
		cx = xcoord
		for x = 1, sx - 1, Map.cellSize do
			--log.log('Creating map cell at coords: ' .. cx .. ', ' .. cy)
			--log.log('Creating map cell at generated tile coords: ' .. x .. ', ' .. y)
			
			local mc = {}

			--log.log('Made new map cell table')
			
			local currentTile = 0
			local tileShorts = ffi.new('uint16_t[?]', Map.cellTileShorts)
			for i = 1, Map.layers do
				for yy = y, y + Map.cellSize - 1 do
					for xx = x, x + Map.cellSize - 1 do
						tileShorts[currentTile] = tiles[i][yy][xx] or 0
						currentTile = currentTile + 1
					end
				end
			end
			
			--log.log('Current tile: ' .. currentTile)
			
			mc._tiles = tileShorts
			local hash = Map.hash{cx,cy}
			mc._hash = hash
			
			self:saveMapCell(mc)
			cx = cx + Map.cellSize
		end
		cy = cy + Map.cellSize
	end
	
	--log.log('Finished creating map cells!')
		
		--[[
	for y = 1, self._sizeInTiles[2] do		
		self._tiles.base[y] = {}
		self._tiles.overlay[y] = {}
		self._tiles.roof[y] = {}
	end		

	-- start with all water	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP WATER TILES ARE BEING GENERATEGENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do		
			self._tiles.base[y][x] = 11
			if math.random() > 0.5 then
				self._tiles.base[y][x] = math.floor(math.random() * 3) + 16
			end
		end
	end			
	print()
	

	local terrain = 
	{
		{ name = 'GRASS', tile = 6, maxRadius = 10, minRadius = 3, numPatches = 1500, variations = true},	
		{ name = 'DIRT', tile = 5, maxRadius = 6, minRadius = 3, numPatches = 750, variations = true },		
		{ name = 'SAND', tile = 7, maxRadius = 50, minRadius = 20, numPatches = 5, variations = true }		
	}
		
	-- generate terrain
	for k, v in ipairs(terrain) do
		local maxRadius = v.maxRadius
		local minRadius = v.minRadius
		local numPatches = v.numPatches
		local tile = v.tile
		for i = 1, numPatches do
			io.write(v.name .. ' PATCHES ARE BEING GENERATED... ' .. (i / numPatches * 100) .. '%             \r')
			local x = math.floor(math.random() * (self._sizeInTiles[1] - (maxRadius * 2))) + maxRadius + 1
			local y = math.floor(math.random()* (self._sizeInTiles[2] - (maxRadius * 2))) + maxRadius + 1
			local w = math.floor(math.random() * (maxRadius-minRadius)) + minRadius
			local h = math.floor(math.random() * (maxRadius-minRadius)) + minRadius
			for yy = y - h, y + h do 
				for xx = x - w, x + w do
					self._tiles.base[yy][xx] = 18 * (tile-1) + 11
					if v.variations then
						if math.random() > 0.5 then
							self._tiles.base[yy][xx] = math.floor(math.random() * 3) + (18 * tile) - 2
						end
						
					end
				end
			end
		end
		print()
	end
	]]
	
	--[[	
	-- add random objects
	local current = 1
	local tree_cycle = { 'short_tree', 'tall_tree', 'pine_tree' }
	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP OBJECTS ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do
			if y > 5 and y < self._sizeInTiles[2] - 5 and 
				x > 5 and x < self._sizeInTiles[1] - 5 and 
				math.random() > 0.99 and 
				math.floor(self._tiles.base[y][x] / 18) == 5 then
					local o = self:createObject(tree_cycle[(current % 3) + 1],x,y)
					table.insert(self._objects, o)
					current = current + 1
			end
		end
	end		
	print()
	]]
end

--[[
--
--  Create colliders
--
function Map:createColliders(b)
	local bs = self._tileSet:boundaries()
	local ts = self._tileSet:size()
	
	local function addCollider(layer, x, y)
		local tile = self._tiles[layer][y][x]
		if tile then
			local boundary = bs[tile]
			if boundary and (boundary[3] > 0 or boundary[4] > 0) then
				local tx = x * ts[1]
				local ty = y * ts[2]
				local o = {}				
				o._position = { x * ts[1], y * ts[2] }
				
				o._boundary = {}
				o._boundary[1] = o._position[1] + boundary[1] - (ts[1] / 2)
				o._boundary[2] = o._position[2] + boundary[2] - (ts[2] / 2)
				o._boundary[3] = o._position[1] + boundary[3] - (ts[1] / 2)
				o._boundary[4] = o._position[2] + boundary[4] - (ts[2] / 2)
				
				o._ids = {}				
				o._ids[b.hash(o._boundary[1], o._boundary[2])] = true
				o._ids[b.hash(o._boundary[1], o._boundary[4])] = true
				o._ids[b.hash(o._boundary[3], o._boundary[2])] = true
				o._ids[b.hash(o._boundary[3], o._boundary[4])] = true
												
				table.insert(self._colliders, o)
			end	
		end
	end
	
	-- add colliders for base and roof tiles
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP COLLIDERS ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do
			addCollider('base', x, y)
			addCollider('overlay', x, y)
		end
	end	
	
	-- add colliders for objects
	for k, v in ipairs(self._objects) do
		v._ids = {}
		v._ids[b.hash(v._boundary[1], v._boundary[2])] = true
		v._ids[b.hash(v._boundary[1], v._boundary[4])] = true
		v._ids[b.hash(v._boundary[3], v._boundary[2])] = true
		v._ids[b.hash(v._boundary[3], v._boundary[4])] = true
				
		table.insert(self._colliders, v)
	end
	
	print()
end
]]

--
--  Returns a table with the ids for the bucket cells
--	that are currently visible
--
function Map:visibleIds()
	local ids = {}
	
	for _, cell in pairs(self._cellsInMemory) do
		if cell._visible then
			for id, _ in pairs(cell._bucketIds) do
				ids[id] = true
			end
		end
	end
	
	return ids
end