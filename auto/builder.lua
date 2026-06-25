local Macros = require("lib.GNMacros")
require("auto.ocean") -- make sure sea level is declared

-- height from the ground/sea
local MARGIN = 5
local SENSITIVITY = 0.15

local HOVER_COLOR = vectors.hexToRGB("#cccccc")
local SELECTED_COLOR = vectors.hexToRGB("#c3f278")
local PRESSED_COLOR = vectors.hexToRGB("#999999")

---@type table<string,Ship.Part.Identity>
local PARTS = {}

local KEYBINDS = {
	pan = keybinds:fromVanilla("key.use"),
	select = keybinds:fromVanilla("key.attack"),
	delete = keybinds:newKeybind("delete","key.keyboard.x"),
	rotate = keybinds:newKeybind("rotate","key.keyboard.r"),
}


---@class Ship.Part.Identity
---@field id string
---@field model ModelPart
---@field bounds {min:Vector3, max:Vector3}?
---@field studs {pos:Vector3, rot:Vector3}[]


---@class Ship.Part
---@field identity Ship.Part.Identity
---@field pos Vector3
---@field rot Vector3
---@field model ModelPart


local yourMom = math.huge

-- model parsing
for index, model in ipairs(models.ship.Parts:getChildren()) do
	local id = model:getName()
	local offset = model:getPivot()

	local bounds
	if model.Selection then
		local sel = model.Selection
		local min = vec(yourMom, yourMom, yourMom)
		local max = vec(-yourMom, -yourMom, -yourMom)
		for index, value in ipairs(sel:getVertices("textures.manditory")) do
			local pos = value:getPos()
			min.x = math.min(min.x, pos.x)
			min.y = math.min(min.y, pos.y)
			min.z = math.min(min.z, pos.z)
			max.x = math.max(max.x, pos.x)
			max.y = math.max(max.y, pos.y)
			max.z = math.max(max.z, pos.z)
		end
		min = min - offset
		max = max - offset
		bounds = { min = min, max = max }
		sel:remove()
	end

	PARTS[id] = {
		id = id,
		model = models:newPart(id):remove():addChild(model:setPos(-offset):remove()),
		studs = {},
		bounds = bounds,
	}
end

--──── Utility Functions ────────────────────────────────────────────--

---@param id Minecraft.soundID
---@param pitch number?
---@param volume number?
local function playSound(id,pitch,volume)
	local instance = sounds[id]
	:pos(client:getCameraPos()+client:getCameraDir())
	:pitch(pitch or 1)
	:volume(volume or 1)
	:play()
end

-- modified version of screen to world space made by Auria & GNamimates, used to get fov
local function screenToWorldSpace(distance, pos, fov)
	local mat = matrices.mat4()
	local wSize = client:getWindowSize()
	local mpos = (pos / wSize - vec(0.5, 0.5)) * vec(wSize.x / wSize.y, 1)
	if renderer:getCameraMatrix() then mat:multiply(renderer:getCameraMatrix()) end
	mat:translate(mpos.x * -fov * distance, mpos.y * -fov * distance, 0)
	mat:rotate(client:getCameraRot():mul(1, -1, 1))
	mat:translate(client:getCameraPos())
	pos = (mat * vectors.vec4(0, 0, distance, 1)).xyz
	return pos
end

local function getRealFov()
	local fov = math.tan(math.rad(client.getFOV() / 2)) * 2
	local pos = vectors.worldToScreenSpace(screenToWorldSpace(1, vec(0, 0), fov)).xy
	local fovErr = vec(-1, -1):length() / pos:length()
	return fov * fovErr
end

--──── Main Macro ────────────────────────────────────────────--

