---@diagnostic disable: assign-type-mismatch
--[[______   __
  / ____/ | / / Name: GN TWEEN LIBRARY v2.0.0
 / / __/  |/ /  Desc: A simple tween library
/ /_/ / /|  / Author: GNanimates | https://gnon.top | @gn68s
\____/_/ |_/ License: Mozilla Public License Version 2.0 
--────────-< DEPENDENCIES >-────────--
Place required dependencies in the same folder as this script.
- GN Easings > https://github.com/lua-gods/GNs-Avatar-5/blob/future/lib/GNEasings.lua
]]

local Easings = require("./GNEasings")


local instances = {}
local sysTime

local tweenProcessor = models:newPart("TweenProcessor","WORLD") -- set to "WORLD" so it always runs when the player is loaded

local isActive = false
local setActive ---@type function

local function process()
	sysTime = client:getSystemTime() / 1000
	
	local toRemove = {}
	
	for id, tween in pairs(instances) do
		local duration = (sysTime - tween.start) / tween.duration
		if duration < 1 then
			local w = tween.easing(duration)
			tween.tick(math.lerp(tween.from,tween.to, w), duration)
		else
			tween.tick(tween.to, 1)
			toRemove[id] = true
			tween.onFinish()
			setActive(next(instances) and true or false) -- stops the process if theres no more entries
		end
	end
	
	for id in pairs(toRemove) do
		instances[id] = nil
	end
end


setActive = function (toggle)
	if isActive ~= toggle then
		tweenProcessor.midRender = toggle and process or nil
		isActive = toggle
	end
end


---@class GN.Tween.Instance
---@field id string?
---
---@field from number|Vector.any
---@field to number|Vector.any
---
---@field duration number
---@field period number?
---@field overshoot number?
---@field amplitude number?
---
---@field easing GN.Easings|(fun(t: number): number|Vector.any)
---
---@field tick fun(v : number|Vector.any,t : number)
---@field onFinish function?


---@class GN.TweenAPI
local TweenAPI = {}


---An instance of a tween query
---@class GN.Tween
---@field id string
---
---@field from number|Vector.any
---@field to number|Vector.any
---
---@field duration number
---@field package start number?
---@field period number?
---@field overshoot number?
---@field amplitude number?
---
---@field easing fun(t: number): number|Vector.any
---
---@field tick fun(v : number|Vector.any,t : number)
---@field onFinish function?
local Tween = {}
Tween.__index = Tween

local function placeholder() end
local function linear(x) return x end


---Creates a new Tween instance
---***
---FIELDS:  
--- | Field       | Default    | Description                                                                                                                                     |
--- | ----------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
--- | `id`        | `?`        | The unique ID of the tween                                                                                                                      |
--- | `from`      | `0`        | The starting value of the tween                                                                                                                 |
--- | `to`        | `1`        | The ending value of the tween                                                                                                                   |
--- | `amplitude` | `1`        | The height of the oscillation (springiness). **only used for the elastic easings**                                                              |
--- | `period`    | `1`        | The frequency of the oscillation (how fast it bounces). **only used for the elastic easings**                                                   |
--- | `overshoot` | `1.7`      | controls how much the back easing will "go past" the starting position before moving toward the final value. **only used for the back easings** |
--- | `duration`  | `1`        | how long the tween will take in seconds                                                                                                         |
--- | `easing`    | `ar`       | The name of theeasing function to use                                                                                                           |
--- | `tick`      | `?`        | a callback function that gets called everytime the tween ticks                                                                                  |
--- | `onFinish`  | `?`        | a callback function that gets called when the tween finishes                                                                                    |
---@param cfg {
---	id: string?,
---	from: number|Vector.any,
---	to: number|Vector.any,
---	duration: number,
---	period: number?,
---	overshoot: number?,
---	amplitude: number?,
---	easing: GN.Easings|(fun(t: number): number|Vector.any),
---	tick: fun(v : number|Vector.any,t : number),
---	onFinish: function?}
---@return GN.Tween
function TweenAPI.new(cfg)
	local id = cfg.id or #instances + 1
	---@type GN.Tween
	
	local self = {
		start = isActive and sysTime or (client:getSystemTime()/1000),
		from = cfg.from or 0,
		to = cfg.to or 1,
		period = cfg.period or 1,
		overshoot = cfg.overshoot or 5,
		duration = cfg.duration or 1,
		easing = Easings[cfg.easing] or (type(cfg.easing) == "function" and cfg.easing) or linear,
		tick = cfg.tick or placeholder,
		onFinish = cfg.onFinish or placeholder,
		id = cfg.id
	}
	setmetatable(self, {__index = Tween})
	self.tick(self.from, 0)
	instances[id] = self
	
	setActive(true)
	return self
end

---Stops this TweenInstance
function Tween:stop()
	instances[self.id] = nil
end

---Skips the given TweenInsatnce to finish instantly
function Tween:skip()
	self.tick(1,1)
	self.onFinish()
	instances[self.id] = nil
end


---Stops the tween with the given ID. if `cancel` is true, it NOT will call the `onFinish` function
---@param id string
---@param cancel boolean?
function Tween.stop(id, cancel)
	instances[id] = nil
	if not cancel and instances[id] then
		instances[id].onFinish()
	end
end

return TweenAPI
