local Macros = require("lib.GNMacros")



local function namedHead(name)
	local u1, u2, u3, u4 = client.uuidToIntArray(player:getUUID())
	local item =
	[=[minecraft:player_head[profile={id:[I;%s,%s,%s,%s]},custom_name='{"text":"%s"}']]]=]
	item = item:format(u1, u2, u3, u4, name)
	return item
end


local function fancyTitle(title, desc)
	return toJson {
		{
			color = "gray",
			text = "",
		},
		{
			text = title,
			color = "white",
			bold = true,
		},
		{
			text = "\n" .. desc,
		},
	}
end


return Macros.new(function (events, ...)
	local page = action_wheel:newPage("Home")
	
	local gn = {
		{text=":@gn:"},
		{color="#c3f278",text="G"},
		{color="#b3e873",text="N"},
		{color="#a3de6e",text="ᴀ"},
		{color="#93d469",text="ɴ"},
		{color="#83ca64",text="ɪ"},
		{color="#73c05f",text="ᴍ"},
		{color="#63b65a",text="ᴀ"},
		{color="#53ac55",text="ᴛ"},
		{color="#43a250",text="ᴇ"},
		{color="#33984b",text="ѕ"}}
	
	local function newAction(color,title,description)
		local desc
		if type(description) == "string" then
			desc = {
				text = description,
				color = "gray",
				bold = false
			}
		else
			desc = description
		end
		
		local action = page:newAction()
		:hoverColor(vectors.hexToRGB(color))
		:setTitle(toJson{
			{
				text = "",
				color = "gray",
			},
			{
				text = title,
				color = color,
				bold=true,
			},
			{text = "\n"},
			description
		})
		return action
	end
	
	newAction("#9097D4",":mci_mace: Build a Ship :mci_mace:","Create a warship")
	:item("minecraft:mace")
	:onLeftClick(function (self)
		setScreen("builder")
	end)
	
	newAction("#FCDC45",":mci_blaze_powder: Spawn a Ship :mci_blaze_powder:","Create a warship")
	:item("minecraft:blaze_powder")
	
	
	
	newAction("#ffffff",":mci_iron_sword: BATTLESHIP :mci_iron_sword:",
	{
		text = "",
		extra = {
			{
				text = '"Noah get the boat, we got a city to burn"\n\n',
			},
			{
				text = ":new_leaf: Created By: ",
				extra = gn,
			},
			{
				text = "\n:banana_rotata_y: Figura Contest 2026 Submission"
			}
		}
	}
	
	
	
	)
	:item("minecraft:paper")
	
	
	---@type table<integer,{[1]:Minecraft.soundID,[2]:number}>
	local SOUNDS = {
		{"minecraft:block.piston.extend",0.75,0.25},
		{"minecraft:item.firecharge.use",0.75,0.3},
		{"minecraft:item.book.page_turn",1,1.2},
	}
	
	local currentPlaying
	
	
	
	local function playSound(id,pitch,volume)
		local instance = sounds[id]
		:pos(client:getCameraPos()+client:getCameraDir())
		:pitch(pitch or 1)
		:volume(volume or 1)
		:play()
		currentPlaying = instance
	end
	
	local lid = nil
	events.WORLD_RENDER:register(function (delta)
		if action_wheel:isEnabled() then -- for some reason this plays without this check
			local id = action_wheel:getSelected() -- this method is buggy
			if lid ~= id then
				lid = id
				if currentPlaying then
					currentPlaying:stop()
					currentPlaying = nil
				end
				local soundid = SOUNDS[id]
				if soundid then
					playSound(table.unpack(soundid))
				end
			end
		end
	end)
	
	action_wheel:setPage(page)
end)