---@diagnostic disable: missing-fields
local Macros = require("lib.GNMacros")
require("auto.ocean") -- make sure sea level is declared

local ICON = models.misc.SKULL
ICON:setRot(30, -45)
	 :setPrimaryRenderType("CUTOUT_EMISSIVE_SOLID")

--────  CONFIG  ────────────────────────────────────────────────────────--

-- height from the ground/sea
local MARGIN = 5

-- CAMERA CONTROLS
local SENSITIVITY = 0.15
local ZOOM_SPEED = 1.2

local CAMERA_EASING = 10
local ZOOM_EASING = 20

-- THEME
local HOVER_COLOR = vectors.hexToRGB("#cccccc")
local SELECTED_COLOR = vectors.hexToRGB("#c3f278")
local PRESSED_COLOR = vectors.hexToRGB("#999999")

local KEYBINDS = {
	pan = keybinds:fromVanilla("key.use"),
	select = keybinds:fromVanilla("key.attack"),
	delete = keybinds:newKeybind("delete", "key.keyboard.x"),
	rotate = keybinds:newKeybind("rotate", "key.keyboard.r"),
}

for key, value in pairs(KEYBINDS) do
	value:gui(true)
end

--────  END OF CONFIG  ────────────────────────────────────────────────────────--

---@type table<string,Ship.Part.Identity>
local PARTS = {
	["Front Hull"] = {},
	["Hull"] = {},
	["Back Hull"] = {},

	["Control Room"] = {},

	["Accommodation Floor 2"] = {},
	["Accommodation Floor 1"] = {},

	["Funnel"] = {},
	["Core Hull"] = {},

	["Cannon"] = {},
	["Schwerer Gustav"] = {},
}



---@class Ship.Part.Identity
---@field id string
---@field model ModelPart
---@field skullIcon ModelPart
---@field bounds {min:Vector3, max:Vector3}?
---@field studs {pos:Vector3, rot:Vector3}[]
---@field desc string?
---@field process fun()?


---@class Ship.Part
---@field id integer
---@field identity Ship.Part.Identity
---@field pos Vector3
---@field rot Vector3
---@field model ModelPart
---@field paint Minecraft.blockID


local yourMom = math.huge

--──── SHIP PARTS PARSING ────────────────────────────────────────────--

local SKULL_ROOT = models:newPart("SkullRoot", "SKULL")
--local a = ""
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

	local skullIcon = model
		 :copy("Skull" .. model:getName())
		 :moveTo(SKULL_ROOT)
		 :setPos(-offset)
		 :setParentType("SKULL")
		 :setVisible(false)

	local parts = PARTS[id] or {}


	--a = a .. '["'..id..'"]\n'

	PARTS[id] = parts
	parts.id = id
	parts.model = models:newPart(id)
		 :remove()
		 :addChild(
			 model:setPos(-offset)
			 :remove()
		 )
	parts.skullIcon = skullIcon
	parts.studs = {}
	parts.bounds = bounds
end
--──── Utility Functions ────────────────────────────────────────────--

---@param id Minecraft.soundID
---@param pitch number?
---@param volume number?
local function playSound(id, pitch, volume)
	local instance = sounds[id]
		 :pos(client:getCameraPos() + client:getCameraDir())
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

local function _recursiveComponent(text, component)
	if component.text then
		text = text .. component.text
	end

	if component.extra then
		for _, extra in ipairs(component.extra) do
			text = text .. _recursiveComponent(text, extra)
		end
	end

	return text
end



---Converts raw json text to the final output text
---@param rawJsonText any
---@return unknown
local function toPlainText(rawJsonText)
	local ok, result = pcall(parseJson, rawJsonText)
	if ok then
		if type(result) == "table" then
			return _recursiveComponent("", result)
		else
			return result
		end
	else
		return rawJsonText
	end
end


local function notObscured()
	return not (action_wheel:isEnabled()) and (not host:getScreen()) or host:isChatOpen()
end

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

local PAINT_BLOCKS = {}

