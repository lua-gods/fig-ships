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
---@field interia Vector3
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
		interia = vec(1,1,1),
		id = id,
		debug = {},
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

function RigidBody:setInteria(x,y,z)
	local interia = GNCommon.vec3(x,y,z)
	self.interia = interia
	return self
end

local impulseLine = Line.new():setColor(0, 0, 1)

--- applies impulse force to angular velocty
function RigidBody:applyImpulse(x, y, z, fx, fy, fz)
	local lmat = self.mat:inverted()
	local pos = lmat:apply(GNCommon.vec3(x, y, z))
	local impulse = lmat:applyDir(GNCommon.vec3(fx, fy, fz))  -- transform direction too
	local dir = (pos):cross(impulse)
	local p = self:getPos()
	impulseLine:setAB(p, p+dir:normalized())
	local absorbed = 1 - ((dir:copy():div(4,1,4)):length() / impulse:length())
	absorbed = math.clamp(absorbed, 0.1, 0.9)
	self.lvel = self.lvel + self.mat:applyDir(impulse) * absorbed  -- back to world for lvel
	self.avel = self.avel + self.mat:applyDir(dir)
end

function RigidBody:getSpatialVelocity(lpos)
	local r = self.mat:applyDir(lpos)      -- local offset -> world space
	return self.lvel + self.avel:cross(r)  -- ω × r, all world space
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
	 :rot(0,-90,0)


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
		body.avel = body.avel * 0.999
		body.lvel = body.lvel * 0.999
		body.lvel = body.lvel - vec(0, 0.1, 0)
		
		-- for each corner of the cube
		for z = -2, 2, 4 do
			for y = -0.5, 0.5, 1 do
				for x = -2, 2, 4 do
					local offset = vec(x, y, z)
					local pos = body.mat:apply(offset)
					particles["end_rod"]:pos(pos):gravity(0):lifetime(20):velocity(0,0,0):spawn()
					local penetration = world.getHeight(pos.x,pos.z,"WORLD_SURFACE")
					local height = math.max(penetration, HEIGHT)
					if pos.y < height then
						body.avel = body.avel * 0.99
						body.lvel = body.lvel * 0.995
						local dir = body.mat:applyDir(0,(height-pos.y)*0.05,0)
						body:applyImpulse(pos.x, pos.y, pos.z, dir.x,dir.y,dir.z)
					end
				end
			end
		end

		local dmat = body.mat:copy()
		dmat.c4 = (dmat.c4.xyz * 16):augmented(1)
		if body.model then
			body.model:setMatrix(dmat)
		end
	end
end)

--[=[

local hitLine = Line.new():setColor(0, 1, 0)


local body = RigidBody.new(MODEL)
--body.mat:rotateY(120)
body:setLVel(0, 0, 0)
	 :setPos(0, HEIGHT+4, 0)
:setAVel(0.5, 0, 1, 1)




events.TICK:register(function()
	local pos = player:getPos():add(0, player:getEyeHeight())
	local dir = player:getLookDir()
	local hitPos, hitDir = body:raycast(pos, dir * 20)
	if hitPos then
		hitLine:setAB(hitPos, hitPos + hitDir)
	end
	--particles["end_rod"]:pos(hitPos):spawn():lifetime(0)
	if player:getSwingTime() == 1 then
		dir = dir * 10
		body:applyImpulse(hitPos.x, hitPos.y, hitPos.z, dir.x, dir.y, dir.z)
	end
	if CONTROLS.forward:isPressed() then
		local p = body:getPos()
		local v = body.mat:applyDir(0,0,1)
		body:applyImpulse(p.x,p.y,p.z, v.x, v.y, v.z)
	end
	if CONTROLS.left:isPressed() then
		local p = body.mat:apply(-1,0,0)
		local v = body.mat:applyDir(0,0,1)
		body:applyImpulse(p.x,p.y,p.z, v.x, v.y, v.z)
	end
	if CONTROLS.right:isPressed() then
		local p = body.mat:apply(1,0,0)
		local v = body.mat:applyDir(0,0,1)
		body:applyImpulse(p.x,p.y,p.z, v.x, v.y, v.z)
	end
end)


]=]

return RigidBody
