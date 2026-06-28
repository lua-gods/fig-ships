local Ship = require("lib.Ship")

SHIP = Ship.new() -- active ship used for the host

---@type table<string,GN.Macro>
local SCREENS = {}

for index, path in ipairs(listFiles("auto.host.screens")) do
	local name = path:match("%.(%w+)$")
	local macro = require(path)
	SCREENS[name] = macro
end

local currentScreen
function setScreen(name)
	local screen = SCREENS[name]
	if screen ~= currentScreen then
		if currentScreen then
			currentScreen:setActive(false)
		end
		if screen then
			screen:setActive(true)
		end
		currentScreen = screen
	end
end

setScreen("builder")
