--[[
	dialog_viewer.lua
	
	Created JUL-16-2012
	
	This object will be responsible for creating the view of a dialog
	that the player will interact with, including handling input and output.
]]

local Object = (require 'object').Object

require 'libraries.loveframes'
local loveframes = loveframes

local log = require 'log'

local table, next, pairs, ipairs, type, love
	= table, next, pairs, ipairs, type, love
	
module('objects')

DialogViewer = Object{ _init = { '_npc' } }

-- only need one of these
DialogViewer._nameFont = love.graphics.newFont(14)

--
--  DialogViewer constructor
--
function DialogViewer:_clone(values)
	local o = Object._clone(self,values)

	o.DIALOGVIEWER = true

	o._currentDialog = nil
	o._currentOption = nil
	o._availableOptions = nil
	
	o._elements = {}
	
	o._elements['npcFrame'] = loveframes.Create('frame')
	o._elements['npcFrame']:SetSize(500, 300)
	o._elements['npcFrame']:SetPos(10,10)
	o._elements['npcFrame']:ShowCloseButton(false)
	o._elements['npcFrame']:SetDraggable(false)

	o._elements['npcName'] = loveframes.Create('text')
	o._elements['npcName']:SetParent(o._elements['npcFrame'])
	o._elements['npcName']:SetPos(10,10)
	o._elements['npcName']:SetFont(self._nameFont)

	o._elements['npcText'] = loveframes.Create('text')
	o._elements['npcText']:SetParent(o._elements['npcFrame'])
	o._elements['npcText']:SetPos(10,30)
	o._elements['npcText']:SetMaxWidth(480)

	o._elements['heroFrame'] = loveframes.Create('frame')
	o._elements['heroFrame']:SetSize(500, 300)
	o._elements['heroFrame']:SetPos(690,360)
	o._elements['heroFrame']:ShowCloseButton(false)
	o._elements['heroFrame']:SetDraggable(false)
	
	o._elements['heroName'] = loveframes.Create('text')
	o._elements['heroName']:SetParent(o._elements['heroFrame'])
	o._elements['heroName']:SetPos(10,10)
	o._elements['heroName']:SetFont(self._nameFont)

	o._elements['heroTexts'] = {}
	for i = 1, 6 do
		o._elements['heroTexts'][i] = loveframes.Create('text')
		o._elements['heroTexts'][i]:SetParent(o._elements['heroFrame'])
		o._elements['heroTexts'][i]:SetPos(10,30 + (i-1) * 40)
		o._elements['heroTexts'][i]:SetMaxWidth(480)
	end	
	
	local dialogs = o._npc:dialogs()
	local k, dialog = next(dialogs)
	
	if table.count(dialogs) > 1 then
		o._currentOption = 1
		o._optionCount = table.count(dialogs)
		o._availableOptions = {}
		for i = 1, o._optionCount do
			o._availableOptions[i] = true
		end		
	else
		o:selectDialog(k)
	end
	
	if o._elements['npcName']:GetVisible() then
		o._elements['npcName']:SetText{{255, 255, 0, 255}, dialog._npc:name()}
		o._elements['heroName']:SetText{{255, 255, 0, 255},dialog._hero:name()}
		o:updateNPCFrame()
		o:updateHeroFrame()
	end
	
	return o
end

--
--  Selects a dialog 
--
function DialogViewer:selectDialog(k)
	self._currentDialog = self._npc:dialogs()[k]
	local branch = self._currentDialog:branch()		
	
	if not branch then
		self:close()
		return
	end
	
	self:prepareAvailableOptions()
end

--
--  Creates the npc frame for this dialog
--
function DialogViewer:updateNPCFrame()
	if self._currentDialog then
		local branch = self._currentDialog:branch()		
		local text = branch.text
		if text then
			if text:find(self._npc:name() .. '%-%>') then
				text = text:gsub(self._npc:name() .. '%-%>','')
				self._elements['npcText']:SetText{{255,255,255,255},text}
			end	
		end
	else
		self._elements['npcText']:SetText{{255,255,255,255},'What would you like to talk about?'}
	end
