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

---@type table<any,Ship>
local shipCache = {}

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
			elseif name:find("^ship;") then
				local data = name:sub(6,-1)
				if not shipCache[data] then
					local ship = Ship.new()
					ship:unpackData(data)
					ship.model:setParentType("SKULL")
					shipCache[data] = ship
					ship.model:setVisible(true)
					
					--- calculate radius
					local min = vec(YOUR_MOM, YOUR_MOM, YOUR_MOM)
					local max = vec(-YOUR_MOM, -YOUR_MOM, -YOUR_MOM)
					for index, part in ipairs(ship.hitbox) do
						min.x = math.min(min.x, part[1].x)
						min.y = math.min(min.y, part[1].y)
						min.z = math.min(min.z, part[1].z)
						max.x = math.max(max.x, part[2].x)
						max.y = math.max(max.y, part[2].y)
						max.z = math.max(max.z, part[2].z)
					end
					min = min / ship.scale
					max = max / ship.scale
					
					local diameter = (min-max):length()
					ship.model:scale(0.4/diameter)
					lastVisible = ship.model
				else
					local ship = shipCache[data]
					ship.model:setVisible(true)
					lastVisible = ship.model
				end
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