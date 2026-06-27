---@diagnostic disable: missing-fields
local Macros = require("lib.GNMacros")
local Tween = require("lib.GNtween")
local Ship = require("lib.Ship")
local PanCamera = require("lib.PanCamera")
require("auto.host.ocean") -- make sure sea level is declared

--────  CONFIG  ────────────────────────────────────────────────────────--

-- height from the ground/sea
local MARGIN = 5

local SHIP_SAVE_PATH = "warship.gnws"



-- THEME
local HOVER_COLOR = vectors.hexToRGB("#cccccc")
local SELECTED_COLOR = vectors.hexToRGB("#c3f278")
local PRESSED_COLOR = vectors.hexToRGB("#999999")

local KEYBINDS = require("auto.host.keybinds")

for key, value in pairs(KEYBINDS) do
	value:gui(true)
end

--────  END OF CONFIG  ────────────────────────────────────────────────────────--


local face2dir = {
	["north"] = vectors.vec3(0, 0, -1),
	["east"]  = vectors.vec3(1, 0, 0),
	["south"] = vectors.vec3(0, 0, 1),
	["west"]  = vectors.vec3(-1, 0, 0),
	["up"]    = vectors.vec3(0, 1, 0),
	["down"]  = vectors.vec3(0, -1, 0),
}



