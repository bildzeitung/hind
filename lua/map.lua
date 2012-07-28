--[[
	map.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

local marshal = require 'marshal'

require 'map_cell'

local log = require 'log'

local table, pairs, ipairs, math, io, love, tostring
	= table, pairs, ipairs, math, io, love, tostring
	
module('objects')

Map = Object{}

-- the size in tiles of the individual map cells
Map.cellSize = 8
-- the number of maximum layers in the map
Map.layers = 4
-- the number of frames to keep a map cell around for before it is disposed
Map.unusedFrames = 60
-- the number of tile to generate ahead
Map.lookAhead = Map.cellSize * 4
-- the size of a bucket cell
Map.bucketCellSize = Map.cellSize * 32

Map.disposeCellsPerFrame = 1
Map.loadCellsPerFrame = 1

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
function Map.hash(x, y)
	local x = math.floor(x / Map.cellSize) * Map.cellSize
	local y = math.floor(y / Map.cellSize) * Map.cellSize
	return y * 1000000 + x, x, y
end

--
--  Returns x,y coordinates from a hash value
--  See notes about Map.hash
--
function Map.unhash(hash)
	local y = math.floor(hash / 1000000)
	local x = hash % 1000000
	return x, y
end

--
--  Map constructor
--
function Map:_clone(values)
	local o = Object._clone(self,values)
			
	-- the cells this map contains
	o._cellsInMemory = {}
	o._minMax = {}
	o._cellMinMax = {} 
	o._zoom = {}	
	o._cellsToDispose = {}
	o._cellsLoading = {}	
	o:createBuckets()
	o._visibleCells = {}
	o._cellsShouldBeVisible = {}
	
	local thread = love.thread.getThread('fileio')
	o._communicator = ThreadCommunicator{ thread }	
	
	return o
end

--
--  Creates the collision buckets for this map
--
function Map:createBuckets()
	local ts = self._tileSet:size()	
	
	local columns = math.floor(1000000 * ts[1] / Map.bucketCellSize)
	
	self._buckets = {}
	self._buckets.hash = function(x,y)
		return math.floor(x / Map.bucketCellSize) + 
			(math.floor(y / Map.bucketCellSize) * columns) + 1
	end		
end

--
--  Calculates the minimum and maximum tile range given the
--	camera and padding
--
function Map:calculateMinMax(camera, l, t, r, b)
	local cw = camera:window()
	local cv = camera:viewport()
	
	self._zoom[1] = cv[3] / cw[3]
	self._zoom[2] = cv[3] / cw[3]
	
	local ts = self._tileSet:size()	
	
	-- get the left, top, right, and bottom
	-- tiles that the camera can see plus some value that looks for further tiles
	self._minMax[1] = math.floor(cw[1] / ts[1]) - l
	self._minMax[2] = math.floor(cw[2] / ts[2])	- t
	self._minMax[3] = math.floor((cw[1] + cw[3]) / ts[1]) + r
	self._minMax[4] = math.floor((cw[2] + cw[4]) / ts[2]) + b
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
	-- go through all cells and mark any that are no longer required
	--profiler:profile('marking map cells for disposal', function()						
			for k, v in pairs(self._cellsInMemory) do
				if not v._visible then
					v._framesNotUsed = v._framesNotUsed + 1
					if v._framesNotUsed > Map.unusedFrames then
						self._cellsToDispose[v._hash] = v
					end
				end
			end	
		--end) -- profile
	
	-- dispose cells if there are any to dispose
	--profiler:profile('disposing map cells', function()			
			local cellsDisposed = 0
			for k, v in pairs(self._cellsToDispose) do
				self:disposeMapCell(v)
				self._cellsToDispose[k] = nil
				cellsDisposed = cellsDisposed + 1
				if cellsDisposed >= Map.disposeCellsPerFrame then break end
			end	
		--end) -- profile
	
	-- receive any map cells that have been loaded
	--profiler:profile('receiving loaded map cells', function()
			self:receiveLoadedCells()
		--end) -- profile
end

--
--  Returns a table of visible cells
--
function Map:visibleCells()		
	local cells = self._visibleCells	
	for k, v in pairs(cells) do
		cells[k] = nil
	end
	local shouldBeVisible = self._cellsShouldBeVisible
	for k, v in pairs(shouldBeVisible) do
		shouldBeVisible[k] = nil
	end
	
	-- get all of the visible cells
	for y = self._cellMinMax[2], self._cellMinMax[4], Map.cellSize do
		for x = self._cellMinMax[1], self._cellMinMax[3], Map.cellSize do			
			local mc, hash = self:mapCell(x,y)
			shouldBeVisible[hash] = true
			if mc then
				mc._visible = true
				mc._framesNotUsed = 0
				cells[#cells+1] = mc				
			else
				cells[#cells+1] = false				
			end
		end		
	end
end

--
--  Draw map
--
function Map:draw(camera)
	local cw = camera:window()
	local cv = camera:viewport()
	local ts = self._tileSet:size()		
	
	-- set all map cells to not visible
	for k, mc in pairs(self._cellsInMemory) do
		mc._visible = false
	end
	
	self:calculateMinMax(camera, Map.cellSize,Map.cellSize,Map.cellSize,Map.cellSize)
	self:visibleCells()
	local cells = self._visibleCells
	
	-- coarse adjustment
	local diffX = (self._minMax[1] - self._cellMinMax[1]) + Map.cellSize
	local diffY = (self._minMax[2] - self._cellMinMax[2]) + Map.cellSize
	local fineX = math.floor((cw[1] % ts[1]) * self._zoom[1])
	local fineY = math.floor((cw[2] % ts[2]) * self._zoom[2])
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
function Map:mapCell(x, y)
	local hash, x, y = Map.hash(x, y)
	self._cellsToDispose[hash] = nil
	
	local mc = self._cellsInMemory[hash]	
	
	if not mc then
		if not self._cellsLoading[hash] then
			self._cellsLoading[hash] = true
			self:loadMapCell(hash)
		end		
	end
	
	return mc, hash
end

--
--  Loads a map cell  from disk using fileio thread
--
function Map:loadMapCell(hash)
	self._communicator:send('loadMapCell',hash)
end

--
--  Receives any actors that have been loaded
--	by the file io thread
--
function Map:receiveLoadedCells()
	local cellsLoaded = 0
	local received = false
	repeat
		received = false
		local hash = self._communicator:receive('loadedMapCell')
		if hash and hash ~= 0 then
			local tiles = self._communicator:demand('loadedMapCell')
			local area = self._communicator:demand('loadedMapCell')
			local actors = self._communicator:demand('loadedMapCell')	
			self._cellsLoading[hash] = nil
		
			if self._cellsShouldBeVisible[hash] then
				received = true							
				local x, y = Map.unhash(hash)			
				local mc = MapCell{ self._tileSet, 
					{Map.cellSize, Map.cellSize}, {x, y}, Map.layers }
				mc._hash = hash			
				self._cellsInMemory[hash] = mc				
				mc:data(marshal.decode(tiles), area, marshal.decode(actors))
				mc:registerBuckets(self._buckets)
				if self.on_cell_load then
					self:on_cell_load(mc)
				end
				cellsLoaded = cellsLoaded + 1
				if cellsLoaded >= Map.loadCellsPerFrame then 
					break
				end			
			end
		end
	until not received 
end

--
--  Saves a map cell to disk using fileio thread
--	
function Map:saveMapCell(mc)
	self._communicator:send('saveMapCell',mc._hash)
	local s = marshal.encode(mc._tiles)
	self._communicator:send('saveMapCell',s)
	
	self._communicator:send('saveMapCell',mc._area)	
	
	local s = marshal.encode(mc._actors)	
	self._communicator:send('saveMapCell',s)		
end

--
--  Disposes of a map cell
--	
function Map:disposeMapCell(mc)
	-- update cell's actor data
	local actors = {}
	for k, _ in pairs(mc._bucketIds) do
		if self._buckets['count' .. k] == 1 then
			-- add any actors to actor data
			for _, v in pairs(self._buckets[k]) do
				if v._id then
					actors[#actors+1] = v._id
				end
			end
		end
	end
	
	mc._actors = actors
	
	-- save the map cell to disk
	self:saveMapCell(mc)
	
	if self.on_cell_dispose then
		self:on_cell_dispose(mc)
	end
	
	-- unregister the map cell from the collision buckets
	mc:unregisterBuckets(self._buckets)
	-- remove the references to all resources
	self._cellsInMemory[mc._hash] = nil	
end

--
--  Returns a table with the ids for the bucket cells
--	that are currently visible
--
function Map:visibleIds(id_table)
	local ids = id_table
	for k, v in pairs(ids) do
		ids[k] = nil
	end
	
	for _, cell in pairs(self._cellsInMemory) do
		if cell._visible then
			for id, _ in pairs(cell._bucketIds) do
				ids[id] = true
			end
		end
	end
end

--
--  Converts a position to a tile coordinate
--
function Map:posToTile(x, y)
	local ts = self._tileSet:size()
	return math.floor(x / ts[1]), math.floor(y / ts[2])
end