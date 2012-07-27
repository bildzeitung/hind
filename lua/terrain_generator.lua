--[[
	terrain_generator.lua
	
	Created JUN-21-2012
]]

local Object = (require 'object').Object

local marshal = require 'marshal'
local log = require 'log'

local pairs, ipairs, math, table, love
	= pairs, ipairs, math, table, love

module('objects')

TerrainGenerator = Object{}

--
--  TerrainGenerator constructor
--
function TerrainGenerator:_clone(values)
	local o = Object._clone(self,values)
			
	local thread = love.thread.getThread('fileio')
	o._communicator = ThreadCommunicator{ thread }	
	
	return o
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
function TerrainGenerator:transitions()
	local tiles = self._tiles
	
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
function TerrainGenerator:generate(xpos, ypos, sx, sy, heroName)
	self._heroName = heroName
	
	self._actors = {}
	local actors = self._actors
	self._tiles = {}
	local tiles = self._tiles
	self._objects = {}
	local objects = self._objects
	
	-- create a table to hold all of the tiles
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
	
	-- now add some land
	for y = Map.cellSize, sy - Map.cellSize - 1, Map.cellSize do
		for x = Map.cellSize, sx - Map.cellSize - 1, Map.cellSize do
			local tt = math.floor(math.random(2)) + 3
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
	
	-- generate and save the actors
	self:createActors(xpos, ypos, sx, sy)
	
	for _, t in pairs(actors) do		
		for _, a in ipairs(t) do
			self:saveActor(a)
		end
	end
	
	-- add random objects
	local current = 1
	local tree_cycle = { 'short_tree', 'tall_tree', 'pine_tree' }
	
	-- create a table to hold all of the objects
	for y = 1, sy do		
		objects[y] = {}
	end	
	
	local ts = self._tileSet:size()
	
	local hash, xcoord, ycoord = Map.hash(xpos,ypos)
	
	for y = Map.cellSize, sy - Map.cellSize do
		for x = Map.cellSize, sx - Map.cellSize do
			if math.random() > 0.99 and math.floor(tiles[1][y][x] / 18) == 5 then
					objects[y][x] = { name = tree_cycle[(current % 3) + 1], 
					x = xcoord * ts[1] + x * ts[1], y = ycoord * ts[1] + y * ts[2] }
				current = current + 1
			end
		end
	end
	
	self:splitIntoCells(xpos,ypos)

	--log.log('Finished creating map cells!')		
end

--
--  Split a terrain into cells
--
function TerrainGenerator:splitIntoCells(xpos, ypos)
	local hash, xcoord, ycoord = Map.hash(xpos,ypos)
	local tiles = self._tiles
	local objects = self._objects
	local actors = self._actors
	local sy = #tiles[1]
	local sx = #tiles[1][1]
	
	local cx = xcoord
	local cy = ycoord
	
	local cells = {}
	
	for y = 1, sy - 1, Map.cellSize do
		cx = xcoord
		for x = 1, sx - 1, Map.cellSize do
			--log.log('Creating map cell at coords: ' .. cx .. ', ' .. cy)
			
			local mc = {}
			mc._tiles = {}
			mc._actors = {}
			for i = 1, Map.layers do
				mc._tiles[i] = {}
			end
			for i = 1, Map.layers do
				for y = 1, Map.cellSize do
					mc._tiles[i][y] = {}
				end
			end
			mc._tiles[Map.layers+1] = {}
			
			for i = 1, Map.layers do
				for yy = y, y + Map.cellSize - 1 do
					for xx = x, x + Map.cellSize - 1 do
						mc._tiles[i][yy-y+1][xx-x+1] = tiles[i][yy][xx]
						if i == 1 and objects[yy][xx] then
							table.insert(mc._tiles[Map.layers+1], objects[yy][xx])
						end
					end
				end
			end
			
			local hash = Map.hash(cx,cy)
			mc._hash = hash
			
			if self._actors[hash] then
				for k, v in ipairs(actors[hash]) do
					mc._actors[#mc._actors + 1] = v._id
				end
			end

			cells[#cells+1] = mc
			cx = cx + Map.cellSize
		end
		cy = cy + Map.cellSize
	end 
		
	for k, v in ipairs(cells) do
		self:saveMapCell(v)
	end
end

--
--  Inserts an actor into the current actor hash table
--
function TerrainGenerator:addActor(actor, tileX, tileY)
	local ts = self._tileSet:size()
	actor:position(tileX * ts[1], tileY * ts[2])	
	actor:update(0)
	local hash = Map.hash(actor._boundary[1] / ts[1], actor._boundary[2] / ts[2])
	if not self._actors[hash] then
		self._actors[hash] = {}
	end
	table.insert(self._actors[hash], actor)
	
	--log.log('Added actor #' .. actor._id .. '# with hash #' .. hash .. '#')
end

--
--  Creates a teleporter
--
function TerrainGenerator:createTeleporter(sx, sy, dx, dy)
	local ts = self._tileSet:size()
	local teleporter = StaticActor.create('content/actors/teleporter.dat')
	teleporter:animation('default')
	teleporter:location(dx * ts[1], dy * ts[2])	
	self:addActor(teleporter, sx, sy)	
end

--
--  Create some actors
--
--	@TODO replace this with actual procedural generation
--
function TerrainGenerator:createActors(xpos, ypos, sx, sy)
	local numActors = 50
	
	local actors = {}

	for i = 1, numActors do		
		local actor = Actor.create('content/actors/slime.dat')
		actor:direction('down')
		actor:animation('stand')
		local tileX = math.floor(math.random() * (sx - 128)) + xpos + 64
		local tileY = math.floor(math.random() * (sy - 128)) + ypos + 64		
		self:addActor(actor, tileX, tileY)
	end	
	
	if xpos == 499904 then
		self:createTeleporter(500040, 500032, 500300, 500032)
	elseif xpos == 500160 then
		self:createTeleporter(500310, 500032, 500030, 500032)
	end
	
	local npc = NPC.create('content/actors/male_human.dat')
	npc._health = 2000
	npc._maxHealth = 2000
	npc:direction('down')
	npc:animation('stand')
	npc:name('Bilbo')
	self:addActor(npc, xpos + 120, ypos + 120)
	
	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc:name(), hero = self._heroName }
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end
	npc:addDialog(d)	

	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc:name(), hero = self._heroName }
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end
	npc:addDialog(d)	

	local dg = DialogGenerator{ 'content/dialogs/lost_item.dat' }
	local d = dg:dialog{ npc = npc:name(), hero = self._heroName }
	d.on_finish = function(self)
		self._npc:removeDialog(self)
	end
	npc:addDialog(d)	
	
	return actors
end

--
--  Saves a map cell to disk using fileio thread
--	
function TerrainGenerator:saveMapCell(mc)
	--log.log('Saving generated map cell: ' .. mc._hash)
	
	self._communicator:send('saveMapCell',mc._hash)
	local s = marshal.encode(mc._tiles)		
	self._communicator:send('saveMapCell',s)
	local s = marshal.encode(mc._actors)	
	self._communicator:send('saveMapCell',s)		
	
	--log.log('Saving generated map cell complete!')
end

--
--  Saves an actor to disk using fileio thread
--
function TerrainGenerator:saveActor(actor)
	local s = marshal.encode(actor)
	self._communicator:send('saveActor',actor._id)
	self._communicator:send('saveActor',s)
end