local Macros = require("lib.GNMacros")
local Ship = require("lib.Ship")
local RigidBody = require("lib.RigidBody")
local PanCamera = require("lib.PanCamera")

local KEYBINDS = require("auto.host.keybinds")

local function notObscured()
	return not (action_wheel:isEnabled()) and (not host:getScreen()) or host:isChatOpen()
end




local function fancyTitle(title, desc)
	return toJson {
		{
			color = "gray",
			text = "",
		},
		{
			text = title,
			color = "white",
			bold = true,
		},
		{
			text = "\n" .. desc,
		},
	}
end



return Macros.new(function (events, ...)
	
	local page = action_wheel:newPage()
	page:newAction()
	:setTitle(fancyTitle("Return,","Return back to the drawing board"))
	:setItem(namedHead("tex;textures.return"))
	:onLeftClick(function(self)
		setScreen("builder")
	end)
	
	action_wheel:setPage(page)
	
	host.unlockCursor = true
	renderer:renderRightArm(false)
		renderer:renderLeftArm(false)
	local body = RigidBody.new()
	
	local points = {}
	local i = 0
	local center = vec(0,0,0)
	local min = vec(YOUR_MOM, YOUR_MOM, YOUR_MOM)
	local max = vec(-YOUR_MOM, -YOUR_MOM, -YOUR_MOM)
	for index, aabb in ipairs(SHIP.hitbox) do
		for z = aabb[1].z, aabb[2].z, 8 do
			for y = aabb[1].y, aabb[2].y, 8 do
				for x = aabb[1].x, aabb[2].x, 8 do
					i = i + 1
					local pos = vec(x,y,z)
					points[i] = pos
					center = center + pos
					min = vec(math.min(min.x, pos.x), math.min(min.y, pos.y), math.min(min.z, pos.z))
					max = vec(math.max(max.x, pos.x), math.max(max.y, pos.y), math.max(max.z, pos.z))
				end
			end
		end
	end
	center = center / i
	body.size = (max - min)
	body.points = points
	local ppos = player:getPos()
	body:setPos(ppos.x, SEA_LEVEL + 5,ppos.z)
	body.model = SHIP.model
	
	SHIP.body = body
	SHIP.model:setVisible(true)
	BODY = body
	body.center = center
	body.ship = SHIP
	
	events.POST_WORLD_RENDER:register(function (delta)
		PanCamera.setPos(body:getPos())
	end)
	
	
	for key, value in pairs(KEYBINDS) do
		value.press = function () if notObscured() then
			return true
		end end
		value.release = nil
	end
	KEYBINDS.esc.press = nil
	
	events.ON_EXIT:register(function ()
		for key, value in pairs(KEYBINDS) do
			value.press = nil
			value.release = nil
		end
		body.model = nil
		body:free()
		host.unlockCursor = false
		renderer:renderRightArm()
		renderer:renderLeftArm()
	end)
end)