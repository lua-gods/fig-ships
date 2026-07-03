---@diagnostic disable: missing-fields

local GNCommon = require("lib.GNcommon")
local KEYBINDS = require("auto.host.keybinds")
local zLib = require("lib.zlib")

local SHIP_SCALE = 8
local THROTTLE_STRENGTH = 0.001
local STEER_STRENGTH = 0.0003
local PROPELLER_STRENGTH = 0.8

---@param string string
---@return string
local function parseBase64(string)
	local buffer = data:createBuffer(#string)
	local ok, result = pcall(buffer.writeBase64, buffer, string)
	if not ok then return "" end
	buffer:setPosition(0)
	local out = buffer:readByteArray(buffer:available())
	buffer:close()
	return out
end


---@param string string
---@return string
local function toBase64(string)
	local buffer = data:createBuffer(#string)
	local ok, result = pcall(buffer.writeByteArray, buffer, string)
	if not ok then return "" end
	buffer:setPosition(0)
	local out = buffer:readBase64(buffer:available())
	buffer:close()
	return out
end

local fan = 0
local activatedThrusters = {}

---@type table<string,Ship.Part.Identity>
local PARTS_ENTRY = {
	["Front Hull"] = {},
	["Hull"] = {},
	["Back Hull"] = {
		process = function (part, ship, body)
			local pos = part.model:partToWorldMatrix():apply()
			if pos.y <= getSeaLevel(pos) then
				if KEYBINDS.forward:isPressed() then
					local p = body:getPos()
					local v = body.mat:applyDir(0, 0, -THROTTLE_STRENGTH * ((#body.points) ^ 2))
					body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
				end
				if KEYBINDS.back:isPressed() then
					local p = body:getPos()
					local v = body.mat:applyDir(0, 0, THROTTLE_STRENGTH * ((#body.points) ^ 2))
					body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
				end
				if KEYBINDS.left:isPressed() then
					local speed = body.mat:copy():invert():applyDir(body.lvel)
					local up = body.mat:applyDir(0, 1, 0)
					body:setAVel(up,-speed.z*STEER_STRENGTH)
				end
				if KEYBINDS.right:isPressed() then
					local speed = body.mat:copy():invert():applyDir(body.lvel)
					local up = body.mat:applyDir(0, 1, 0)
					body:setAVel(up,speed.z*STEER_STRENGTH)
				end
			end
		end,
		desc="Lets you throttle and steer your ship!"
	},

	["Control Room"] = {
		desc="does nothing"
	},

	["Accommodation Floor 2"] = {},
	["Accommodation Floor 1"] = {},

	["Funnel"] = {},
	["Core Hull"] = {
		locked = true,
	},

	["Cannon"] = {},
	["Schwerer Gustav"] = {},
	["Propeller Fan"] = {
		process = function (part, ship, body)
			if KEYBINDS.up:isPressed() then
				local up = body.mat:applyDir(0, PROPELLER_STRENGTH, 0)
				local pos = part.model:partToWorldMatrix():apply()
				body:applyImpulse(pos.x,pos.y,pos.z,up.x,up.y,up.z)
				fan = fan + 1
				part.model["Propeller Fan"].wings:setRot(0,fan * 5,0)
			end
		end,
		desc="press [Space] to activate the propeller fan and lift off!"
	},
	["Thruster"] = {
		process = function (part, ship, body)
			if KEYBINDS.forward:isPressed() then
				local mat = part.model:partToWorldMatrix()
				local pos = mat:apply(0,8,0)
				local dir = mat:applyDir(0,0,-10)
				if not activatedThrusters[part.id] then
					activatedThrusters[part.id] = true
        			sounds["item.firecharge.use"]:pos(pos):volume(0.2):pitch(0.4):attenuation(8):play()
        			sounds["item.firecharge.use"]:pos(pos):volume(0.2):pitch(0.3):attenuation(8):play()
        			sounds["item.firecharge.use"]:pos(pos):volume(0.2):pitch(0.2):attenuation(8):play()
        			sounds["item.firecharge.use"]:pos(pos):volume(0.2):pitch(0.15):attenuation(8):play()
        			sounds["item.firecharge.use"]:pos(pos):volume(0.2):pitch(0.1):attenuation(8):play()
				end
				particles["end_rod"]:pos(pos):velocity(-dir):lifetime(10):setColor(vectors.hexToRGB("#FFD986")):scale(30):spawn()
				body:applyImpulse(pos.x,pos.y,pos.z,dir.x,dir.y,dir.z)
			else
				activatedThrusters[part.id] = nil
			end
		end
	}
}

local SHIP_PARTS = {}

local PAINT_BLOCKS = {}
for index, id in ipairs(client.getRegistry("minecraft:block")) do
	local id = id:match("minecraft:(.*)")
	if id and id:find("concrete") or id:find("wool") or id:find("teracotta") or id:find("glazed") then
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
---@field paint integer

--────  PARSING  ────────────────────────────────────────────────────────--

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

	local parts = PARTS_ENTRY[name] or {}


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
	if identity and not self:isOccupied(pos.x, pos.y, pos.z) then
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
			paint = 0,
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
	if PAINT_BLOCKS[index] then
		local tex = world.newBlock(PAINT_BLOCKS[index]):getTextures()
		local path = tex[next(tex)]
		path = path[1]
		part.model:setPrimaryTexture("RESOURCE", path .. ".png")
		part.paint = index
	else
		part.model:setPrimaryTexture("PRIMARY")
		part.paint = 0
	end
	return self
end

---@return Ship
function Ship:recalculateHitbox()
	self.hitbox = {}
	for id, part in pairs(self.parts) do
		local mat = matrices.mat4()
		mat:scale(SHIP_SCALE)
		mat:translate(SHIP_SCALE * 0.5,0,SHIP_SCALE * 0.5)
		mat:rotate(0, part.rot * 90, 0)
		mat:translate(-SHIP_SCALE * 0.5,0,-SHIP_SCALE * 0.5)
		mat:translate(part.pos * SHIP_SCALE)

		local bounds = part.identity.bounds

		local a = mat:apply(bounds.min) / 16
		local b = mat:apply(bounds.max) / 16
		local min = vec(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
		local max = vec(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
		
		self.hitbox[id] = {
			min,
			max
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
	for index, part in pairs(self.parts) do
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
		buffer:write(part.pos.y*4)
		buffer:write(part.pos.z+128)
		buffer:write(part.rot)
		buffer:write(part.paint)
	end
	buffer:setPosition(0)
	local out = buffer:readByteArray()
	
	out = zLib.Deflate.Compress(out)
	buffer:close()
	return toBase64(out)
end

function Ship:unpackData(packedData)
	self:demolish()
	packedData = parseBase64(packedData)
	packedData = zLib.Deflate.Decompress(packedData)
	local buffer = data:createBuffer()
	buffer:writeByteArray(packedData)
	buffer:setPosition(0)
	for i = 1, 1024, 1 do
		local id = buffer:read()
		if id then
			local x = buffer:read()-128
			local y = buffer:read()/4
			local z = buffer:read()-128
			local rot = buffer:read()
			local paint = buffer:read()
			local part = self:newPart(id, vec(x, y, z), rot)
			if part then
				self:paintPart(part.id, paint)
			end
		end
	end
	buffer:close()
end

return ShipAPI