for index, id in ipairs(client.getRegistry("minecraft:block")) do
	local block = world.newBlock(id)
	if block:isOpaque() and block:isSolidBlock() then
		PAINT_BLOCKS[#PAINT_BLOCKS + 1] = id
	end
end

-- source: imitfu https://www.geeksforgeeks.org/dsa/introduction-to-levenshtein-distance/
local function levenshtein(a, b)
	local lenA = #a
	local lenB = #b

	local matrix = {}

	for i = 0, lenA do
		matrix[i] = {}
		matrix[i][0] = i
	end

	for j = 0, lenB do
		matrix[0][j] = j
	end

	for i = 1, lenA do
		for j = 1, lenB do
			local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1

			matrix[i][j] = math.min(
				matrix[i - 1][j] + 1, -- deletion
				matrix[i][j - 1] + 1, -- insertion
				matrix[i - 1][j - 1] + cost -- substitution
			)
		end
	end

	return matrix[lenA][lenB]
end

local function similarity(a, b)
	a = a:lower()
	b = b:lower()

	local distance = levenshtein(a, b)
	local maxLen = math.max(#a, #b)

	if maxLen == 0 then
		return 1
	end

	return 1 - (distance / maxLen)
end

local function fuzzySearch(query)
	local results = {}

	for _, word in ipairs(PAINT_BLOCKS) do
		table.insert(results, {
			word = word,
			score = similarity(query, word),
		})
	end

	table.sort(results, function(a, b)
		return a.score > b.score
	end)

	return results
end

--──── Main Macro ────────────────────────────────────────────--

return Macros.new(function(events, ...)
	local mode = 0
	local paint
	local shipPos = client:getCameraPos()
	local camPos = shipPos
	local targetCamPos = shipPos
	local zoom = 5
	local targetZoom = 3

	local buildPage = action_wheel:newPage("Builder")
	local paintPage = action_wheel:newPage("Paint")

	action_wheel:setPage()
	events.ENTITY_INIT:register(function()
		local u1, u2, u3, u4 = client.uuidToIntArray(player:getUUID())

		--──── PAINT PAGE ────────────────────────────────────────────--

		local query = ""
		local actionCount = 0
		local function updatePaintPage()
			-- clear
			if actionCount > 1 then
				for i = 2, actionCount, 1 do
					paintPage:action(i, nil)
				end
			end
			actionCount = 1
			for index, data in ipairs(fuzzySearch(query or "")) do
				actionCount = actionCount + 1
				local id = data.word
				paintPage:newAction()
					 :setItem(id)
					 :setTitle(id)
					 :onLeftClick(function(self)
						 paint = id
					 end)
			end
		end

		local toggle = false
		local function search(active)
			query = ""
			if active then
				events.CHAR_TYPED:register(function(char, modifiers, codepoint)
					if action_wheel:isEnabled() then
						query = query .. char
						updatePaintPage()
					end
				end, "search")
				events.KEY_PRESS:register(function(key, state, modifiers)
					if action_wheel:isEnabled() then
						if state ~= 0 then
							if key == 259 then -- erase
								query = query:sub(1, -2)
							end
							updatePaintPage()
						end
					end
				end, "search")
			else
				events.CHAR_TYPED:remove("search")
				events.KEY_PRESS:remove("search")
			end
		end
		paintPage:newAction()
			 :setItem(namedHead("tex;textures.return"))
			 :setTitle(fancyTitle("Return", "Return back to build page"))
			 :onLeftClick(function(self)
				 action_wheel:setPage(buildPage)
				 search(false)
			 end)


		--──── BUILD PAGE ────────────────────────────────────────────--

		---@type Action[]
		local actions = {}

		local function updateHighlight()
			for key, value in pairs(actions) do
				value:setColor(key == mode and SELECTED_COLOR or nil)
				value:setHoverColor(key == mode and SELECTED_COLOR or nil)
			end
		end

		buildPage:newAction()
			 :setItem(namedHead("tex;textures.load"))
			 :setTitle(fancyTitle("Load Ship", "Load saved Ship"))

		buildPage:newAction()
			 :setItem(namedHead("tex;textures.save"))
			 :setTitle(fancyTitle("Save Ship", "Save the ship"))

		actions[-1] = buildPage:newAction()
			 :setItem(namedHead("tex;textures.paint"))
			 :setTitle(fancyTitle("Paint",
				 "Chose a color and select a part to paint\n[TIP]: type to search for the block!"))
			 :onLeftClick(function(self)
				 mode = -1
				 action_wheel:setPage(paintPage)
				 updateHighlight()
				 updatePaintPage()
				 search(true)
			 end)

		actions[0] = buildPage:newAction()
			 :setItem(namedHead("tex;textures.select"))
			 :setTitle(fancyTitle("Select", "Select a part of the ship"))
			 :onLeftClick(function(self)
				 mode = 0
				 updateHighlight()
			 end)

		for key, value in pairs(PARTS) do
			buildPage:newAction()
				 :setItem(namedHead(key))
				 :setTitle(fancyTitle(key, value.desc or "..."))
		end



		-- generate new probability
		action_wheel:setPage(buildPage)
	end)


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
		local i = 0
		for id, part in pairs(ship) do
			i = i + 1
			part.id = i
		end
		for id, value in pairs(ship) do
			local mat = matrices.mat4()
			mat:rotate(value.rot)
			mat:translate(value.pos)

			local bounds = value.identity.bounds

			hitbox[id] = {
				mat:apply(bounds.min) / 16,
				mat:apply(bounds.max) / 16,
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

	local function HighlightPart(part, r, g, b)
		if not part then return end
		local m = part.model
		if m then
			if r then
				m:setSecondaryRenderType("EYES")
				m:setSecondaryTexture("CUSTOM", textures["textures.manditory"])
				m:setSecondaryColor(r, g, b)
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

	local lTime = client:getSystemTime()
	events.WORLD_RENDER:register(function(delta)
		local time = client:getSystemTime()
		local delta = (time - lTime) / 1000
		delta = math.min(delta, 1)
		lTime = time
		camPos = math.lerp(camPos, targetCamPos, CAMERA_EASING * delta)
		renderer:setCameraPivot(camPos)

		zoom = math.lerp(zoom, targetZoom, ZOOM_EASING * delta)
		renderer:setCameraPos(0, 0, zoom)

		renderer:setCameraRot(rot.xy_)
	end)

	local lHoveredPart ---@type Ship.Part?
	local hoveredPart ---@type Ship.Part?
	local selectedPart ---@type Ship.Part?
	events.MOUSE_MOVE:register(function(x, y)
		if KEYBINDS.pan:isPressed() then
			rot.x = rot.x + y * SENSITIVITY
			rot.y = rot.y + x * SENSITIVITY
			rot.x = math.clamp(rot.x, -89, 89)
		end
		if not notObscured() then return end
		local mpos = client:getMousePos()
		local pos = screenToWorldSpace(0.1, mpos, getRealFov())
		local to = screenToWorldSpace(20, mpos, getRealFov())
		local aabb, hitPos, side, index = raycast:aabb(pos - shipPos, to - shipPos, hitbox)

		hoveredPart = side and ship[index]
		if hoveredPart ~= lHoveredPart then
			if lHoveredPart then
				HighlightPart(lHoveredPart)
			end

			if selectedPart then
				HighlightPart(selectedPart, SELECTED_COLOR)
			end

			if hoveredPart then
				HighlightPart(hoveredPart, HOVER_COLOR)
			end
			lHoveredPart = hoveredPart
		end
	end)

	KEYBINDS.select:onPress(function(modifiers, self)
		if notObscured() then
			if mode == 0 then -- SELECT MODE
				if hoveredPart then
					HighlightPart(selectedPart)
					selectedPart = hoveredPart
					HighlightPart(hoveredPart, PRESSED_COLOR)
					playSound("minecraft:entity.item_frame.add_item", 0.9)
					targetCamPos = hoveredPart.pos / 16 + shipPos
				end
			elseif mode == -1 then -- PAINT MODE
				if hoveredPart then
					if paint then
						hoveredPart.paint = paint
						local tex = world.newBlock(paint):getTextures()
						local path = tex[next(tex)]
						if path then
							path = path[1]
							playSound("minecraft:block.honey_block.place", 0.75)
							hoveredPart.model:setPrimaryTexture("RESOURCE", path .. ".png")
							targetCamPos = hoveredPart.pos / 16 + shipPos
						end
					end
				end
			end
		end
	end):onRelease(function(modifiers, self)
		if hoveredPart and notObscured() then
			if hoveredPart == selectedPart then
				HighlightPart(hoveredPart, SELECTED_COLOR)
			else
				HighlightPart(hoveredPart, HOVER_COLOR)
			end
		end
	end)

	KEYBINDS.delete:onPress(function(modifiers, self)
		if selectedPart and mode == 0 then -- DELETE ONLY IN SELECT MODE
			selectedPart.model:remove()
			playSound("minecraft:block.iron_trapdoor.open", 0.5)
			playSound("minecraft:block.iron_trapdoor.close", 0.5)
			playSound("minecraft:entity.generic.eat")
			table.remove(ship, selectedPart.id)
			recalculateHitbox()
			selectedPart = nil
		end
		recalculateHitbox()
	end)

	events.MOUSE_SCROLL:register(function(dir)
		if notObscured() then
			targetZoom = math.max(targetZoom * ZOOM_SPEED ^ -dir, 1)
			return false
		end
	end)

	events.ON_EXIT:register(function()
		renderer:renderRightArm()
		renderer:renderLeftArm()
		renderer:setCameraPivot()
		renderer:setRenderCrosshair()
		host:setUnlockCursor()
	end)


	--────  SKULL SHINANIGANS  ────────────────────────────────────────────────────────--

	local lastVisible
	events.SKULL_RENDER:register(function(delta, block, item, entity, ctx)
		if item then
			local name = toPlainText(item:getName())
			if lastVisible then
				lastVisible:setVisible(false)
			end
			if name:find("^tex;") then
				local tex = name:sub(5)
				ICON:setPrimaryTexture("CUSTOM", textures[tex])
					 :setVisible(true)
				lastVisible = ICON
			else
				local part = PARTS[name]
				if part then
					ICON:setVisible(false)
					part.skullIcon
						 :setVisible(true)
						 :setRot(vec(0, -45 + rot.y, 0))
					lastVisible = part.skullIcon
				end
			end
		end
	end)
end)
