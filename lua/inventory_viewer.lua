--[[
	inventory_viewer.lua
	
	Created JUL-18-2012
	
	This object will be responsible visually outputting a hero's inventory
	and allowing the player to interact with the inventory
]]

local Object = (require 'object').Object

require 'libraries.loveframes'
local loveframes = loveframes

local log = require 'log'

local table, next, pairs, ipairs, type, love
	= table, next, pairs, ipairs, type, love
	
module('objects')

InventoryViewer = Object{ _init = { '_hero' } }

-- only need one of these
InventoryViewer._countFont = love.graphics.newFont(16)

local equipPos =
{
	weapon = { 50, 100 },
	offHand = { 150, 100 },
	hands = { 125, 100 },
	head = { 125, 50 },
	belt = { 125, 150 },	
	torso = { 125, 100 },
	legs = { 125, 200 },
	feet = { 125, 250 },
	ring1 = { 10, 240 },
	ring2 = { 150, 240 },
	necklace = { 200, 10 }
}

--
--  InventoryViewer constructor
--
function InventoryViewer:_clone(values)
	local o = Object._clone(self,values)

	o.INVENTORYVIEWER = true
	
	o._elements = {}
	
	o._elements['frame'] = loveframes.Create('frame')
	o._elements['frame']:SetSize(500, 650)
	o._elements['frame']:SetPos(700,0)
	o._elements['frame']:SetDraggable(false)	
	o._elements['frame'].OnClose = function()
		o:close()
	end
	
	o._elements['inventoryFrame'] = loveframes.Create('panel')
	o._elements['inventoryFrame']:SetParent(o._elements['frame'])
	o._elements['inventoryFrame']:SetSize(480,260)
	o._elements['inventoryFrame']:SetPos(10,360)
	
	o._elements['equippedFrame'] = loveframes.Create('panel')
	o._elements['equippedFrame']:SetParent(o._elements['frame'])
	o._elements['equippedFrame']:SetSize(250,300)
	o._elements['equippedFrame']:SetPos(200,10)	
	
	o._elements['equippedImages'] = {}
	o._elements['equippedTooltips'] = {}
	o._elements['inventoryImages'] = {}
	o._elements['inventoryTooltips'] = {}
	o._elements['inventoryTexts'] = {}
	
	o:updateEquippedFrame()	
	o:updateInventoryFrame()
	
	return o
end

--
--  Returns the inventory appropriate image for an item
--
function itemImage(item)
	local anim = item._animations['inventory']
	if not anim then
		local animName = item._currentAnimation:name():gsub('game','') .. 'inventory'
		anim = item._animations[animName]
	end	
	if not anim then
		anim = item._currentAnimation
	end
	local frame = anim:frame()	
	local ts = anim:tileSet()
	local tq = ts:quads()
	return tq[frame]
end

--
--  Creates an image with a tooltip
--  
function createImageForItem(item)
	local itemImage = itemImage(item)		
	local image = loveframes.Create('imagebutton')
	image:SetImage(itemImage)
	image:SizeToImage()
	image:SetText('')
	local tooltip = loveframes.Create('tooltip')
	tooltip:SetObject(image)
	tooltip:SetPadding(2)
	tooltip:SetText{{255,255,255,255},item:description()}
	
	return image, tooltip
end

-- 
--  Updates the equipped frame
-- 
function InventoryViewer:updateEquippedFrame()
	for k, v in ipairs(self._elements['equippedImages']) do
		v:Remove()
		self._elements['equippedImages'][k] = nil
	end
	for k, v in ipairs(self._elements['equippedTooltips']) do
		v:Remove()
		self._elements['equippedTooltips'][k] = nil
	end
	
	for k, v in pairs(self._hero:equipped()) do
		local i, t = createImageForItem(v)
		i:SetParent(self._elements['equippedFrame'])			
		local pos = equipPos[k]
		i:SetPos(pos[1] - i:GetWidth()/2, pos[2] - i:GetHeight()/2)
		i.OnClick = function()			
			if self._hero:addItem(v) then
				self._hero:unequipItem(k)
				self:updateEquippedFrame()
				self:updateInventoryFrame()
			end
		end
		
		table.insert(self._elements['equippedImages'], i)
		table.insert(self._elements['equippedTooltips'], t)
	end
end

-- 
--  Updates the inventory frame
-- 
function InventoryViewer:updateInventoryFrame()
	for k, v in ipairs(self._elements['inventoryImages']) do
		v:Remove()
		self._elements['inventoryImages'][k] = nil
	end
	for k, v in ipairs(self._elements['inventoryTooltips']) do
		v:Remove()
		self._elements['inventoryTooltips'][k] = nil
	end
	for k, v in ipairs(self._elements['inventoryTexts']) do
		v:Remove()
		self._elements['inventoryTexts'][k] = nil
	end	
	
	local x, y = 24, 24
	for k, v in pairs(self._hero:inventory()) do
		local i, t = createImageForItem(v)
		i:SetParent(self._elements['inventoryFrame'])			
		local pos = equipPos[k]
		i:SetPos(x - i:GetWidth()/2, y - i:GetHeight()/2)

		i.OnClick = function()			
			-- equip item?
			if v._slot then
				if self._hero:equipItem(v._slot, v) then
					self._hero:removeItem(v)
					self:updateEquippedFrame()
					self:updateInventoryFrame()
				end
			-- use item?
			elseif v.use then
				if v:use(self._hero) then
					self:updateEquippedFrame()
					self:updateInventoryFrame()
				end
			end
		end
		
		table.insert(self._elements['inventoryImages'], i)
		table.insert(self._elements['inventoryTooltips'], t)

		-- show the number of items in the stack
		if v:stackable() then
			local count = v:count()
			local font = InventoryViewer._countFont
			local text = loveframes.Create('text')
			text:SetParent(self._elements['inventoryFrame'])
			text:SetText{{0,255,255,255},v:count()}
			text:SetPos(x + 16 - font:getWidth(count),
				y + 16 - font:getHeight(count))
			text:SetFont(font)
			
			table.insert(self._elements['inventoryTooltips'], text)
		end
		x = x + 40
		if x > self._elements['inventoryFrame']:GetWidth() - 32 then
			x = 16
			y = y + 40
		end
	end
end

-- 
--  Closes the InventoryViewer
-- 
function InventoryViewer:close()
	for k, v in pairs(self._elements) do
		if not v.Remove then
			for k2, v2 in pairs(v) do
				v2:Remove()
				v[k2] = nil
			end
		else
			v:Remove()
			self._elements[k] = nil
		end
	end	

	if self.on_close then self:on_close() end
end

--
--  Called when a key is pressed
--
function InventoryViewer:keypressed(key, unicode)
	if key == 'x' then
		self:close()
	end
end