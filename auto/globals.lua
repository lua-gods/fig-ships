SEA_LEVEL = 103.9
SHIP_SAVE_PATH = "GNShips"
SHIP_SAVE_EXTENSION = ".gnws"
-- height from the ground/sea
SEA_MARGIN = 5
YOUR_MOM = math.huge -- coconut



events.ENTITY_INIT:register(function ()
	local u1, u2, u3, u4 = client.uuidToIntArray(player:getUUID())
if client.compareVersions(client:getVersion(), "1.20.6") >= 0 then
	function namedHead(name)
		local item =
		[=[minecraft:player_head[profile={id:[I;%s,%s,%s,%s]},custom_name='{"text":"%s"}']]]=]
		item = item:format(u1, u2, u3, u4, name)
		return item
	end
else
	function namedHead(name)
		local item =
		[=[minecraft:player_head{SkullOwner:{Id:[I;%s,%s,%s,%s]},display:{Name:'{"text":"%s"}'}}]=]
		item = item:format(u1, u2, u3, u4, name)
		return item
	end
end
end)


function getSeaLevel(pos)
	return math.max(SEA_LEVEL, world.getHeight(pos.x,pos.z, "WORLD_SURFACE"))
end