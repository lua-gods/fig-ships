--[[______   __
  / ____/ | / / Name: GN SYNC LIBRARY v0.1.1 BETA
 / / __/  |/ /  Desc: automatically syncs data using pings aggressively
/ /_/ / /|  / Author: GNanimates | https://gnon.top | @gn68s
\____/_/ |_/ License: Mozilla Public License Version 2.0 
you have an early copy of my library!
]]

--────────────────────────-< DEPENDENCIES >-────────────────────────--

local Event = require("lib.GNEvent")
--TODO: add support for chunked package sending for super long string pings.
--TODO: add support for voiding keys
--────────────────────────-< CONFIG >-────────────────────────--

-- [DEFAULT : false] whether to use sync data instead of the real data for the host.
local USE_SYNC_DATA_ON_HOST = false

-- [DEFAULT : 924] the maximum ping size you have per second, default value is maximum possible
local MAX_SIZE_LIMIT = 1024 - 100

-- [DEFAULT : 5] the maximum amount of pings per second, default value is maximum possible
local MAX_COUNT_LIMIT = 5

-- [DEFAULT : 0.5] the timer to slow the syncer down in seconds, 0 for fast asf boi
local PASSIVE_TIMER_INTERVAL = 0.5

-- [DEFAULT : 10] the maximum amount of items a batch can have
local MAX_ITEMS_PER_BATCH = 10

-- [DEFAULT : toJson] function that compresses data into a string from a table
local PACKER = toJson

-- [DEFAULT : parseJson] function that decompresses data from a string to a table
local UNPACKER = parseJson

-- function that tells how many bytes a string has as a ping.
local PING_SIZE_CHECKER = function(string)
	return #string
end

-- whether to sync the data using the player armor slots.
-- NOTES:
-- * this will use your offhand to sync data, meaning you are unable to use your offhand.
-- * this only works with OP and creative mode
-- * this WILL increase your ping and everyone around you
local WEAPONIZE_OFFHAND = false

-- CONFIG OVERRIDES
if WEAPONIZE_OFFHAND then
	USE_SYNC_DATA_ON_HOST = true

	MAX_SIZE_LIMIT = 65535 - 100

	MAX_COUNT_LIMIT = 10000
	MAX_ITEMS_PER_BATCH = 200

	PASSIVE_TIMER_INTERVAL = 0.05
end

--────────-< Debug Options >-────────--

-- shows the data that is being synced beside the player
local DEBUG_SHOW_DATA = false

--────────────────────────-< END OF CONFIG >-────────────────────────--

-- optimization to only make this option only work for the host.
USE_SYNC_DATA_ON_HOST = USE_SYNC_DATA_ON_HOST and host:isHost()

---@type table<string,any>|{changes:table<any,GN.Event>}
local syncInterface = {}  --- proxy table interface
local eventInterface = {} --- proxy table interface for events

local realData = {}
local syncData = {} -- actual data
local syncEvents = {} ---@type table<string,GN.Event>

syncInterface.changes = eventInterface


local function appendPackage(package)
	local payload = UNPACKER(package)
	for key, value in pairs(payload) do
		if syncData[key] ~= value then
			syncData[key] = value
			if not syncEvents[key] then
				syncEvents[key] = Event.new()
			end
			if USE_SYNC_DATA_ON_HOST or (not host:isHost()) then
				syncEvents[key]:invoke(value)
			end
		end
	end
end


function pings.syncPayload(package)
	appendPackage(package)
end

if DEBUG_SHOW_DATA then
	local SCALE = 0.25

	local label = models:newPart("panel")
		 :newText("")

		 :scale(SCALE, SCALE, SCALE)
		 :setBackground(true)

	events.WORLD_RENDER:register(function(delta)
		local text = printTable(syncData, 9, true)

		local lineCount = 1
		if text then
			text:gsub("\n", function()
				lineCount = lineCount + 1
				return "\n"
			end)
		end

		label
			 :setText(text)
			 :setPos(-10, lineCount * 10 * SCALE, 0)
	end)
end



setmetatable(syncInterface, {
	__index = function(t, key)
		key = tostring(key)
		-- create a new listener if it doesn't exist.
		if key == "changes" then
			return eventInterface[key]
		end
		if USE_SYNC_DATA_ON_HOST then
			return syncData[key]
		else
			return realData[key] or syncData[key] --NOTE: dont remove the fallback, its used by remote views
		end
	end,
	__newindex = function(t, key, value)
		key = tostring(key)
		assert(key ~= "changes", "Attempted to delete event listeners")
		if realData[key] ~= value then
			realData[key] = value
			if not USE_SYNC_DATA_ON_HOST then
				if not syncEvents[key] then
					syncEvents[key] = Event.new()
				end
				syncEvents[key]:invoke(value)
			end
		end
	end,
})


setmetatable(eventInterface, {
	__index = function(t, key)
		if not syncEvents[key] then
			syncEvents[key] = Event.new()
		end
		return syncEvents[key]
	end,
	__newindex = function(t, key, value)
		if not syncEvents[key] then
			syncEvents[key] = Event.new()
		end
	end,
})

if WEAPONIZE_OFFHAND then
	events.WORLD_RENDER:register(function(delta)
		if player:isLoaded() then
			local item = player:getItem(2)
			if item and item.tag and item.tag and item.tag ~= "" then
				if item.tag.BlockEntityTag then
					appendPackage(item.tag.BlockEntityTag.Command)
				elseif item.tag["minecraft:custom_data"] then
					appendPackage(item.tag["minecraft:custom_data"].BlockEntityTag.Command)
				end
			end
		end
	end)
end

if not host:isHost() then return syncInterface end
--────────────────────────-< Host only >-────────────────────────--

local availableSize = MAX_SIZE_LIMIT
local availableCount = MAX_COUNT_LIMIT

local passiveTimer = 0

local payload = {}
local flip = false
local function sendPayload()
	availableSize = availableSize - #payload
	availableCount = availableCount - 1
	local package = PACKER(payload)
	payload = {}
	if WEAPONIZE_OFFHAND then
		flip = not flip
		host:setSlot(9,
			(flip and "command_block" or "chain_command_block") ..
			"{BlockEntityTag:{Command:" .. toJson(package) .. "}}")
	else
		pings.syncPayload(package)
	end
	passiveTimer = PASSIVE_TIMER_INTERVAL
end




local index
local lastTime = client:getSystemTime()
events.WORLD_RENDER:register(function()
	local time = client:getSystemTime()
	local delta = (time - lastTime) / 1000

	availableSize = math.min(availableSize + delta * MAX_SIZE_LIMIT, MAX_SIZE_LIMIT)
	availableCount = math.min(availableCount + delta * MAX_COUNT_LIMIT, MAX_COUNT_LIMIT)
	lastTime = time
	passiveTimer = passiveTimer - delta
	if passiveTimer > 0 then return end
	passiveTimer = PASSIVE_TIMER_INTERVAL

	for i = 1, MAX_ITEMS_PER_BATCH, 1 do
		if availableCount > 1 then
			index = next(realData, index)
			if index then
				local value = realData[index]
				payload[index] = value
				local package = toJson(payload)
				if PING_SIZE_CHECKER(package) > availableSize then
					payload[index] = nil -- temporarily remove it as it is too big
					sendPayload()
					payload[index] = value
					return
				end
			else -- reached the end
				if not WEAPONIZE_OFFHAND then
					sendPayload()
				end
				return
			end
			if not WEAPONIZE_OFFHAND then
				sendPayload()
			end
		else
			return
		end
	end
end)

return syncInterface
