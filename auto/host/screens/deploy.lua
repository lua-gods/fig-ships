local Macros = require("lib.GNMacros")
local Ship = require("lib.Ship")
local RigidBody = require("lib.RigidBody")
local PanCamera = require("lib.PanCamera")



local function namedHead(name)
	local u1, u2, u3, u4 = client.uuidToIntArray(player:getUUID())
	local item =
	[=[minecraft:player_head[profile={id:[I;%s,%s,%s,%s]},custom_name='{"text":"%s"}']]]=]
	item = item:format(u1, u2, u3, u4, name)
	return item
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


local YOUR_MOM = math.huge

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
	events.ON_EXIT:register(function ()
		body.model = nil
		host.unlockCursor = false
		renderer:renderRightArm()
		renderer:renderLeftArm()
	end)
end)