local Macros = require("lib.GNMacros")
local Ship = require("lib.Ship")
local RigidBody = require("lib.RigidBody")


local CONTROLS = {
	forward = keybinds:fromVanilla("key.forward"),
	backward = keybinds:fromVanilla("key.back"),
	left = keybinds:fromVanilla("key.left"),
	right = keybinds:fromVanilla("key.right")
}

for key, value in pairs(CONTROLS) do
	value.press = function (modifiers, self)
		return true
	end
end


return Macros.new(function (events, ...)
	local body = RigidBody.new()
	
	body:setPos(0,20,0)
	body.model = SHIP.model
	
	events.ON_EXIT:register(function ()
		
	end)
end)