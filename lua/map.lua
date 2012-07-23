--[[
	map.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

require 'map_cell'

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

local log = require 'log'

local table, pairs, ipairs, math, io, love, tostring, collectgarbage
	= table, pairs, ipairs, math, io, love, tostring, collectgarbage
	
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
	o._cellsToDispose = {}
	o._cellsToLoad = {}
	
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
	self:calculateMinMax(camera, {Map.lookAhead,  Map.lookAhead,  Map.lookAhead,  Map.lookAhead})

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
	]]
	
	-- go through all cells and get rid of ones that are no longer required
	for k, v in pairs(self._cellsInMemory) do
		if not v._visible then
			v._framesNotUsed = v._framesNotUsed + 1
			if v._framesNotUsed > Map.unusedFrames then
				self._cellsToDispose[v._hash] = v
			end
		end
	end	

	-- dispose one cell per frame
	for k, v in pairs(self._cellsToDispose) do
		self:disposeMapCell(v)
		self._cellsToDispose[k] = nil
		break
	end
	
	-- load one cell per frame
	for k, v in pairs(self._cellsToLoad) do
		local mc = self:loadMapCell(v, k)
		if mc then
			mc._hash = k
			self._cellsInMemory[k] = mc
			self._generated[k] = nil
			mc:registerBuckets(self._buckets)
			self._cellsToLoad[k] = nil
			break
		end
	end
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
function Map:draw(camera)
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
		self._cellsToDispose[hash] = nil
		self._cellsToLoad[hash] = {x,y}
	end
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
	local tileData = f:read(Map.cellTileBytes)
	local objBytes = f:read('*number')

	--log.log('objBytes')
	--log.log(tostring(objBytes))	
	local objs 
	if objBytes > 0 then		
		objs = f:read(objBytes)
	end
	
	f:close()
	
	local mc = MapCell{ self._tileSet, 
		{Map.cellSize, Map.cellSize}, 
		{coords[1], coords[2]}, 
		Map.layers }
		
	-- store the tile data
	mc:setTileData(tileData, objs)	
	
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
	
	if mc._objectData then
		f:write(ffi.sizeof(mc._objectData))
		local bytes = ffi.string(mc._objectData, ffi.sizeof(mc._objectData))	
		--log.log('ffi.sizeof(mc._objectData)')
		--log.log(ffi.sizeof(mc._objectData))		
		f:write(bytes)	
	else
		f:write(0)
	end
	
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

--
--  Adds transition (overlay tiles)
--  between base terrain types
--
--  This function assumes that each base tile type 
--	consists of 18 tiles with the following and that the base tile 
--	types start at index 1 and are contiguous in 
--	a tileset
--  
function Map:transitions(tiles)
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
	
	local sy = #tiles[1]
	local sx = #tiles[1][1]
	
	local edges = {}
	for y = 1, sy do
		edges[y] = {}
		for x = 1, sx do	
			edges[y][x]	= {}
		end
	end
			
	for y = 1, sy do
		for x = 1, sx do			
			local tile = tiles[1][y][x]
			local thisType = math.floor((tile - 1)/tilesPerType)

			local count = 8
			-- considsr all neighbouring tiles
			for yy = y - 1, y + 1 do
				for xx = x - 1, x + 1 do
					-- only work to edge of map
					if yy >= 1 and yy <= sy and
						xx >= 1 and xx <= sx and
						not (y == yy and x == xx) then
							local neighbourTile = tiles[1][yy][xx]
							local neighbourType = math.floor((neighbourTile-1)/tilesPerType)							
							if neighbourType > thisType then								
								local edgeType = edges[yy][xx][2 ^ count]
								if (not edgeType) or (edgeType > thisType) then
									edges[yy][xx][2 ^ count] = thisType
								end
							end
							count = count - 1
					end										
				end
			end		
		end	
	end
	
	for y = 1, sy do
		for x = 1, sx do	
			local edgeList = edges[y][x]	
			local sum = 0
			local edgeType = 0
			local minEdgeType = 99
			for k, v in pairs(edgeList) do
				sum = sum + k
				if v < minEdgeType then
					edgeType = v
					minEdgeType = v
				end
			end
			
			if sum > 0 then
				local idx = edgeToTileIndex[sum] or 4
				tiles[2][y][x] = (edgeType * tilesPerType) + idx
			end
		end	
	end	

	edges = nil
