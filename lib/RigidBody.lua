--[[______   __
  / ____/ | / / Name: GN SHITTY RIGID BODY LIBRARY v1.0.0
 / / __/  |/ /  Desc: rigid body library made without researching how tf these work
(please dont use this)
/ /_/ / /|  / Author: GNanimates | https://gnon.top | @gn68s
\____/_/ |_/ License: Mozilla Public License Version 2.0
--────────-< DEPENDENCIES >-────────--
Place required dependencies in the same folder as this script.
- DEPENDENCY > LINK
]]

---@diagnostic disable: param-type-mismatch
local GNCommon = require("lib.GNcommon")
local Line = require("lib.GNLine")

local HEIGHT = 104
local KEYBINDS = require("auto.keybinds")

local face2dir = {
	["north"] = vec(0, 0, -1),
	["east"]  = vec(1, 0, 0),
	["south"] = vec(0, 0, 1),
	["west"]  = vec(-1, 0, 0),
	["up"]    = vec(0, 1, 0),
	["down"]  = vec(0, -1, 0),
}



---@class GN.RigidBody
---@field model ModelPart
---@field mass number
---@field intertia Vector3
---@field center Vector3
---@field lvel Vector3
---@field avel Vector3
---@field mat Matrix4
---@field debug table
---@field size Vector3
---@field points Vector3[]
local RigidBody = {}
RigidBody.__index = RigidBody

---@type GN.RigidBody[]
local rigidBodies = {}

---@param model ModelPart?
---@return GN.RigidBody
function RigidBody.new(model)
	local id = #rigidBodies + 1
	local self = {
		model = model,
		mass = 0,
		intertia = vec(0, 0, 0),
		center = vec(0, 0, 0),
		lvel = vec(0, 0, 0),
		avel = vec(0, 0, 0),
		mat = matrices.mat4(),
		size = vec(1, 1, 1),
		id = id,
		debug = {},
		points = {},
	}

	self.debug.axis = Line.new():setColor(1, 0.5, 0)
	setmetatable(self, RigidBody)
	rigidBodies[id] = self
	return self
end

function RigidBody:setLVel(x, y, z)
	local vel = GNCommon.vec3(x, y, z)
	self.lvel = self.lvel + vel
	return self
end

function RigidBody:setPos(x, y, z)
	local pos = GNCommon.vec3(x, y, z)
	self.mat.c4 = pos:augmented(1)
	return self
end

function RigidBody:getPos()
	return self.mat.c4.xyz
end

function RigidBody:setAVel(x, y, z, l)
	local vel = GNCommon.vec4(x, y, z, l)
	if vel.xyz:length() > 0.00001 then
		vel = vel.xyz:normalized() * vel.w
		self.avel = self.avel + vel
	end
	return self
end

function RigidBody:setInteria(x, y, z)
	local interia = GNCommon.vec3(x, y, z)
	self.size = interia
	return self
end

local impulseLine = Line.new():setColor(0, 0, 1)

