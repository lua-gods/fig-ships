---@diagnostic disable: missing-fields
local Macros = require("lib.GNMacros")
local Tween = require("lib.GNtween")
local Ship = require("lib.Ship")
local PanCamera = require("lib.PanCamera")
local Music = require("auto.host.music")

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


--──── Main Macro ────────────────────────────────────────────--

return Macros.new(function(events, ...)
	local mode = 0
	local paint
	local shipPos = player:getPos()
	shipPos.y = math.max(SEA_LEVEL, world.getHeight(shipPos.x, shipPos.z, "WORLD_SURFACE")) + MARGIN

	local lHoveredPart ---@type Ship.Part?
	local hoveredPart ---@type Ship.Part?
	local selectedPart ---@type Ship.Part?
	local placementPos
	local placementRot = 0
	local placementDir

	PanCamera.setPos(shipPos)

	SHIP.model:pos(shipPos * 16)
	:setVisible(true)

	local preview

	local buildPage = action_wheel:newPage("Builder")
	local paintPage = action_wheel:newPage("Paint")



	local function clearPreview()
		if preview then
			preview:remove()
		end
	end

	---@param model ModelPart
	---@param r Vector3|number?
	---@param g number?
	---@param b number?
	local function highlightPart(model, r, g, b)
		if model then
			if r then
				model:setPrimaryRenderType("CUTOUT")
				model:setSecondaryRenderType("EYES")
				model:setSecondaryTexture("CUSTOM", textures["textures.manditory"])
				---@diagnostic disable-next-line: param-type-mismatch
				model:setSecondaryColor(r, g, b)
			else
				model:setPrimaryRenderType("CUTOUT")
				model:setSecondaryTexture("SECONDARY")
			end
		end
	end

	local function setSelectedPart(part)
		if selectedPart then
			highlightPart(selectedPart.model)
		end
		if selectedPart ~= part then
			selectedPart = part
			if selectedPart then
				highlightPart(selectedPart.model, SELECTED_COLOR)
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

	action_wheel:setPage()
	--──── PAINT PAGE ────────────────────────────────────────────--

	paintPage:newAction()
		 :setItem(namedHead("tex;textures.return"))
		 :setTitle(fancyTitle("Return", "Return back to build page"))
		 :onLeftClick(function(self)
			 action_wheel:setPage(buildPage)
		 end)
	paintPage:newAction()
		 :setItem(namedHead("tex;textures.none"))
		 :setTitle(fancyTitle("None", "Remove paint off of the ship"))
		 :onLeftClick(function(self)
			 paint = nil
			 action_wheel:setPage(buildPage)
		 end)
	for i, id in ipairs(Ship.getPaintBlocks()) do
		local index = i -- turns out i is a reference number, not a constant
		local name = id
			 :gsub("_", " ")
			 :gsub("%s%S", string.upper)
			 :gsub("^%l", string.upper)
		paintPage:newAction()
			 :setItem(id)
			 :setTitle(fancyTitle(name, "Paint the ship with " .. name))
			 :onLeftClick(function(self)
				 paint = index
				 action_wheel:setPage(buildPage)
			 end)
	end



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
			 "Chose a color and select a part to paint!"))
		 :onLeftClick(function(self)
			 mode = -1
			 setSelectedPart()
			 action_wheel:setPage(paintPage)
			 updateHighlight()
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
		 
		 
	config:setName("GN.ship")
	local isMusicActive = config:load("music") and true or false
	buildPage:newAction()
		 :setItem(namedHead("tex;textures.music"))
		 :setTitle(fancyTitle("Toggle Music", "dispicable swines music"))
		 :setToggled(isMusicActive)
		 :onToggle(function (state, self)
			Music:setActive(state)
		 end)
		 Music:setActive(isMusicActive)
	buildPage:newAction()
		 :setItem(namedHead("tex;textures.return"))
		 :setTitle(fancyTitle("Return", "Exit back to the main menu"))
		 :onLeftClick(function(self)
			 setScreen("main")
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
					 preview = part.model:copy("preview"):scale(SHIP.scale):setParentType("WORLD")
						  :moveTo(models)
						  :setOpacity(0.2)
					 updateHighlight()
				 end)
			actions[i] = action
		end
	end

	-- generate new probability
	action_wheel:setPage(buildPage)

	renderer:setCameraPivot(shipPos)
	renderer:renderRightArm(false)
	renderer:renderLeftArm(false)
	renderer:setRenderCrosshair(false)
	host:setUnlockCursor(true)




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
		local to = screenToWorldSpace(300, mpos, getRealFov())
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

		placementRot = placementRot
		
		if preview then
			if placementPos then
				if SHIP:isOccupied(placementPos * 16) then
					preview:setColor(1, 0, 0)
				else
					preview:setColor(1, 1, 1)
				end
				preview:setPos((placementPos * SHIP.scale + shipPos) * 16)
				:setRot(0,placementRot*90,0)
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
				highlightPart(lHoveredPart.model)
			end

			if selectedPart then
				highlightPart(selectedPart.model, SELECTED_COLOR)
			end

			if hoveredPart then
				highlightPart(hoveredPart.model, HOVER_COLOR)
			end
			lHoveredPart = hoveredPart
		end
	end)






	for key, value in pairs(KEYBINDS) do
		value.press = function () return true end
	end


	KEYBINDS.select:onPress(function(modifiers, self)
		if notObscured() then
			if mode == 0 then -- SELECT MODE
				if hoveredPart then
					setSelectedPart(hoveredPart)
					playSound("minecraft:entity.item_frame.add_item", 0.9)
					highlightPart(hoveredPart.model, PRESSED_COLOR)
				else
					setSelectedPart()
				end
			elseif mode == -1 then -- PAINT MODE
				if hoveredPart then
					if paint then
						playSound("minecraft:block.honey_block.place")
					else
						playSound("minecraft:item.axe.scrape")
					end
					SHIP:paintPart(hoveredPart.id, paint)
				end
			else -- BUILD MODE
				if placementPos and not SHIP:isOccupied(placementPos * 16) then
					--playSound("minecraft:block.iron_trapdoor.close", 0.5)
					playSound("minecraft:block.iron_door.close", 0.5)
					local part = SHIP:newPart(mode, placementPos * 16, placementRot)
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
				highlightPart(hoveredPart.model, SELECTED_COLOR)
			else
				highlightPart(hoveredPart.model, HOVER_COLOR)
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
				setSelectedPart()
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
			updateHighlight()
			return true
		else
			if selectedPart then
				setSelectedPart()
				return true
			end
		end
	end)

	KEYBINDS.rotate:onPress(function (modifiers, self)
		placementRot = (placementRot + 1) % 4
		return true
	end)

	events.ON_EXIT:register(function()
		renderer:renderRightArm()
		renderer:renderLeftArm()
		renderer:setCameraRot()
		renderer:setCameraPos()
		renderer:setCameraPivot()
		renderer:setRenderCrosshair()
		clearPreview()
		setSelectedPart()
		SHIP.model:setVisible(false)
		PanCamera.setPos()
		isMusicActive = Music.isActive
		Music:setActive(false)
		config:setName("GN.ship")
		config:save("music", isMusicActive)
		host:setUnlockCursor()

		for key, value in pairs(KEYBINDS) do
			value.press = nil
			value.release = nil
		end
	end)


	--────  SKULL SHINANIGANS  ────────────────────────────────────────────────────────--
end)
