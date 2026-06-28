local nbs = require("lib.nbs")
local MacrosAPI = require("lib.GNMacros")
local MusicPlayer = nbs.newMusicPlayer()


local track = nbs.loadFromPath("bad")
track.loop = true
local macro =  MacrosAPI.new(function(events, ...)
	config:setName("GN.ship")
	config:save("music", true)
	MusicPlayer
		 :setTrack(track)
		 :play()
		 :setVolume(0.7)

	events.WORLD_RENDER:register(function(delta)
		MusicPlayer
			 :setPos(client:getCameraPos() + client:getCameraDir())
			 :setAttenuation(67)
	end)
	events.ON_EXIT:register(function ()
		config:setName("GN.ship")
		config:save("music", false)
		MusicPlayer:stop()
	end)
end)

return macro