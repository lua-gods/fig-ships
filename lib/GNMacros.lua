---@diagnostic disable: undefined-field
--[[______   __
  / ____/ | / / Name: GN MACROS LIBRARY v1.2.0
 / / __/  |/ /  Desc: encapsulates events and initialization into a togglable macro.
/ /_/ / /|  / Author: GNanimates | https://gnon.top | @gn68s
\____/_/ |_/ License: Mozilla Public License Version 2.0
--────────-< DEPENDENCIES >-────────--
Place required dependencies in the same folder as this script.
- GNEvent > https://discord.com/channels/1129805506354085959/1492967289312641095
]]

---@class MacroAPI
local MacrosAPI = {}


local Event = require("./GNEvent")


local randomID = function()
	return client.intUUIDToString(client.generateUUID())
end

---@class GN.Macro
---@field isActive boolean
---@field events MacroEventsAPI
---@field id string
---@field package init fun(events: MacroEventsAPI,...):any?
local Macro = {}
Macro.__index = Macro


---@class MacroEventsAPI : EventsAPI
---@field ON_EXIT Event
---@field ON_ENTITY_UNLOAD Event
---@field ON_ENTITY_LOAD Event
local MacroEventsAPI = {}

---Enables / Disables the macro
---@param active boolean
---@param ... any
---@return ...
function Macro:setActive(active, ...)
	if self.isActive ~= active then
		self.isActive = active
		if active then
			self.events = setmetatable({
				id = self.id,
				ENTITY_INIT = Event.new(),
				ON_EXIT = Event.new(),
				ON_ENTITY_UNLOAD = Event.new(),
				ON_ENTITY_LOAD = Event.new(),
			}, MacroEventsAPI)
			local out = self.init(self.events, ...)
			
			--TODO: ENTITY INIT SHOULD BE IN METATABLE INDEX INSTEAD OF MACRO INIT
			local hasInit = false
			local hasLoadEvent = false
			for name, value in pairs(self.events) do
				if name == "ENTITY_INIT" then
					hasInit = true
				end
				if name == "ON_ENTITY_LOAD" or name == "ON_ENTITY_UNLOAD" then
					hasLoadEvent = true
				end
			end

			if player:isLoaded() then
				self.events.ENTITY_INIT:invoke()
			else
				if hasInit then
					local initName = self.id .. "init"
					self.initName = initName
					events.TICK:register(function()
						self.events.ENTITY_INIT:invoke()
						events.TICK:remove(initName)
					end, initName)
				end
			end
			local wasLoaded = 5
			if hasLoadEvent then
				events.WORLD_TICK:register(function()
					local isLoaded = player:isLoaded()
					if isLoaded ~= wasLoaded then
						wasLoaded = isLoaded
						if isLoaded then
							self.events.ON_ENTITY_LOAD:invoke()
						else
							self.events.ON_ENTITY_UNLOAD:invoke()
						end
					end
				end)
			end
			return out
		else
			for name in pairs(self.events) do
				if events[name]then
					events[name]:remove(self.id)
				end
				if self.initName then
					events.TICK:remove(self.initName)
				end
			end
			self.events.ON_EXIT:invoke(...)
		end
	end
end

---@param init fun(events: MacroEventsAPI,...):any?
---@return GN.Macro
function MacrosAPI.new(init)
	assert(type(init) == "function", "Macro.init must be a function")
	local new = {
		init = init,
		isActive = false,
		id = randomID(),
		events = {},
	}
	return setmetatable(new, Macro)
end

MacroEventsAPI.__index = function(t, name)
	if not rawget(t, name) then
		local signal = Event.new()
		rawset(t, name, signal)
		if name ~= "ENTITY_INIT" then
			events[name]:register(function(...)
				local out = signal:invoke(...)[1] or {}
				return table.unpack(out)
			end, rawget(t,"id"))
		end
		--if v and type(v) == "function" then signal:register(v) end
	end
	return rawget(t, name)
end


return MacrosAPI
