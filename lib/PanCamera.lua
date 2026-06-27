local GNCommon = require("lib.GNcommon")

local KEYBINDS = require("auto.host.keybinds")
-- CAMERA CONTROLS
local SENSITIVITY = 0.15
local ZOOM_SPEED = 1.2

local DEFAULT_ZOOM = 16

local CAMERA_EASING = 10
local ZOOM_EASING = 20

local camPos = nil
local targetCamPos = nil
local zoom = nil
local targetZoom = nil
local rot = vec(25, -45)


local API = {}

function API.setPos(x,y,z)
	if x then
		local pos = GNCommon.vec3(x,y,z)
		targetCamPos = pos
	else
		camPos = nil
		zoom = nil
		targetCamPos = nil
	end
end

local function notObscured()
	return not (action_wheel:isEnabled()) and (not host:getScreen()) or host:isChatOpen()
end

local lTime = client:getSystemTime()
events.WORLD_RENDER:register(function(delta)
	local time = client:getSystemTime()
	local delta = (time - lTime) / 1000
	delta = math.min(delta, 1)
	lTime = time
	if targetCamPos then
		camPos = math.lerp(camPos or targetCamPos, targetCamPos, math.min(CAMERA_EASING * delta, 1))
		renderer:setCameraPivot(camPos)
	
		targetZoom = targetZoom or DEFAULT_ZOOM
		zoom = math.lerp(zoom or targetZoom, targetZoom, math.min(ZOOM_EASING * delta, 1))
		renderer:setCameraPos(0, 0, zoom)
	
		renderer:setCameraRot(rot.xy_)
	end
end)

events.MOUSE_MOVE:register(function(x, y)
	if KEYBINDS.pan:isPressed() then
		rot.x = rot.x + y * SENSITIVITY
		rot.y = rot.y + x * SENSITIVITY
		rot.x = math.clamp(rot.x, -89, 89)
	end
end)

events.MOUSE_SCROLL:register(function(dir)
	if notObscured() then
		targetZoom = math.max(targetZoom * ZOOM_SPEED ^ -dir, 1)
		return false
	end
end)

return API