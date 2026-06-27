local Ship = require("lib.Ship")
local Sync = require("lib.GNSync")

local ship = Ship.new()
ship:newPart(1)
ship.model:setParentType("WORLD")


local historyTime = {}
local lastTime = client:getSystemTime()
local lastHash
local averageTime = 0
local lastMat
local mat

local BLEND_MAT = 3

local finalMat

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


local lastSystemTime = client:getSystemTime()
local lastShip

local points = {}
events.RENDER:register(function(_, ctx, matrix)
	if ctx == "RENDER" then
		local time = client:getSystemTime()
		local delta = (time - lastSystemTime) / 1000
		lastSystemTime = time


		if Sync.axis then
			if Sync.ship ~= lastShip then
				ship:unpackData(parseBase64(Sync.ship))
				lastShip = Sync.ship

				points = {}
				
				local i = 0
				local center = vec(0, 0, 0)
				for index, aabb in ipairs(ship.hitbox) do
					for z = aabb[1].z, aabb[2].z, 8 do
						for y = aabb[1].y, aabb[2].y, 8 do
							for x = aabb[1].x, aabb[2].x, 8 do
								i = i + 1
								local pos = vec(x, y, z)
								points[i] = pos
								center = center + pos
							end
						end
					end
				end
			end

			local hash = printTable(Sync.axis, 1, true)
			if lastHash ~= hash then
				local timeSinceLast = time - lastTime
				table.insert(historyTime, 1, timeSinceLast)
				if #historyTime > 10 then
					table.remove(historyTime, 11)
				end

				for index, data in ipairs(historyTime) do
					averageTime = averageTime + data
				end
				averageTime = averageTime / #historyTime
				lastTime = time
				lastHash = hash
				local axis1 = vec(Sync.axis[1], Sync.axis[2], Sync.axis[3])
				local axis2 = vec(Sync.axis[4], Sync.axis[5], Sync.axis[6])
				local pos = vec(Sync.axis[7], Sync.axis[8], Sync.axis[9])
				lastMat = mat
				mat = matrices.mat4()
				mat.c1 = axis1:augmented(0)
				mat.c2 = axis2:augmented(0)
				mat.c3 = (axis1:copy():cross(axis2)):augmented(0)
				mat:translate(pos * 16)

			end
		end
		if lastMat and mat then
			local time = client:getSystemTime()
			local timeSinceLast = (time - lastTime) / averageTime
			local slideMat = math.lerp(lastMat, mat, timeSinceLast)
			
			local lastFinalMat = finalMat and finalMat:copy()
			finalMat = finalMat and math.lerp(finalMat, slideMat, BLEND_MAT * delta) or slideMat:copy()
			
			if lastFinalMat and finalMat then
				for index, value in ipairs(points) do
					local pos = finalMat:apply(value * 16)
					local height = math.max(pos.y/16, SEA_LEVEL)
					local lvel = (finalMat:apply(pos)-lastFinalMat:apply(pos)) / 16
					if SEA_LEVEL+1 >= height then
						if lvel:length() > 0.5 then
							particles["end_rod"]:pos(pos.x/16,height,pos.z/16):gravity(0.1):lifetime(40):scale(8):velocity(lvel * 0.04 + vec(math.random()-0.5,0,math.random()-0.5)*0.4):spawn()
						end
					end
				end
			end
			
			

			ship.model:setMatrix(finalMat)
		end
	end
end)
