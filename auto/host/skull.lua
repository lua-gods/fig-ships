local Ship = require("lib.Ship")
local ICON = models.misc.SKULL
ICON:setRot(30, -45)
	 :setPrimaryRenderType("CUTOUT_EMISSIVE_SOLID")


local lastVisible


local SKULL_ROOT = models:newPart("SkullRoot", "SKULL")
local icons = {}
for index, identity in ipairs(Ship.getShipPartIdentities()) do
	icons[identity.name] = identity.model
		 :copy("icon" .. identity.name)
		 :moveTo(SKULL_ROOT)
		 :setVisible(false)
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
				local partIcon = icons[name]
				if partIcon then
					local rot = client:getCameraRot()
					ICON:setVisible(false)
					partIcon
						 :setVisible(true)
						 :setRot(vec(0, -45 + rot.y, 0))
					lastVisible = partIcon
				end
			end
		end
	end)