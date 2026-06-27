local Macros = require("lib.GNMacros")
local Ship = require("lib.Ship")
local RigidBody = require("lib.RigidBody")
local PanCamera = require("lib.PanCamera")

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

local YOUR_MOM = math.huge

return Macros.new(function (events, ...)
	host.unlockCursor = true
	renderer:renderRightArm(false)
		renderer:renderLeftArm(false)
	local body = RigidBody.new()
	
	local points = {}
	local i = 0
	local min = vec(YOUR_MOM, YOUR_MOM, YOUR_MOM)
	local max = vec(-YOUR_MOM, -YOUR_MOM, -YOUR_MOM)
	for index, aabb in ipairs(SHIP.hitbox) do
		for z = aabb[1].z, aabb[2].z, 8 do
			for y = aabb[1].y, aabb[2].y, 8 do
				for x = aabb[1].x, aabb[2].x, 8 do
					i = i + 1
					local pos = vec(x,y,z)
					points[i] = pos
					min = vec(math.min(min.x, pos.x), math.min(min.y, pos.y), math.min(min.z, pos.z))
					max = vec(math.max(max.x, pos.x), math.max(max.y, pos.y), math.max(max.z, pos.z))
				end
			end
		end
	end
	body.size = (max - min)
	body.points = points
	body:setPos(player:getPos():add(0,20,0))
	body.model = SHIP.model
	events.POST_WORLD_RENDER:register(function (delta)
		PanCamera.setPos(body:getPos())
	end)
	events.ON_EXIT:register(function ()
		host.unlockCursor = false
		renderer:renderRightArm()
		renderer:renderLeftArm()
	end)
end)