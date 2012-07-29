--[[
	main.lua
	
	Created JUN-21-2012
]]

require 'profiler'
require 'factories'
require 'renderer'
require 'floating_text'
require 'libraries.loveframes'
require 'dialog_generator'
require 'dialog_viewer'
require 'inventory_viewer'
require 'personality_viewer'
require 'world'
require 'NPC'

local HERO_DEAD = -99
local IN_GAME = 10

--collectgarbage('stop')
collectgarbage('setpause', 100)
collectgarbage('setstepmul', 400)

local Counters
local Names

function love.load()	
	fileiothread = love.thread.newThread('fileio', 'fileio.lua') 
	fileiothread:start()
	
	pathfindthread = love.thread.newThread('pathfind', 'pathfind.lua') 
	pathfindthread:start()	
	
	profiler = objects.Profiler{}	
	
	largeFont = love.graphics.newFont(24)
	smallFont = love.graphics.newFont(12)
	
	screenWidth = 1200
	screenHeight = 675
	local success = love.graphics.setMode( 
		screenWidth,screenHeight, false, false, 0 )		

	soundEffects = {}
	
	local load = { 
		'coin_pickup', 'sword_cut_1', 'sword_cut_2', 'sword_slash_1',
		'sword_slash_2', 'human_hurt_1', 'human_attack_1', 'human_attack_2', 
		'human_attack_3', 'human_attack_4'
	}
	
	for _, v in ipairs(load) do
		soundEffects[v] = 
			love.audio.newSource( 'content/sounds/' .. v .. '.wav', 'static' )
	end
	
	tileSets = {}
	
	local load = {
		'outdoor', 'male_human', 
		'chain_armour', 'chain_helmet', 'plate_shoes', 
		'plate_pants', 'longsword', 'monster', 'coins', 
		'magic_firelion', 'magic_iceshield', 'potions',
		'inventory_items', 'magic_torrent'
	}
		
	for _, v in ipairs(load) do
		local ts = factories.createTileset('content/tilesets/' .. v .. '.dat')
		tileSets[ts:name()] = ts
	end
	
	drawProfileText = true
	
	music = love.audio.newSource( 'content/sounds/theme.ogg', 'stream' )
	--music:setVolume(0.15)
	--music:setLooping( true )
	--music:play()	
	
	loveframes.config['DEBUG'] = false
	loveframes.util.SetActiveSkin('Hind')
	
	state = IN_GAME
	overlays = {}	
	
	world = objects.World{ profiler }
	world:initialize()
	world._hero.on_end_die = function(self, other)			
		state = HERO_DEAD
	end
end

