if host:isHost() then
	for key, value in pairs(listFiles("auto.host")) do
		require(value)
	end
else
	for key, value in pairs(listFiles("auto.remote")) do
		print(value)
		require(value)
	end
end