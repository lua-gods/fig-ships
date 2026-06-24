if not host:isHost() then return end

local world = models:newPart("world","WORLD")
world:scale(16,16,16)

local Circle = models.env.Ocean
:setVisible(false)

local Dome = models.env.Dome
:setVisible(false)


local OCEAN = world:newPart("ocean")
:light(0,15)

local LAYERS = 20
local LAYER_SCALE = 1
local SEA_SIZE = 128
local SEA_LEVEL = 103.9


local clrFrom = vectors.hexToRGB("#4FF1D6")
local clrTo = vectors.hexToRGB("rgb(0 22 11)")

local WHITE = textures
:newTexture("1x1white",1,1):setPixel(0,0,vec(1,1,1))

local WHITE_OVERLAY = textures
:newTexture("1x1white_overlay",1,1):setPixel(0,0,vec(1,1,1,0.5))

local OVERLAY = models:newPart("overlay","WORLD")
--:setMatrix(matrices.mat4(
--	vec(1,0,0,0),
--	vec(0,1,0,0),
--	vec(0,0,1,0),
--	vec(0,0,0,0)
--))
local SCREEN = OVERLAY:newPart("camera","NONE")


for i = 1, 20, 1 do
	Dome:copy("dome")
	:moveTo(SCREEN)
	:setOpacity(0.15)
	:scale(i)
	:setColor(math.lerp(clrTo,clrFrom,i/20))
	:setPrimaryRenderType("CUTOUT_EMISSIVE_SOLID")
	:setVisible(true)
end

local R = 1/LAYERS


for i = 1, LAYERS, 1 do
	local model = Circle:copy("layer"..i)
	model
	:setPrimaryTexture("CUSTOM",WHITE)
	:pos(0,(-i+1)*LAYER_SCALE+SEA_LEVEL,0)
	:setUV(5,5)
	:setVisible(true)
	:light(0,15)
	:scale(SEA_SIZE)
	
	if i == 1 then
		model
		:setColor(clrFrom)
		:setOpacity(6*R)
	else
		model
		:setColor(clrTo)
		:setOpacity(4*R)
	end
	
	OCEAN:addChild(model)
	
	--OCEAN:newSprite("layer"..i)
	--:texture(white,1,LAYERS)
	--:pos(SEA_SIZE*0.5,-i*LAYER_SCALE+SEA_LEVEL,SEA_SIZE*0.5)
	--:rot(90,0,0)
	--:scale(SEA_SIZE,SEA_SIZE/LAYERS,0)
	--:setRegion(1,1)
	--:setUVPixels(1,LAYERS-i)
	
end

local wasInWater = false
local ambient
events.WORLD_RENDER:register(function (delta)
	local pos = client:getCameraPos()
	local height = pos.y-SEA_LEVEL
	OCEAN
	:setPos(pos.x_z)
	if height > 0 then
		OVERLAY:setVisible(false)
		OCEAN:setVisible(true)
		if wasInWater then
			wasInWater = false
			sounds:playSound("minecraft:ambient.underwater.exit",pos)
			if ambient then
				ambient:stop()
				ambient = nil
			end
		end
	else
		if not wasInWater then
			wasInWater = true
			ambient = sounds:playSound("minecraft:ambient.underwater.loop",pos):loop(true)
			sounds:playSound("minecraft:ambient.underwater.enter",pos)
		end
		textures["env.dome"]:applyFunc(0,0,1,64,function (col, x, y)
			local v = (-height*0.5-0.5+y/64)
			if v > 0 then
				return math.lerp(clrFrom,clrTo,math.min((v*0.05)^0.8,1)):augmented(1)
			else
				return vec(1,1,1,0)
			end
		end)
		:update()
		OVERLAY:setVisible(true)
		OCEAN:setVisible(false)
	end
	OVERLAY:pos(pos*16)
	
end)

local zoom = 0.5
