--[[
	map.lua
	
	Created JUN-21-2012
]]

module(..., package.seeall)

--
--  Creates a new map
--
function _M:new(t)
	self.__index = self    
	setmetatable(t, self)
	
	t._tiles = {
		base = {},
		object = {},
		roof = {}	
	}
	t._colliders = {}
	
	-- center the map by default
	local tileSize = t._tileSet:size()
	t._size = { t._sizeInTiles[1] * tileSize[1],
				t._sizeInTiles[2] * tileSize[2] }
	
	return t
end

--
--  Generates a map
--
function _M:generate()
	-- insert objet
	local function addObject(name, x, y)		
		local definition = self._tileSet._definitions[name]

		local sx = x - definition.x
		local sy = y - definition.y		
		local cx, cy = sx, sy
		
		local counter = 1
		for yy = 1, definition.h do
			cx = sx
			for xx = 1, definition.w do
				self._tiles.object[cy][cx] = definition.o[counter]
				self._tiles.roof[cy][cx] = definition.r[counter]
				counter = counter + 1
				cx = cx + 1
			end
			cy = cy + 1
		end
	end
	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP TILES ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		self._tiles.base[y] = {}
		self._tiles.object[y] = {}
		self._tiles.roof[y] = {}
		for x = 1, self._sizeInTiles[1] do
			self._tiles.base[y][x] = math.floor(math.random()*3) + 37			
			if y > 5 and y < self._sizeInTiles[2] - 5 and 
				x > 5 and x < self._sizeInTiles[1] - 5 and 
				math.random() > 0.98 then
					addObject('pine_tree',x,y)
			end
		end
	end	
	
	print()
end


--
--  Create colliders
--
function _M:createColliders(b)
	self._colliders = {}
	local bs = self._tileSet:boundaries()
	local ts = self._tileSet:size()
	local tx, ty = 0 ,0 
	
	local function addCollider(layer, x, y)
		local tile = self._tiles[layer][y][x]
		if tile then
			local boundary = bs[tile]
			if boundary then
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
	
	for y = 1, self._sizeInTiles[2] do
		io.write('MAP COLLIDERS ARE BEING GENERATED... ' .. ((y / self._sizeInTiles[2]) * 100) .. '%             \r')
		tx = 0
		for x = 1, self._sizeInTiles[1] do
			addCollider('base', x, y)
			addCollider('object', x, y)
			addCollider('roof', x, y)
			tx = tx + ts[1]
		end
		ty = ty + ts[2]
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
function _M:draw(camera, drawTable)	
	local im = self._tileSet:image()
	local cw = camera:window()
	local cv = camera:viewport()
	local tq = self._tileSet:quads()
	local ts = self._tileSet:size()
	local th = self._tileSet:heights()
	local zoomX = cv[3] / cw[3] 
	local zoomY = cv[4] / cw[4]	
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
				{ y * ts[1] + th[tile], im, tq[tile], 
				cx, cy, zoomX, zoomY, htsx, htsy})
				
			-- draw the object layer if a tile exists
			local tile = self._tiles.object[y][x]
			if tile then
				table.insert(drawTable.object, 
					{ y * ts[1] + th[tile], im, tq[tile], 
					cx, cy, zoomX, zoomY, htsx, htsy})
			end
					
			-- draw the roof layer if a tile exists
			local tile = self._tiles.roof[y][x]
			if tile then
				table.insert(drawTable.roof, 
					{ y * ts[1] + th[tile], im, tq[tile], 
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

