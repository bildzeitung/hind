--[[
	personality_viewer.lua
	
	Created JUL-18-2012
	
	This object will be responsible visually outputting a hero's personality
	traits and allowing the player to interact with them (how?)
]]

local Object = (require 'object').Object

require 'libraries.loveframes'
local loveframes = loveframes

local log = require 'log'

local table, next, pairs, ipairs, type, love, string
	= table, next, pairs, ipairs, type, love, string
	
module('objects')

PersonalityViewer = Object{ _init = { '_hero' } }

-- only need one of these
PersonalityViewer._headingFont = love.graphics.newFont(14)
PersonalityViewer._barImage = love.graphics.newImage('content/images/ui/personalitybar.png')
PersonalityViewer._selectorImage = love.graphics.newImage('content/images/ui/personalityselector.png')

--
--  PersonalityViewer constructor
--
function PersonalityViewer:_clone(values)
	local o = Object._clone(self,values)

	o.PERSONALITYVIEWER = true
	
	o._elements = {}
	
	o._elements['frame'] = loveframes.Create('frame')
	o._elements['frame']:SetSize(800, 600)
	o._elements['frame']:SetPos(400,0)
	o._elements['frame']:SetDraggable(false)	
	o._elements['frame'].OnClose = function()
		o:close()
	end
	
	o._elements['items'] = {}

	o:updatePersonalityFrame()
	
	return o
end

-- 
--  Updates the personality frame
-- 
function PersonalityViewer:updatePersonalityFrame()
	for k, v in ipairs(self._elements['items']) do
		v:Remove()
		self._elements['items'][k] = nil
	end
	
	local y = 20
	local x = 150
	for k, v in pairs(self._hero._personality) do
		local ls = loveframes.Create('text')
		ls:SetText{{255,0,0,255}, v[1]}
		ls:SetParent(self._elements['frame'])
		ls:SetFont(PersonalityViewer._headingFont)	
		local w = PersonalityViewer._headingFont:getWidth(v[1])
		ls:SetPos(x - 75 - (w / 2), y + 30)		
		
		local rs = loveframes.Create('text')
		rs:SetText{{29,95,246,255}, v[2]}
		rs:SetParent(self._elements['frame'])
		rs:SetFont(PersonalityViewer._headingFont)			
		local w = PersonalityViewer._headingFont:getWidth(v[2])
		rs:SetPos(x + 75 - (w / 2), y + 30)		
		
		local pb = loveframes.Create('progressbar')
		pb:SetParent(self._elements['frame'])
		pb:SetSize(200, 15)
		pb:SetLerp(false)
		pb:SetMinMax(-1000,1000)
		pb:SetValue(self._hero[k](self._hero))
		pb:SetPos(x - pb:GetWidth() / 2, y)
		
		pb.Draw = function(self)
			love.graphics.setColor(255,255,255,255)
			love.graphics.draw(PersonalityViewer._barImage, self:GetX(), self:GetY())
			love.graphics.draw(PersonalityViewer._selectorImage, self:GetX() + self.progress - 12, self:GetY())			
		end
		
		x = x + 250
		if x > 800 then 
			x = 150
			y = y + 60
		end
				
		--table.insert(self._elements['texts'], t)
		table.insert(self._elements['items'], ls)
		table.insert(self._elements['items'], rs)
		table.insert(self._elements['items'], pb)
		
	end
end

-- 
--  Closes the PersonalityViewer
-- 
function PersonalityViewer:close()
	for k, v in pairs(self._elements) do
		if not v.Remove then
			for k2, v2 in pairs(v) do
				v2:Remove()
			end
		else
			v:Remove()
		end
	end	

	if self.on_close then self:on_close() end
end

--
--  Called when a key is pressed
--
function PersonalityViewer:keypressed(key, unicode)
	if key == 'x' then
		self:close()
	end
end