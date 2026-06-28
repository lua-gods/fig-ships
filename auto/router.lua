if host:isHost() then
	events.ENTITY_INIT:register(function()
		
		for key, value in pairs(listFiles("auto.host.utils")) do
			require(value)
		end
		
		for key, value in pairs(listFiles("auto.host")) do
			require(value)
		end
	end)
else
	for key, value in pairs(listFiles("auto.remote")) do
		print(value)
		require(value)
	end
end