end

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
		for x = 1, sx do
			tiles[1][y][x] = 11
			if math.random() > 0.5 then
				tiles[1][y][x] = math.floor(math.random() * 3) + 16
			end
		end
	end			
	
	--[[
	-- make a box surrounding the water as a barrier
	-- N.B. this should be done automatically by tile transitions
	for y = Map.cellSize - 1, sy - Map.cellSize do
		tiles[1][y][Map.cellSize - 1] = 1
		tiles[1][y][sx - Map.cellSize] = 1
	end
	for x = Map.cellSize - 1, sx - Map.cellSize - 1 do
		tiles[1][Map.cellSize - 1][x] = 1
		tiles[1][sx - Map.cellSize][x] = 1
	end	
	]]
	
	-- now add some land
	for y = Map.cellSize, sy - Map.cellSize - 1, Map.cellSize do
		for x = Map.cellSize, sx - Map.cellSize - 1, Map.cellSize do
			local tt = math.floor(math.random(2)) + 4
			for yy = y, y + Map.cellSize - 1 do
				for xx = x, x + Map.cellSize - 1 do
					tiles[1][yy][xx] = 11 + (tt*18)
					if math.random() > 0.5 then
						tiles[1][yy][xx] = math.floor(math.random() * 3) + 16 + (tt*18)
					end
				end
			end
		end
	end
	
	-- generate tile transitions
	self:transitions(tiles)
	
	-- add random objects
	local current = 1
	local tree_cycle = { 'short_tree', 'tall_tree', 'pine_tree' }
	
	-- create a table to hold all of the objects
	local objects = {}
	for y = 1, sy do		
		objects[y] = {}
	end	
	
	local ts = self._tileSet:size()
	
	local hash, xcoord, ycoord = Map.hash{xpos,ypos}
	
	for y = Map.cellSize, sy - Map.cellSize do
		for x = Map.cellSize, sx - Map.cellSize do
			if math.random() > 0.99 and math.floor(tiles[1][y][x] / 18) == 5 then
				objects[y][x] = { name = tree_cycle[(current % 3) + 1], 
					x = xcoord * ts[1] + x * ts[1], y = ycoord * ts[1] + y * ts[2] }
				current = current + 1
			end
		end
	end
	
	local cx = xcoord
	local cy = ycoord
	
	local cells = {}
	
	for y = 1, sy - 1, Map.cellSize do
		cx = xcoord
		for x = 1, sx - 1, Map.cellSize do
			--log.log('Creating map cell at coords: ' .. cx .. ', ' .. cy)
			--log.log('Creating map cell at generated tile coords: ' .. x .. ', ' .. y)
			
			local mc = {}
			mc._objects = {}
			
			--log.log('Made new map cell table')
			
			local currentTile = 0
			local tileShorts = ffi.new('uint16_t[?]', Map.cellTileShorts)
			for i = 1, Map.layers do
				for yy = y, y + Map.cellSize - 1 do
					for xx = x, x + Map.cellSize - 1 do
						tileShorts[currentTile] = tiles[i][yy][xx] or 0
						currentTile = currentTile + 1
						
						if i == 1 and objects[yy][xx] then
							table.insert(mc._objects, objects[yy][xx])
						end
					end
				end
			end
			
			--log.log('Current tile: ' .. currentTile)
			
			mc._tiles = tileShorts
			local hash = Map.hash{cx,cy}
			mc._hash = hash

			mc._objectData = ffi.new('map_object[?]', #mc._objects)
			local objectBytes = 0
			for k, v in ipairs(mc._objects) do
				mc._objectData[k-1].name = v.name
				mc._objectData[k-1].x = v.x
				mc._objectData[k-1].y = v.y
			end	
			mc._objects = nil	
	
			cells[#cells+1] = mc
			cx = cx + Map.cellSize
		end
		cy = cy + Map.cellSize
	end
		
	for k, v in ipairs(cells) do
		self:saveMapCell(v)
	end
	
	--log.log('Finished creating map cells!')		
end

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