local BuilderMacro = Macros.new(function(events, ...)
	local shipPos = client:getCameraPos()
	local camPos = shipPos
	local targetCamPos = shipPos
	local zoom = 3
	
	
	shipPos.y = math.max(SEA_LEVEL, world.getHeight(shipPos.x, shipPos.z, "WORLD_SURFACE")) + MARGIN

	renderer:setCameraPivot(shipPos)
	renderer:renderRightArm(false)
	renderer:renderLeftArm(false)
	renderer:setRenderCrosshair(false)
	host:setUnlockCursor(true)

	local shipModel = models:newPart("warship", "WORLD")
	shipModel:pos(shipPos * 16)
	---@type Ship.Part[]
	local ship = {}

	local hitbox = {}
	local function recalculateHitbox()
		for id, value in pairs(ship) do
			local mat = matrices.mat4()
			mat:rotate(value.rot)
			mat:translate(value.pos)

			local bounds = value.identity.bounds

			hitbox[id] = {
				mat:apply(bounds.min)/16,
				mat:apply(bounds.max)/16,
			}
		end
	end

	local nextFree = 0
	local function newShipPart(id, pos, rot)
		local part = PARTS[id]
		if part then
			nextFree = nextFree + 1
			local model = part.model:copy("shipPart" .. nextFree)
			---@type Ship.Part
			local self = {
				model = model,
				pos = pos,
				rot = rot,
				identity = part,
				id = nextFree,
			}
			model
			:pos(pos)
			:rot(rot)
			:setPrimaryRenderType("CUTOUT")
			shipModel:addChild(model)
			ship[nextFree] = self
		end
	end
	
	local function HighlightPart(part,r,g,b)
		if not part then return end
		local m = part.model
		if m then
			if r then
				m:setSecondaryRenderType("EYES")
				m:setSecondaryTexture("CUSTOM",textures["textures.manditory"])
				m:setSecondaryColor(r,g,b)
			else
				m:setSecondaryTexture("SECONDARY")
			end
		end
	end
	
	local o = 0
	for id, value in pairs(PARTS) do
		o = o + 16
		newShipPart(id, vec(o, 0, 0), vec(0, 0, 0))
	end
	recalculateHitbox()

	local rot = vec(25, -45)

	events.WORLD_RENDER:register(function(delta)
		renderer:setCameraRot(rot.xy_)
		camPos = math.lerp(camPos, targetCamPos, 0.1	)
		renderer:setCameraPivot(camPos)
	end)
	
	local lHoveredPart
	local hoveredPart
	local selectedPart
	events.MOUSE_MOVE:register(function(x, y)
		if KEYBINDS.pan:isPressed() then
			rot.x = rot.x + y * SENSITIVITY
			rot.y = rot.y + x * SENSITIVITY
			rot.x = math.clamp(rot.x, -89, 89)
		end
		local mpos = client:getMousePos()
		local pos = screenToWorldSpace(0.1, mpos, getRealFov())
		local to = screenToWorldSpace(20, mpos, getRealFov())
		local aabb, hitPos, side, index = raycast:aabb(pos - shipPos, to-shipPos, hitbox)
		
		hoveredPart = side and ship[index]
		
		if hoveredPart ~= lHoveredPart then
			
			if lHoveredPart then
				HighlightPart(lHoveredPart)
			end
			
			if selectedPart then
				HighlightPart(selectedPart,SELECTED_COLOR)
			end
			
			if hoveredPart then
				HighlightPart(hoveredPart,HOVER_COLOR)
			end
			lHoveredPart = hoveredPart
		end
	end)
	
	KEYBINDS.select:onPress(function (modifiers, self)
		if not action_wheel:isEnabled() then
			if hoveredPart then
				HighlightPart(selectedPart)
				selectedPart = hoveredPart
				HighlightPart(hoveredPart,PRESSED_COLOR)
				playSound("minecraft:entity.item_frame.add_item",0.9)
				targetCamPos = hoveredPart.pos / 16 + shipPos
			end
		end
	end):onRelease(function (modifiers, self)
		if hoveredPart and not action_wheel:isEnabled() then
			playSound("minecraft:entity.item_frame.add_item")
			HighlightPart(hoveredPart,SELECTED_COLOR)
		end
	end)
	
	KEYBINDS.delete:onPress(function (modifiers, self)
		if selectedPart then
			selectedPart.model:remove()
			playSound("minecraft:block.iron_trapdoor.open",0.5)
			playSound("minecraft:block.iron_trapdoor.close"	,0.5)
			playSound("minecraft:entity.generic.eat")
			ship[selectedPart.id] = nil
			selectedPart = nil
		end
		recalculateHitbox()
	end)

	events.MOUSE_SCROLL:register(function(dir)
		zoom = math.max(zoom * 1.1^-dir, 1)
		renderer:setCameraPos(0, 0, zoom)
		return false
	end)
	renderer:setCameraPos(0, 0, zoom)

	events.ON_EXIT:register(function()
		renderer:renderRightArm()
		renderer:renderLeftArm()
		renderer:setCameraPivot()
		renderer:setRenderCrosshair()
		host:setUnlockCursor()
	end)
end)

BuilderMacro:setActive(true)