function love.draw()
	love.graphics.setColor(255,255,255,255)
	
	if state == HERO_DEAD then		
		love.graphics.setFont(largeFont)
		love.graphics.print('GAME OVER', 300, 300)
		return
	end
	
	world:draw(profiler)
	
	-- draw profile text
	--profiler:profile('drawing profile text', function()
			love.graphics.setColor(255,255,255,255)	
			love.graphics.setFont(smallFont)
			love.graphics.print('FPS: '..love.timer.getFPS(), 10, 70)
			love.graphics.print('MEMORY IN USE '.. string.format('%.2f', collectgarbage('count')), 10, 85)			
			
			if drawProfileText then
				local y = 300
				local total = 0	
				love.graphics.print('===== PROFILES ======', 0, y)
				love.graphics.print('= C =', 275, y)
				love.graphics.print('= T =', 325, y)
				love.graphics.print('= M =', 425, y)
				y = y + 20
				
				local avgs = {}
				
				for k, v in pairs(profiler:profiles()) do
					avgs[#avgs+1] = { name = k, mem_avg = v.mem_sum / v.count, time_avg = v.time_sum / v.count, count = v.count }
				end
				
				--table.sort(avgs, function(a,b) return a.mem_avg > b.mem_avg end)
				table.sort(avgs, function(a,b) return a.name > b.name end)
				
				local x = 0
				for _, v in pairs(avgs) do
					--if v.time_avg > 0.00009 or v.mem_avg > 0.001 then
						love.graphics.print(v.name, x, y)				
						love.graphics.print(v.count, x + 275, y)				
						love.graphics.print(string.format('%.5f', v.time_avg),x + 325, y)		
						love.graphics.print(string.format('%.5f', v.mem_avg),x + 425, y)		
						y=y+15		
					--end
					total = total + v.time_avg
					
					if y > 640 then 
						y = 340
						x = x + 500
					end
				end	
				
				love.graphics.print('=== TOTAL AVG TIME ===', x, y)
				y=y+15
				love.graphics.print(string.format('%.5f', total), x, y)
				y=y+15
				love.graphics.print('=== EXPECTED FPS ===', x, y)
				y=y+15
				love.graphics.print(string.format('%.5f', 1/total), x, y)
			end
		--end) -- profile

	--profiler:profile('drawing loveframes', function()		
			loveframes.draw()
		--end) -- profile
end

function love.update(dt)
	if state == HERO_DEAD then		
		return
	end

	-- @TODO keyboard handling code is just crap with currently lots of
	-- junk for just testing purposes
	-- figure out how to design this and implement properly	
	--profiler:profile('handling keyboard input', function()
			if not world._hero._currentAction and table.count(overlays) == 0 then
				local vx, vy = 0, 0
				-- @ TODO put this into the actor definition file!!!!
				-- n.b. this is a good value for testing but makes the hero 
				-- walk very fast
				local speed = 125
				-- @ TODO put this into the actor definition file!!!!
				
				if love.keyboard.isDown('up') then
					world._hero:direction('up')
					world._hero:animation('walk')		
					vy = -speed
				elseif
					love.keyboard.isDown('down') then
					world._hero:direction('down')
					world._hero:animation('walk')		
					vy = speed
				end
				if love.keyboard.isDown('left') then
					world._hero:direction('left')
					world._hero:animation('walk')
					vx = -speed
				elseif
					love.keyboard.isDown('right') then
					world._hero:direction('right')
					world._hero:animation('walk')
					vx = speed
				end
				
				world._hero:velocity(vx, vy)
				
				if vx == 0 and vy == 0 then
					world._hero:animation('stand')
				end
				
				if love.keyboard.isDown('lctrl') then
					local closest, distance = world:closestActor(world._hero)
					if closest and closest.dialogs and distance < 100 and table.count(closest:dialogs()) > 0 then
						world._hero:velocity(0,0)
						world._hero:animation('stand' .. world._hero:direction(), true)
						local dialogViewer = objects.DialogViewer{ closest, world._hero }
						overlays[dialogViewer] = true
						dialogViewer.on_close = function(self)
							overlays[dialogViewer] = nil
						end
					else
						world._hero:action('attack')
					end
				end
				
				if love.keyboard.isDown('lshift') then	
					world._hero:action('spellcast')
				end		

				if love.keyboard.isDown('i') then
					world._hero:velocity(0,0)
					world._hero:animation('stand' .. world._hero:direction(), true)
					local inventoryViewer = objects.InventoryViewer{ world._hero }
					overlays[inventoryViewer] = true
					inventoryViewer.on_close = function(self)
						overlays[inventoryViewer] = nil
					end
				end		
				
				if love.keyboard.isDown('p') then
					world._hero:velocity(0,0)
					world._hero:animation('stand' .. world._hero:direction(), true)
					local personalityViewer = objects.PersonalityViewer{ world._hero }
					overlays[personalityViewer] = true
					personalityViewer.on_close = function(self)
						overlays[personalityViewer] = nil
					end
				end	
			end
			
			if love.keyboard.isDown('escape') then
				os.exit()
			end

			if love.keyboard.isDown('q') then
				world._zoom  = 1
			end
			
			if love.keyboard.isDown('w') then
				world._zoom  = 2
			end
			
			if love.keyboard.isDown('r') then
				world._zoom  = 4
			end		

			if love.keyboard.isDown('t') then
				world._zoom  = 0.5
			end		
			
			if love.keyboard.isDown('a') then
				world._zoom  = world._zoom  + 0.01
			end
			
			if love.keyboard.isDown('z') then
				world._zoom  = world._zoom  - 0.01
			end	
			
			if world._zoom < 0.1 then world._zoom  = 0.1 end
			
			if love.keyboard.isDown('h') then
				world._showCollisionBoundaries = true
			end		

			if love.keyboard.isDown('n') then
				world._showCollisionBoundaries = false
			end	
			
			if love.keyboard.isDown('=') then
				world._hero._currentSpell = world._hero._currentSpell + 1
				if world._hero._currentSpell > #world._hero._spells then
					world._hero._currentSpell = #world._hero._spells
				end
			end			

			if love.keyboard.isDown('-') then	
				world._hero._currentSpell = world._hero._currentSpell - 1
				if world._hero._currentSpell < 1 then
					world._hero._currentSpell = 1
				end
			end			
		
			--@TODO coordinate the shadow and light position
			-- with the light color for day / night effect
			-- each light could also generate it's own shadow
			-- redraw!!!!!!	
			if love.keyboard.isDown('1') then		
				world._renderer:shader('light')
				
				-- morning
				world._renderer:setDirectionalLight( { fallOff = 0.35 } )
				world._renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {1.7,1.4,1.1}, world = false }		
				for i = 2, world._renderer:maxLights() do
					world._renderer:setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end				
			end
			
			if love.keyboard.isDown('2') then		
				world._renderer:shader('light')
				
				-- midday
				world._renderer:setDirectionalLight( { fallOff = 0.35 } )
				world._renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {2.5,2.5,2.5}, world = false }		
				for i = 2, world._renderer:maxLights() do
					world._renderer:setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end			
			end
			
			if love.keyboard.isDown('3') then		
				world._renderer:shader('light')
				
				-- dusk
				world._renderer:setDirectionalLight( { fallOff = 0.35 } )
				world._renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {2.0,1.6,1.4}, world = false }		
				for i = 2, world._renderer:maxLights() do
					world._renderer:setSpotLight{ idx = i, pos = {0,0}, size = {0,0}, 
							angle = {0, 0}, lightColor = {0,0,0}, world = false }		
				end					
			end	
			
			if love.keyboard.isDown('4') then		
				world._renderer:shader('light')
				
				-- night
				world._renderer:setDirectionalLight( { fallOff = 0.35 } )
				world._renderer:setSpotLight{ idx = 1, pos = {400,300}, size = {1600,1200}, 
						angle = {-1, 7}, lightColor = {0.5,0.5,1.1}, world = false }
				-- random spot lights
				world._renderer:setSpotLight{ idx = 2, pos = {8000,8000}, size = {100,100}, 
						angle = {-1, 7}, lightColor = {3,3,3}, world = true }				
				world._renderer:setSpotLight{ idx = 3, pos = {7600,7600}, size = {75,75},
						angle = {-1, 7}, lightColor = {3,1,1}, world = true }
				world._renderer:setSpotLight{ idx = 4, pos = {8400,8400}, size = {400,400}, 
						angle = {1, 3}, lightColor = {0.5,0.5,2}, world = true }
				world._renderer:setSpotLight{ idx = 5, pos = {8500,7600}, size = {80,400}, 
						angle = {4,4.5}, lightColor = {2,2,2}, world = true }
						
				world._renderer:updateLightEffect(world._camera)
			end		
				
			if love.keyboard.isDown('o') then
				world._renderer:shader(nil)
			end
			
			if love.keyboard.isDown(',') then		
				profiler:reset()
			end	
		--end) -- profile
		
	world:update(dt, profiler)
	
	--profiler:profile('updating loveframes', function()
			loveframes.update(dt)
		--end) -- profile
