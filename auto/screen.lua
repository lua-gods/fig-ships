
---@type table<string,GN.Macro>
local SCREENS = {}

for index, path in ipairs(listFiles("auto.screens")) do
	local name = path:match("%.(%w+)$")
	local macro = require(path)
	SCREENS[name] = macro
end

local currentScreen
function setScreen(name)
	if currentScreen then
		currentScreen:setActive(false)
	end
	local screen = SCREENS[name]
	if screen then
		screen:setActive(true)
	end
	currentScreen = screen
end

setScreen("builder")