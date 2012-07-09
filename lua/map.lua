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
	--  a table that maps the edge number
	--  to a tile index in the tileset
	--  n.b. this table describes some assumptions about the
	--  layout of the tiles in the tileset as follows:
	--	indices of tiles
	--	1 - fully enclosed - type 1
	--	2 - bottom right corner contains other tile type
	--	3 - botom left corner contains other tile type
	--	4 - fully enclosed - type 2
	--	5 - top right corner contains other tile type
	--	6 - top left corner contains other tile type
	--	7 - left and top edges contains other tile type
	--	8 - top edge contains other tile type
	--	9 - top and right edges contains other tile type
	--  10 - left edge contains other tile type
	--  11 - no other tile type adjacent
	--  12 - right edge contains other tile type
	--  13 - bottom and left edges contains other tile type
	--  14 - bottom edge contains other tile type
	--  15 - bottom and right edges contains other tile type
	--  16 - no other tile type adjacent
	--  17 - no other tile type adjacent
	--  18 - no other tile type adjacent	
	local edgeToTileIndex =
	{
		
	}
	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP TILE TRANSITIONS ARE BEING CALCULATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do			
			local tile = self._tiles.base[y][x]
			local thisType = math.floor((tile - 1)/18)
			
			local edges = 0			
			local count = 0
			-- considsr all neighbouring tiles
			for yy = y - 1, y + 1 do
				for xx = x - 1, x + 1 do
					-- only work to edge of map
					if yy >= 1 and yy <= self._sizeInTiles[2] and
						xx >= 1 and xx <= self._sizeInTiles[1] and
						not (y == yy and x == xx) then
							local neighbourTile = self._tiles.base[yy][xx]
							local neighbourType = math.floor((neighbourTile-1)/18)
							
							if neighbourType ~= thisType then
								edges = edges + 2 ^ count
							end
							count = count + 1
					end					
				end
			end		

			if edges > 0 then
				self._tiles.overlay[y][x] = (thisType * 18) + 2
			end
		end
	end
	
	print()
end

--
--  Generates a map
--
function _M:generate()
	local ts = self._tileSet:size()
		
	-- insert objet
	local function addObject(name, x, y)			
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
			
			table.insert(drawTable.object, 
				{ self._position[2] + self._height - (self._position[1] * 0.0000000001), 
				self._image[1], 
				sx, sy, 
				zoomX, zoomY, self._offset[1], self._offset[2] })
				
			table.insert(drawTable.roof, 
				{ self._position[2] + self._height - (self._position[1] * 0.0000000001), 
				self._image[2], 
				sx, sy, 
				zoomX, zoomY, self._offset[1], self._offset[2] })
				
		end
		
		table.insert(self._objects, o)
	end
	
	for y = 1, self._sizeInTiles[2] do		
		self._tiles.base[y] = {}
		self._tiles.overlay[y] = {}
		self._tiles.roof[y] = {}
	end		
	
	local current = 1
	local tree_cycle = { 'short_tree', 'tall_tree', 'pine_tree' }
	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP TILES ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		for x = 1, self._sizeInTiles[1] do
			-- select a base tile
			local found = false
			local tile
			while not found do
				 --tile = math.floor(math.random()*3) + 16
				 tile = math.floor(math.random()*36) + 1
				if self._tileSet._heights[tile] == 0 then
					found = true
				end
			end
			self._tiles.base[y][x] = tile		
			
			if y > 5 and y < self._sizeInTiles[2] - 5 and 
				x > 5 and x < self._sizeInTiles[1] - 5 and 
				math.random() > 0.98 then
					addObject(tree_cycle[(current % 3) + 1],x,y)
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
			if boundary then
				local tx = x * ts[1]
				local ty = y * ts[2]
				local ids = {}
				local boundary = { tx + boundary[1] + ts[1] / 2, 
					ty + boundary[2] + ts[2] / 2,
					tx + boundary[3] + ts[1] / 2,
					ty + boundary[4] + ts[2] / 2}									
						
				ids[b.hash(boundary[1], boundary[2])] = true
				ids[b.hash(boundary[1], boundary[4])] = true
				ids[b.hash(boundary[3], boundary[2])] = true
				ids[b.hash(boundary[3], boundary[4])] = true
												
				table.insert(self._colliders,
					{ _boundary = boundary, _ids = ids })
			end	
		end
	end
	
	-- add colliders for base and roof tiles
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP COLLIDERS ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		tx = 0
		for x = 1, self._sizeInTiles[1] do
			addCollider('base', x, y)
			addCollider('roof', x, y)
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
			table.insert(buckets[k], v)
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
	
	for y = sty, ety do
		local ty = y * ts[2]
		for x = stx, etx do	
			local tx = x * ts[1]			
			ids[b.hash(tx, ty)] = true
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
	
	for y = sty, ety do
		cx = sx
		for x = stx, etx do		
			-- draw the base layer
			local tile = self._tiles.base[y][x]
			table.insert(drawTable.base, 
				{ y * ts[1] + th[tile], tq[tile], 
				cx, cy, zoomX, zoomY, htsx, htsy})
			
			-- draw the overlay layer
			local tile = self._tiles.overlay[y][x]
			if tile then
				table.insert(drawTable.overlay, 
					{ y * ts[1] + th[tile], tq[tile], 
					cx, cy, zoomX, zoomY, htsx, htsy})
			end
				
			-- draw the roof layer if a tile exists
			local tile = self._tiles.roof[y][x]
			if tile then
				table.insert(drawTable.roof, 
					{ y * ts[1] + th[tile] + xof, tq[tile], 
					cx, cy, zoomX, zoomY, htsx, htsy})
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

