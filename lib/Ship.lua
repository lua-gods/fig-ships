---@diagnostic disable: missing-fields

local SHIP_SCALE = 8
local GNCommon = require("lib.GNcommon")

local THROTTLE_STRENGTH = 2
local STEER_STRENGTH = 0.04

local KEYBINDS = require("auto.host.keybinds")

local zLib = require("lib.zlib")

---@type table<string,Ship.Part.Identity>
local PARTS_ENTRY = {
	["Front Hull"] = {},
	["Hull"] = {},
	["Back Hull"] = {
		process = function (part, ship, body)
			if KEYBINDS.forward:isPressed() then
			local p = body:getPos()
			local v = body.mat:applyDir(0, 0, -THROTTLE_STRENGTH)
			body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
		end
		if KEYBINDS.left:isPressed() then
			local p = body.mat:apply(-(#body.points)^1.5*STEER_STRENGTH, 0, 0)
			local v = body.mat:applyDir(0, 0, 1)
			body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
		end
		if KEYBINDS.right:isPressed() then
			local p = body.mat:apply((#body.points)^1.5*STEER_STRENGTH, 0, 0)
			local v = body.mat:applyDir(0, 0, 1)
			body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
		end
		end
	},

	["Control Room"] = {},

	["Accommodation Floor 2"] = {},
	["Accommodation Floor 1"] = {},

	["Funnel"] = {},
	["Core Hull"] = {
		locked = true,
	},

	["Cannon"] = {},
	["Schwerer Gustav"] = {},
}

local SHIP_PARTS = {}


local PAINT_BLOCKS = {}
for index, id in ipairs(client.getRegistry("minecraft:block")) do
	local id = id:match("minecraft:(.*)")
	if id:find("concrete") or id:find("wool") or id:find("teracotta") or id:find("glazed") then
		local block = world.newBlock(id)
		if block:isOpaque() and block:isSolidBlock() then
			PAINT_BLOCKS[#PAINT_BLOCKS + 1] = id
		end
	end
end
table.sort(PAINT_BLOCKS)


--────  TYPINGS  ────────────────────────────────────────────────────────--

---@class ShipAPI
local ShipAPI = {}


---@class Ship
---@field model ModelPart
---@field models ModelPart[]
---@field parts Ship.Part[]
---@field spatial table<string,Ship.Part>
---@field scale number
---@field hitbox {min:Vector3, max:Vector3}[]
local Ship = {}
Ship.__index = Ship


---@class Ship.Part.Identity
---@field id integer
---@field locked boolean?
---@field name string
---@field model ModelPart
---@field skullIcon ModelPart
---@field bounds {min:Vector3, max:Vector3}?
---@field studs {pos:Vector3, rot:Vector3}[]
---@field desc string?
---@field process fun(part:Ship.Part, ship:Ship,body: GN.RigidBody)?


---@class Ship.Part
---@field id integer
---@field identity Ship.Part.Identity
---@field pos Vector3
---@field rot integer
---@field model ModelPart
---@field paint Minecraft.blockID

--────  PARSING  ────────────────────────────────────────────────────────--

local YOUR_MOM = math.huge

local SKULL_ROOT = models:newPart("SkullRoot", "SKULL")
for index, model in ipairs(models.ship.Parts:getChildren()) do
	local name = model:getName()
	local offset = model:getPivot()

	local bounds
	if model.Selection then
		local sel = model.Selection
		local min = vec(YOUR_MOM, YOUR_MOM, YOUR_MOM)
		local max = vec(-YOUR_MOM, -YOUR_MOM, -YOUR_MOM)
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

	local parts = PARTS_ENTRY[name]


	SHIP_PARTS[index] = parts
	parts.id = index
	parts.name = name
	parts.model = models:newPart(name)
		 :remove()
		 :addChild(
			 model
			 :setPos(-offset)
			 :remove()
		 )
	parts.skullIcon = skullIcon
	parts.studs = {}
	parts.bounds = bounds
end

---@return Ship
function ShipAPI.new()
	local self = {
		parts = {},
		spatial = {},
		model = models:newPart("Ship" .. client.intUUIDToString(client:generateUUID()), "WORLD"),
		models = {},
		scale = SHIP_SCALE,
		hitbox = {},
	}
	setmetatable(self, Ship)
	return self
end

---@return Ship.Part.Identity[]
function ShipAPI.getShipPartIdentities()
	return SHIP_PARTS
end

---@return Minecraft.blockID[]
function ShipAPI.getPaintBlocks()
	return PAINT_BLOCKS
end

---@param id integer
---@param pos Vector3?
---@param rot integer?
---@return Ship.Part?
function Ship:newPart(id, pos, rot)
	pos = pos or vec(0, 0, 0)
	rot = rot or 0
	local identity = SHIP_PARTS[id]
	if identity then
		local id = #self.parts + 1

		---@type Ship.Part
		local part = {
			id = id,
			identity = identity,
			pos = pos:floor(),
			rot = math.floor(rot),
			model = identity.model:copy("Part" .. id):moveTo(self.model)
				 :setPos(pos * SHIP_SCALE)
				 :setScale(SHIP_SCALE)
				 :setRot(0, rot * 90, 0),
			paint = nil,
		}

		self.parts[id] = part
		self.spatial[pos:toString()] = part
		self:recalculateHitbox()
		return part
	end
end

---@param id integer
function Ship:removePart(id)
	local part = self.parts[id]
	if part then
		part.model:remove()
		self.spatial[part.pos:toString()] = nil
		table.remove(self.parts, id)
	end
	self:realizeInstances()
	self:recalculateHitbox()
	return self
end

---@return Ship
function Ship:realizeInstances()
	local i = 0
	for id, part in pairs(self.parts) do
		i = i + 1
		part.id = i
	end
	return self
end

function Ship:paintPart(id, index)
	local part = self.parts[id]
	if not part then return end
	part.paint = PAINT_BLOCKS[index]
	if part.paint then
		local tex = world.newBlock(part.paint):getTextures()
		local path = tex[next(tex)]
		path = path[1]
		part.model:setPrimaryTexture("RESOURCE", path .. ".png")
	else
		part.model:setPrimaryTexture("PRIMARY")
	end
	return self
end

---@return Ship
function Ship:recalculateHitbox()
	self.hitbox = {}
	for id, part in pairs(self.parts) do
		local mat = matrices.mat4()
		mat:scale(SHIP_SCALE)
		mat:rotate(0, part.rot * 90, 0)
		mat:translate(part.pos * SHIP_SCALE)

		local bounds = part.identity.bounds

		self.hitbox[id] = {
			mat:apply(bounds.min) / 16,
			mat:apply(bounds.max) / 16,
		}
	end
	return self
end

---@overload fun(self:Ship, pos: Vector3): boolean
---@param x number
---@param y number
---@param z number
---@return boolean
function Ship:isOccupied(x, y, z)
	local pos = GNCommon.vec3(x, y, z)
	return self.spatial[pos:toString()] and true or false
end

function Ship:refreshModel()
	for index, value in ipairs(self.model:getChildren()) do
		value:remove()
	end

	for index, part in ipairs(self.parts) do
		part.model:moveTo(self.model)
			 :rot(0, part.rot * 90, 0)
			 :pos(part.pos)
	end
end

function Ship:demolish()

	for index, part in ipairs(self.parts) do
		part.model:remove()
	end
	self.parts = {}
	self.spatial = {}

	return self
end

function Ship:packData()
	local buffer = data:createBuffer()
	for index, part in ipairs(self.parts) do
		buffer:write(part.identity.id)
		buffer:write(part.pos.x+128)
		buffer:write(part.pos.y)
		buffer:write(part.pos.z+128)
		buffer:write(part.rot)
		local paint = part.paint or ""
		buffer:write(#paint)
		buffer:writeString(paint,"ascii")
	end
	buffer:setPosition(0)
	local out = buffer:readByteArray()
	out = zLib.Deflate.Compress(out)
	buffer:close()
	return out
end

function Ship:unpackData(packedData)
	self:demolish()
	packedData = zLib.Deflate.Decompress(packedData)
	local buffer = data:createBuffer()
	buffer:writeByteArray(packedData)
	buffer:setPosition(0)
	for i = 1, 1024, 1 do
		local id = buffer:read()
		if id then
			local x = buffer:read()-128
			local y = buffer:read()
			local z = buffer:read()-128
			local rot = buffer:read()
			local len = buffer:read()
			local paint = buffer:readString(len,"ascii")
			local part = self:newPart(id, vec(x, y, z), rot)
			if #paint > 0 then
				self:paintPart(part.id, paint)
			end
		end
	end
	buffer:close()
end

return ShipAPI