end

--
--  Prepares the option list to see which ones are available
--
function DialogViewer:prepareAvailableOptions()
	self._availableOptions = {}
	self._currentOption = nil
	
	local branch = self._currentDialog:branch()
	if not branch then
		self:close()
		return
	end
	
	if branch.options then
		self._optionCount = #branch.options
		for k, v in ipairs(branch.options) do
			local available = true
			if v.available then
				if not v.available(self._currentDialog) then			
					available = false
				end
			end	
			if available then
				self._availableOptions[k] = true
				if not self._currentOption then 
					self._currentOption = k
				end
			end
		end
	end
end

--
--  Converts a text string to a colour indexed table
--
function DialogViewer:colourText(text, defaultColour)
	local textChunks = text:split('%%')
	
	local txt = {}
	
	for k, v in ipairs(textChunks) do
		if k == 1 then
			txt[#txt+1] = defaultColour
		else
			txt[#txt+1] = {0,255,255,255}
		end
		txt[#txt+1] = v			
	end
	
	return txt
end

--
--  Creates the hero frame for this dialog
--
function DialogViewer:updateHeroFrame()
	-- blank possibly non used options
	for i = 2, #self._elements['heroTexts'] do
		self._elements['heroTexts'][i]:SetText(' ')
	end
	
	if self._currentDialog then		
		local branch = self._currentDialog:branch()
		if branch.options then	
			for k, v in ipairs(branch.options) do
				if self._availableOptions[k] then
					local text = v.text:gsub(self._currentDialog._hero:name() .. '%-%>','')
					if k == self._currentOption then
						self._elements['heroTexts'][k]:SetText(self:colourText(text,{255,0,0,255}))
					else
						self._elements['heroTexts'][k]:SetText(self:colourText(text,{255,255,255,255}))
					end
				end
			end
		else
			local text = branch.text
			if text:find(self._currentDialog._hero:name() .. '%-%>') then	
				text = text:gsub(self._currentDialog._hero:name() .. '%-%>','')
				self._elements['heroTexts'][1]:SetText(self:colourText(text,{255,255,255,255}))
			end			
		end
	else
		local txt = 1
		for k, v in pairs(self._npc:dialogs()) do
			if txt == self._currentOption then
				self._selectedDialog = k
				self._elements['heroTexts'][txt]:SetText(self:colourText(k,{255,0,0,255}))
			else
				self._elements['heroTexts'][txt]:SetText(self:colourText(k, {255,255,255,255}))
			end
			txt = txt + 1
		end	
	end
end

-- 
--  Closes the DialogViewer
-- 
function DialogViewer:close()
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
function DialogViewer:keypressed(key, unicode)
	if key == 'x' then
		self:close()
	end
	
	if key == 'lctrl' then
		if self._currentDialog then
			if self._currentOption then
				local branch = self._currentDialog:branch()
				local text = self:colourText(branch.options[self._currentOption].text, {255,0,0,255})
				self._elements['heroTexts'][1]:SetText(text)	
			end
			self._currentDialog:viewed(self._currentOption)	
			
			self:prepareAvailableOptions()
		else
			self:selectDialog(self._selectedDialog)
			self._elements['heroTexts'][1]:SetText(' ')			
		end				
	end
	
	local oldOption = self._currentOption	
	if key == 'up' then
		if self._currentOption then
			repeat
				self._currentOption = self._currentOption - 1
				if self._currentOption < 1 then
					self._currentOption = oldOption
					break
				end
			until self._availableOptions[self._currentOption]
		end
	end
	
	if key == 'down' then
		if self._currentOption then
			repeat
				self._currentOption = self._currentOption + 1
				if self._currentOption > self._optionCount then
					self._currentOption = oldOption
					break
				end
			until self._availableOptions[self._currentOption]
		end
	end

	if self._elements['npcFrame']:GetVisible() then
		self:updateNPCFrame()
		self:updateHeroFrame()	
	end
end