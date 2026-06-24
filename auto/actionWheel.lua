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

newAction("#9097D4","Build a Ship","Create a warship")
:item("minecraft:mace")

newAction("#FCDC45","Spawn a Ship","Create a warship")
:item("minecraft:blaze_powder")



newAction("#ffffff","BATTLESHIP",
{
	text = "",
	extra = {
		{
			text = "Noah get the boat, we got a city to burn \n\n",
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
	local id = action_wheel:getSelected()
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
end)

action_wheel:setPage(page)