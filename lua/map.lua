--[[
	map.lua
	
	Created JUN-21-2012
]]

require 'table_ext'

module(..., package.seeall)

--
--  Creates a new map
--
function _M:new(t)
	self.__index = self    
	setmetatable(t, self)
	
	t._tiles = {
		base = {},
		overlay = {},
		roof = {}	
	}
	t._objects = {}
	t._colliders = {}
	
	-- center the map by default
	local tileSize = t._tileSet:size()
	t._size = { t._sizeInTiles[1] * tileSize[1],
				t._sizeInTiles[2] * tileSize[2] }
	
	return t
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
function _M:transitions()
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

function _M:createObject(name, x, y)
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

--
--  Generates a map
--
function _M:generate()
		
	for y = 1, self._sizeInTiles[2] do		
		self._tiles.base[y] = {}
		self._tiles.overlay[y] = {}
		self._tiles.roof[y] = {}
	end		

	-- start with all water	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP WATER TILES ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do		
			self._tiles.base[y][x] = 11
			if math.random() > 0.5 then
				self._tiles.base[y][x] = math.floor(math.random() * 3) + 16
			end
		end
	end		
	print()
	
	-- generate land
	local maxRadius = 6
	local minRadius = 3
	local numPatches = 750
	for i = 1, numPatches do
		io.write('MAP LAND PATCHES ARE BEING GENERATED... ' .. (i / numPatches * 100) .. '%             \r')
		local x = math.floor(math.random() * (self._sizeInTiles[1] - (maxRadius * 2))) + maxRadius + 1
		local y = math.floor(math.random()* (self._sizeInTiles[2] - (maxRadius * 2))) + maxRadius + 1
		local w = math.floor(math.random() * (maxRadius-minRadius)) + minRadius
		local h = math.floor(math.random() * (maxRadius-minRadius)) + minRadius
		for yy = y - h, y + h do 
			for xx = x - w, x + w do
				self._tiles.base[yy][xx] = 29
				if math.random() > 0.5 then
					self._tiles.base[yy][xx] = math.floor(math.random() * 3) + 34
				end
			end
		end
	end
	print()
	
	
	-- add dirt patches
	local maxRadius = 10
	local minRadius = 3
	local numPatches = 1500
	for i = 1, numPatches do
		io.write('MAP DIRT PATCHES ARE BEING GENERATED... ' .. (i / numPatches * 100) .. '%             \r')
		local x = math.floor(math.random() * (self._sizeInTiles[1] - (maxRadius * 2))) + maxRadius + 1
		local y = math.floor(math.random()* (self._sizeInTiles[2] - (maxRadius * 2))) + maxRadius + 1
		local w = math.floor(math.random() * (maxRadius-minRadius)) + minRadius
		local h = math.floor(math.random() * (maxRadius-minRadius)) + minRadius
		for yy = y - h, y + h do 
			for xx = x - w, x + w do
				self._tiles.base[yy][xx] = 47
				if math.random() > 0.5 then
					self._tiles.base[yy][xx] = math.floor(math.random() * 3) + 52
				end
			end
		end
	end
	print()
	
	-- add random objects
	local current = 1
	local tree_cycle = { 'short_tree', 'tall_tree', 'pine_tree' }
	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP OBJECTS ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do
			if y > 5 and y < self._sizeInTiles[2] - 5 and 
				x > 5 and x < self._sizeInTiles[1] - 5 and 
				math.random() > 0.98 then
					local o = self:createObject(tree_cycle[(current % 3) + 1],x,y)
					table.insert(self._objects, o)
					current = current + 1
			end
		end
	end		
	print()
end


--
--  Create colliders
--
function _M:createColliders(b)
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

--
--  Registers the map in the proper
--	collision buckets
--
function _M:registerBuckets(buckets)
	for _, v in pairs(self._colliders) do
		for k, _ in pairs(v._ids) do	
			if buckets[k] then				
				table.insert(buckets[k], v)
			end
		end
	end