--- applies impulse force to angular velocty
function RigidBody:applyImpulse(x, y, z, fx, fy, fz)
	local lmat = self.mat:inverted()
	local pos = lmat:apply(GNCommon.vec3(x, y, z))
	local impulse = lmat:applyDir(GNCommon.vec3(fx, fy, fz)):div(self.size) -- transform direction too
	local dir = (pos):cross(impulse)
	local p = self:getPos()
	impulseLine:setAB(p, p + dir:normalized())
	local absorbed = 1 - ((dir / self.size):length() / impulse:length())
	absorbed = math.clamp(absorbed, 0.1, 0.9)
	self.lvel = self.lvel + self.mat:applyDir(impulse) * absorbed -- back to world for lvel
	self.avel = self.avel + self.mat:applyDir(dir) / ((#self.points) ^ 2) -- not a magic number truet
end

function RigidBody:getSpatialVelocity(lpos)
	local r = self.mat:applyDir(lpos)   -- local offset -> world space
	return self.lvel + self.avel:cross(r) -- ω × r, all world space
end

---@param pos Vector3
---@param dir Vector3
function RigidBody:raycast(pos, dir)
	local mat = self.mat
	local lmat = self.mat:inverted()
	local aabb, hitpos, side, index = raycast:aabb(
		lmat:apply(pos),
		lmat:apply(pos + dir),
		{
			{
				vec(-0.5, -0.5, -0.5),
				vec(0.5, 0.5, 0.5),
			},
		}
	)
	local hitDir = mat:applyDir(face2dir[side])
	return mat:apply(hitpos), hitDir
end

-- ignore this
local MODEL = models:newPart("boat", "WORLD")
MODEL:newBlock("display")
	 :block("minecraft:furnace")
	 :pos(8, -8, -8)
	 :rot(0, -90, 0)


local ltime = client:getSystemTime()
events.WORLD_RENDER:register(function()
	local time = client:getSystemTime()
	local delta = (time - ltime) / 1000
	ltime = time
	for id, body in pairs(rigidBodies) do
		body.mat
			 :translate(body.lvel * delta)

		local angle = math.deg(body.avel:length()) * delta
		local axis = body.avel:normalized()
		if angle > 0 then
			body.mat.c1 = vectors.rotateAroundAxis(angle, body.mat.c1.xyz, axis):augmented(0)
			body.mat.c2 = vectors.rotateAroundAxis(angle, body.mat.c2.xyz, axis):augmented(0)
			body.mat.c3 = vectors.rotateAroundAxis(angle, body.mat.c3.xyz, axis):augmented(0)
		end

		if body.debug.axis then
			local a = body.mat.c4.xyz - body.avel * 2
			local b = body.mat.c4.xyz + body.avel * 2
			body.debug.axis:setAB(a, b)
		end
		
		body.lvel = body.lvel - vec(0, 0.1, 0)
		local collided = false
		for index, pos in ipairs(body.points) do
			local pos = body.mat:apply(pos)
			local _, hitpos = raycast:block(pos + vec(0, 8, 0), pos.x_z)
			local height = math.max(hitpos.y, HEIGHT)
			if pos.y < height then
				collided = true
				local dir = body.mat:applyDir(0, (height - pos.y) * 0.08, 0)
				body:applyImpulse(pos.x, pos.y, pos.z, dir.x, math.abs(dir.y), dir.z)
				particles["end_rod"]:pos(pos.x,height,pos.z):gravity(0):lifetime(20):scale(8):velocity(0, 0, 0):spawn()
			end

			local dmat = body.mat:copy()
			dmat.c4 = (dmat.c4.xyz * 16):augmented(1)
			if body.model then
				body.model:setMatrix(dmat)
			end
		end
		if collided then
			body.avel = body.avel * 0.99
			body.lvel = body.lvel * 0.99
		else
			body.avel = body.avel * 0.999
			body.lvel = body.lvel * 0.999
		end
		
		if KEYBINDS.forward:isPressed() then
			local p = body:getPos()
			local v = body.mat:applyDir(0, 0, -5)
			body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
		end
		if KEYBINDS.left:isPressed() then
			local p = body.mat:apply(-(#body.points)^1.5, 0, 0)
			local v = body.mat:applyDir(0, 0, 1)
			body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
		end
		if KEYBINDS.right:isPressed() then
			local p = body.mat:apply((#body.points)^1.5, 0, 0)
			local v = body.mat:applyDir(0, 0, 1)
			body:applyImpulse(p.x, p.y, p.z, v.x, v.y, v.z)
		end
	end
end)
--[ [

local hitLine = Line.new():setColor(0, 1, 0)




events.TICK:register(function()
	--particles["end_rod"]:pos(hitPos):spawn():lifetime(0)
end)


--]]

return RigidBody
