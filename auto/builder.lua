local PARTS = {}
for index, child in ipairs(models.ship.Parts:getChildren()) do
	local id = child:getName()
	local pivot = child:getPivot()
	PARTS[id] = {
		id = id,
		model = models:newPart(id):remove():addChild(child:setPos(-pivot):remove()),
	}
end

local function spawnPart(id)
	local part = PARTS[id]
	if not part then return end
	models:addChild(part.model:copy("ee"))
end