--──── SHIP PARTS PARSING ────────────────────────────────────────────--



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
	shipPos.y = math.max(SEA_LEVEL, world.getHeight(shipPos.x, shipPos.z, "WORLD_SURFACE")) + MARGIN
	
	local lHoveredPart ---@type Ship.Part?
	local hoveredPart ---@type Ship.Part?
	local selectedPart ---@type Ship.Part?
	local placementPos
	local placementDir

	PanCamera.setPos(shipPos)
	
	SHIP.model:pos(shipPos * 16)


	local preview

	local buildPage = action_wheel:newPage("Builder")
	local paintPage = action_wheel:newPage("Paint")

	local function clearPreview()
		if preview then
			preview:remove()
		end
	end

	action_wheel:setPage()
	events.ENTITY_INIT:register(function()
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
			 :setItem(namedHead("tex;textures.deploy"))
			 :setTitle(fancyTitle("Dploy Ship", "Spawn your ship into the world!"))
			 :onLeftClick(function(self)
				 playSound("minecraft:block.fence_gate.open", 0.2)
				 playSound("minecraft:block.dispenser.launch", 0.3)
				 playSound("minecraft:block.piston.contract", 0.3)
				 setScreen("deploy")
			 end)


		buildPage:newAction()
			 :setItem(namedHead("tex;textures.load"))
			 :setTitle(fancyTitle("Load Ship", "Load saved Ship"))
			 :onLeftClick(function(self)
				 local buffer = data:createBuffer()
				 buffer:readFromStream(file:openReadStream(SHIP_SAVE_PATH))
				 buffer:setPosition(0)
				 local shipData = buffer:readByteArray(buffer:available())
				 SHIP:unpackData(shipData)
				 playSound("minecraft:block.trial_spawner.eject_item")
			 end)


		buildPage:newAction()
			 :setItem(namedHead("tex;textures.save"))
			 :setTitle(fancyTitle("Save Ship", "Save the ship"))
			 :onLeftClick(function(self)
				 local shipData = SHIP:packData()
				 local buffer = data:createBuffer(#shipData)
				 buffer:writeByteArray(shipData)
				 buffer:setPosition(0)
				 buffer:writeToStream(file:openWriteStream(SHIP_SAVE_PATH))
				 playSound("minecraft:block.trial_spawner.open_shutter")
			 end)

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
				 clearPreview()
			 end)

		actions[0] = buildPage:newAction()
			 :setItem(namedHead("tex;textures.select"))
			 :setTitle(fancyTitle("Select", "Select a part of the ship"))
			 :onLeftClick(function(self)
				 mode = 0
				 updateHighlight()
				 clearPreview()
			 end)

		for i, part in pairs(Ship.getShipPartIdentities()) do
			if not part.locked then
				local action = buildPage:newAction()
					 :setItem(namedHead(part.name))
					 :setTitle(fancyTitle(part.name, part.desc or "..."))
					 :onLeftClick(function(self)
						 mode = i
						 if preview then
							 preview:remove()
						 end
						 preview = part.model:copy("preview"):scale(SHIP.scale):setParentType("WORLD"):moveTo(models)
							  :setOpacity(0.2)
						 updateHighlight()
					 end)
				actions[i] = action
			end
		end

		-- generate new probability
		action_wheel:setPage(buildPage)
	end)

	renderer:setCameraPivot(shipPos)
	renderer:renderRightArm(false)
	renderer:renderLeftArm(false)
	renderer:setRenderCrosshair(false)
	host:setUnlockCursor(true)


	---@param model ModelPart
	---@param r Vector3|number?
	---@param g number?
	---@param b number?
	local function HighlightPart(model, r, g, b)
		if model then
			if r then
				model:setPrimaryRenderType("CUTOUT")
				model:setSecondaryRenderType("EYES")
				model:setSecondaryTexture("CUSTOM", textures["textures.manditory"])
				---@diagnostic disable-next-line: param-type-mismatch
				model:setSecondaryColor(r, g, b)
			else
				model:setPrimaryRenderType("TRANSLUCENT")
				model:setSecondaryTexture("SECONDARY")
			end
		end
	end

	SHIP:newPart(1)
	events.WORLD_RENDER:register(function(delta)

		local title = "..."

		if mode == 0 then
			title = ":cursor_1: Select Mode"
		elseif mode == -1 then
			title = ":palette: Paint Mode"
		else
			title = ":hammer_big: Placing " .. Ship.getShipPartIdentities()[mode].name
		end

		host:setActionbar(title)
		
		
		if not notObscured() then return end
		local mpos = client:getMousePos()
		local pos = screenToWorldSpace(0.1, mpos, getRealFov())
		local to = screenToWorldSpace(50, mpos, getRealFov())
		local aabb, hitPos, side, index = raycast:aabb(pos - shipPos, to - shipPos, SHIP.hitbox)
		if hitPos and index and hitPos and side then
			placementPos = (hitPos / SHIP.scale) + face2dir[side] * 0.5
			placementDir = face2dir[side]
			placementPos.x = math.floor(placementPos.x + 0.5)
			if side == "up" then
				placementPos.y = aabb[2].y / SHIP.scale
			else
				placementPos.y = aabb[1].y / SHIP.scale
			end
			placementPos.z = math.floor(placementPos.z + 0.5)

			placementPos.x = math.clamp(placementPos.x, -128, 128)
			placementPos.y = math.clamp(placementPos.y, 0, 256)
			placementPos.z = math.clamp(placementPos.z, -128, 128)
		else
			placementPos = nil
		end

		if preview then
			if placementPos then
				if SHIP:isOccupied(placementPos * 16) then
					preview:setColor(1, 0, 0)
				else
					preview:setColor(1, 1, 1)
				end
				preview:setPos((placementPos * SHIP.scale + shipPos) * 16)
			else
				preview:setPos(0, -6942067, 0)
			end
		end

		if mode <= 0 then
			hoveredPart = side and SHIP.parts[index]
		else
			hoveredPart = nil
		end
		if hoveredPart ~= lHoveredPart then
			if lHoveredPart then
				HighlightPart(lHoveredPart.model)
			end

			if selectedPart then
				HighlightPart(selectedPart.model, SELECTED_COLOR)
			end

			if hoveredPart then
				HighlightPart(hoveredPart.model, HOVER_COLOR)
			end
			lHoveredPart = hoveredPart
		end
	end)




	local function setSelectedPart(part)
		if selectedPart then
			HighlightPart(selectedPart.model)
		end
		if selectedPart ~= part then
			selectedPart = part
			if selectedPart then
				HighlightPart(selectedPart.model, SELECTED_COLOR)
				PanCamera.setPos((selectedPart.pos * SHIP.scale) / 16 + shipPos)
			else
				playSound("minecraft:entity.item_frame.remove_item")
				local center = vec(0, 0, 0)
				for index, value in ipairs(SHIP.parts) do
					center = center + value.pos * SHIP.scale
				end
				PanCamera.setPos((center / #SHIP.parts) / 16 + shipPos)
			end
		end
	end

	


	KEYBINDS.select:onPress(function(modifiers, self)
		if notObscured() then
			if mode == 0 then -- SELECT MODE
				if hoveredPart then
					setSelectedPart(hoveredPart)
					playSound("minecraft:entity.item_frame.add_item", 0.9)
					HighlightPart(hoveredPart.model, PRESSED_COLOR)
				else
					setSelectedPart()
				end
			elseif mode == -1 then -- PAINT MODE
				if hoveredPart then
					if paint then
						SHIP:paintPart(hoveredPart.id, paint)
						playSound("minecraft:block.honey_block.place")
					end
				end
			else -- BUILD MODE
				if placementPos and not SHIP:isOccupied(placementPos * 16) then
					--playSound("minecraft:block.iron_trapdoor.close", 0.5)
					playSound("minecraft:block.iron_door.close", 0.5)
					local part = SHIP:newPart(mode, placementPos * 16, 0)
					Tween.new {
						from = (part.pos + placementDir * 16) * SHIP.scale,
						to = (part.pos * SHIP.scale),
						easing = "inQuad",
						duration = 0.25,
						tick = function(v, t)
							part.model:setPos(v)
						end,
					}
					setSelectedPart(part)
				end
			end
		end
	end):onRelease(function(modifiers, self)
		if hoveredPart and notObscured() then
			if hoveredPart == selectedPart then
				HighlightPart(hoveredPart.model, SELECTED_COLOR)
			else
				HighlightPart(hoveredPart.model, HOVER_COLOR)
			end
		end
	end)

	KEYBINDS.delete:onPress(function(modifiers, self)
		if selectedPart then -- DELETE ONLY IN SELECT MODE
			if not selectedPart.identity.locked then
				playSound("minecraft:block.iron_trapdoor.open", 0.5)
				playSound("minecraft:block.iron_trapdoor.close", 0.5)
				playSound("minecraft:entity.generic.eat")
				SHIP:removePart(selectedPart.id)
			else
				playSound("minecraft:entity.breeze.deflect")
			end
		end
	end)

	KEYBINDS.esc:onPress(function(modifiers, self)
		if mode ~= 0 then
			mode = 0
			playSound("minecraft:entity.breeze.deflect")
			clearPreview()
			return true
		else
			if selectedPart then
				setSelectedPart()
				return true
			end
		end
	end)

	KEYBINDS.vineboom:onPress(function(modifiers, self)
		local data = SHIP:packData()
		SHIP:unpackData(data)
	end)

	

	events.ON_EXIT:register(function()
		renderer:renderRightArm()
		renderer:renderLeftArm()
		renderer:setCameraRot()
		renderer:setCameraPos()
		renderer:setCameraPivot()
		renderer:setRenderCrosshair()
		host:setUnlockCursor()
		
		KEYBINDS.select.press = nil
		KEYBINDS.select.release = nil
		KEYBINDS.vineboom.press = nil
		KEYBINDS.delete.press = nil
		KEYBINDS.esc.press = nil
	end)


	--────  SKULL SHINANIGANS  ────────────────────────────────────────────────────────--

	
end)