end

function love.mousepressed(x, y, button)
	loveframes.mousepressed(x, y, button)

	for overlay, _ in pairs(overlays) do
		if overlay.mousepressed then
			overlay:mousepressed(x, y ,button)
		end	
	end
end

function love.mousereleased(x, y, button)
	loveframes.mousereleased(x, y, button)

	for overlay, _ in pairs(overlays) do
		if overlay.mousereleased then
			overlay:mousereleased(x, y ,button)
		end	
	end
end

function love.keypressed(key, unicode)
	loveframes.keypressed(key, unicode)

	for overlay, _ in pairs(overlays) do
		if overlay.keypressed then
			overlay:keypressed(key, unicode)
		end	
	end
end

function love.keyreleased(key)
	loveframes.keyreleased(key)
	
	for overlay, _ in pairs(overlays) do
		if overlay.keyreleased then
			overlay:keyreleased(key)
		end	
	end
	
	if key == '[' then		
		world._drawInfoText = not world._drawInfoText
	end		
			
	if key == 'e' then
		drawProfileText = not drawProfileText
	end	
	
	if key == 'd' then
		local function hook ()
		  local f = debug.getinfo(2, 'f').func
		  if Counters[f] == nil then    
			Counters[f] = 1
			Names[f] = debug.getinfo(2, 'Sn')
		  else  
			Counters[f] = Counters[f] + 1
		  end
		end

		local function getname (func)
		  local n = Names[func]
		  if n.what == "C" then
			return n.name
		  end
		  local loc = string.format("[%s]:%s", n.short_src, n.linedefined)
		  if n.namewhat ~= "" then
			return string.format("%s (%s)", loc, n.name)
		  else
			return string.format("%s", loc)
		  end
		end				
		
		if not debugMode then
			debugMode = true
			Counters = {}
			Names = {}									
			debug.sethook(hook, 'c')
		else		
			debugMode = false
			debug.sethook()  
			for func, count in pairs(Counters) do
				if count > 1000 then
					local msg = tostring(getname(func)) .. ' : ' .. count
					log.log(msg)
				end
			end	
		end	
	end
end