end

--
--  Returns a table with the ids for the bucket cells
--	that surround the camera.
--
--	Inputs:
--		camera - the camera
--		b - the bucket table
--		padding - the number of cells on either side of the
--			visble tiles to include
--
function _M:nearIds(camera, b, padding)
	local cw = camera:window()
	local cv = camera:viewport()
	local ts = self._tileSet:size()
	local zoomX = cv[3] / cw[3] 
	local zoomY = cv[4] / cw[4]	
	local ztx = ts[1] * zoomX
	local zty = ts[2] * zoomY
	local tcx = math.floor(b.cellSize / ztx * padding)
	local tcy = math.floor(b.cellSize / zty * padding)
						
	local stx = math.floor(cw[1] / ts[1]) - tcx
	local etx = stx + math.floor(cv[3] / ztx) + (tcx * 2)
	local sty = math.floor(cw[2] / ts[2]) - tcy
	local ety = sty + math.floor(cv[4] / zty) + (tcy * 2)
	
	local ids = {}
		
	local stx = math.max(1,stx)
	local etx = math.min(self._sizeInTiles[1] - 1,etx)	
	local sty = math.max(1,sty)
	local ety = math.min(self._sizeInTiles[2] - 1,ety)
	
	for y = sty, ety do
		local ty = y * ts[2]
		local startHash = b.hash(stx * ts[1], ty)
		local endHash = b.hash(etx * ts[1], ty)
		for h = startHash, endHash do
			ids[h] = true
		end			
	end
	
	return ids
end

--
--  Draw the map
--
function _M:drawTiles(camera, drawTable)	
	local cw, cv, zoomX, zoomY =
		drawTable.cw, drawTable.cv, 
		drawTable.zoomX, drawTable.zoomY

	local tq = self._tileSet:quads()
	local ts = self._tileSet:size()
	local th = self._tileSet:heights()
	local ztx = ts[1] * zoomX
	local zty = ts[2] * zoomY
	local htsx = ts[1] / 2
	local htsy = ts[2] / 2
						
	local stx = math.floor(cw[1] / ts[1])
	local etx = stx + math.floor(cv[3] / ztx) + 2
	local ofx = math.floor(cw[1] - stx * ts[1]) * zoomX
	local sty = math.floor(cw[2] / ts[2])
	local ety = sty + math.floor(cv[4] / zty) + 2
	local ofy = math.floor(cw[2] - sty * ts[2]) * zoomY
	
	local sx = (cv[1] - ofx)
	local sy = (cv[2] - ofy)
	local cx = sx
	local cy = sy
	
	local base = drawTable.base
	local overlay = drawTable.overlay
	local roof = drawTable.roof
	
	for y = sty, ety do
		cx = sx
		for x = stx, etx do		
			-- draw the base layer
			local tile = self._tiles.base[y][x]
			base[#base+1] = 
				{ y * ts[1] + th[tile], tq[tile], 
				cx, cy, zoomX, zoomY, htsx, htsy}
			
			-- draw the overlay layer
			local tile = self._tiles.overlay[y][x]
			if tile then
				overlay[#overlay + 1] = 
					{ y * ts[1] + th[tile], tq[tile], 
					cx, cy, zoomX, zoomY, htsx, htsy}
			end
				
			-- draw the roof layer if a tile exists
			local tile = self._tiles.roof[y][x]
			if tile then
				roof[#roof + 1] = 
					{ y * ts[1] + th[tile] + xof, tq[tile], 
					cx, cy, zoomX, zoomY, htsx, htsy}
			end			
			cx = cx + ztx
		end
		cy = cy + zty
	end
end

-- 
--  Returns the map size
--
function _M:size()
	return self._size
end

-- 
--  Returns the map size in tiles
--
function _M:sizeInTiles()
	return self._sizeInTiles
end

