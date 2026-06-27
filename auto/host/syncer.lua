local Sync = require("lib.GNSync")

local SYNC_TIME = 5



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

local packTimer = 0
	events.TICK:register(function ()
		packTimer = packTimer - 1
		if packTimer < 0 then
			Sync.ship = toBase64(SHIP:packData())
			if BODY then
				local axis1 = BODY.mat.c1.xyz
				local axis2 = BODY.mat.c2.xyz
				local pos = (BODY.mat:apply(-BODY.center)*4):floor()/4
				Sync.axis = {axis1.x, axis1.y, axis1.z, axis2.x, axis2.y, axis2.z,pos.x, pos.y, pos.z}
			end
			packTimer = SYNC_TIME
		end
	end)