SEA_LEVEL = 103.9

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
