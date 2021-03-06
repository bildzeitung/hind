--[[
	factories.lua
	
	Created JUN-23-2012
]]

require 'terrain_generator'
require 'tileset'
require 'map'
require 'animation'
require 'camera'

module (..., package.seeall)

local actorID = 1000000
local fileTables = {}

--
--  Reads in a lua table from a file
--
function readTableFromFile(filename)
	-- we only want to call loadstring the
	-- first time a table is constructed as it is slow
	if fileTables[filename] then
		return table.clone(fileTables[filename], { deep = true, nometa = true })
	else
		local f = io.open(filename, 'r')
		if not f then 
			return nil, 'There was an error loading the table from filename "' 
				.. filename .. '" - the file did not open.'
		end
		local s = f:read('*all')
		f:close()
		
		local t = loadstring('return ' .. s)()
		
		if not t then
			return nil, 'There was an error loading the table from filename "' 
				.. filename .. '" - the file did not parse properly.'
		end
			
		if t._static then
			if not objects.static then
				objects.static = {}
			end
			objects.static = table.merge(objects.static, t._static)
			t._static = nil
		end	
			
		-- merge in base tables if they are 
		-- mentioned
		while t._baseTable do 
			local ot = readTableFromFile(t._baseTable)
			t._baseTable = nil
			t = table.merge(ot, t)			
		end
				
		fileTables[filename] = t
		
		return table.clone(t, { deep = true, nometa = true })
	end	
end

--
--  Returns a new tile set loaded
--	from the provided data file
--
function createTileset(filename)
	local t = readTableFromFile(filename)	
	
	for k, v in ipairs(t._images) do
		t._images[k]._image = love.image.newImageData(v._file)
	end
		
	local ts = tileset:new(t)	
	return ts	
end

--
--  Returns a new animation
--	from the provided table
--
--  Inputs:
--		table that describes the animation
--
function createAnimation(t)
	t._tileSet = tileSets[t._tileSet]
	local a = objects.Animation(t)
	return a
end

--
--  Returns a new map using the
--	provided tileset 
--
--  Inputs:
--		ts - the name of the tileset to use 
--			for this map
--
function createMap(ts)
	local t = {}	
	t._tileSet = tileSets[ts]	
	local m = objects.Map(t)
	return m	
end

--
--  Returns a new terrain generator using the
--	provided tileset
--
--  Inputs:
--		ts - the name of the tileset to use 
--			for this map
--
function createTerrainGenerator(ts)
	local t = {}	
	t._tileSet = tileSets[ts]	
	local m = objects.TerrainGenerator(t)
	return m	
end


--
--	Returns a table suitable for creating an actor
--
function prepareActor(filename, existing)
	local t = readTableFromFile(filename)
	
	for k, v in pairs(t._animations) do
		local a = createAnimation(v)
		t._animations[k] = a		
	end
	t._filename = filename
	
	if not existing or not existing._id then
		t._id = actorID
		actorID = actorID + 1	
	end
	
	if existing then
		t = table.merge(t, existing)
	end
	
	return t
end

--
--  Returns a new camera
--
function createCamera()
	local c = camera:new{}
	return c
end

--
--  Returns a floating text
--  
function createFloatingText(text, font, color, position, velocity, aliveTime, screenSpace)
	local ft = objects.FloatingText
		{ text, font, color, position, velocity, aliveTime, screenSpace }
	return ft
end