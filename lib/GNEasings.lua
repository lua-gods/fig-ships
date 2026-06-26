--[[______   __
  / ____/ | / / Name: GN EASINGS LIBRARY v1.0.0
 / / __/  |/ /  Desc: contains all the common easing functions
/ /_/ / /|  / Author: GNanimates | https://gnon.top | @gn68s
\____/_/ |_/ License: MIT ]]

local pow, sin, cos, pi, sqrt, asin = math.pow, math.sin, math.cos, math.pi, math.sqrt, math.asin

local function linear(t)
	return t
end

local function inQuad(t)
	return t^2
end

local function outQuad(t)
	return -t * (t - 2)
end

local function inOutQuad(t)
	t = t * 2
	if t < 1 then return 0.5 * t^2 end
	t = t - 1
	return -0.5 * (t * (t - 2) - 1)
end

local function outInQuad(t)
	if t < 0.5 then return outQuad(t * 2) * 0.5 end
	return inQuad((t - 0.5) * 2) * 0.5 + 0.5
end

-- Cubic
local function inCubic(t)
	return t^3
end

local function outCubic(t)
	t = t - 1
	return t^3 + 1
end

local function inOutCubic(t)
	t = t * 2
	if t < 1 then return 0.5 * t^3 end
	t = t - 2
	return 0.5 * (t^3 + 2)
end

local function outInCubic(t)
	if t < 0.5 then return outCubic(t * 2) * 0.5 end
	return inCubic((t - 0.5) * 2) * 0.5 + 0.5
end

-- Quart
local function inQuart(t)
	return t^4
end

local function outQuart(t)
	t = t - 1
	return 1 - t^4
end

local function inOutQuart(t)
	t = t * 2
	if t < 1 then return 0.5 * t^4 end
	t = t - 2
	return -0.5 * (t^4 - 2)
end

local function outInQuart(t)
	if t < 0.5 then return outQuart(t * 2) * 0.5 end
	return inQuart((t - 0.5) * 2) * 0.5 + 0.5
end

-- Quint
local function inQuint(t)
	return t^5
end

local function outQuint(t)
	t = t - 1
	return t^5 + 1
end

local function inOutQuint(t)
	t = t * 2
	if t < 1 then return 0.5 * t^5 end
	t = t - 2
	return 0.5 * (t^5 + 2)
end

local function outInQuint(t)
	if t < 0.5 then return outQuint(t * 2) * 0.5 end
	return inQuint((t - 0.5) * 2) * 0.5 + 0.5
end

-- Sine
local function inSine(t)
	return 1 - cos(t * pi * 0.5)
end

local function outSine(t)
	return sin(t * pi * 0.5)
end

local function inOutSine(t)
	return -0.5 * (cos(pi * t) - 1)
end

local function outInSine(t)
	if t < 0.5 then return outSine(t * 2) * 0.5 end
	return inSine((t - 0.5) * 2) * 0.5 + 0.5
end

-- Expo
local function inExpo(t)
	if t == 0 then return 0 end
	return pow(2, 10 * (t - 1))
end

local function outExpo(t)
	if t == 1 then return 1 end
	return 1 - pow(2, -10 * t)
end

local function inOutExpo(t)
	if t == 0 then return 0 end
	if t == 1 then return 1 end
	t = t * 2
	if t < 1 then return 0.5 * pow(2, 10 * (t - 1)) end
	return 0.5 * (2 - pow(2, -10 * (t - 1)))
end

local function outInExpo(t)
	if t < 0.5 then return outExpo(t * 2) * 0.5 end
	return inExpo((t - 0.5) * 2) * 0.5 + 0.5
end

-- Circ
local function inCirc(t)
	return -(sqrt(1 - t^2) - 1)
end

local function outCirc(t)
	t = t - 1
	return sqrt(1 - t^2)
end

local function inOutCirc(t)
	t = t * 2
	if t < 1 then return -0.5 * (sqrt(1 - t^2) - 1) end
	t = t - 2
	return 0.5 * (sqrt(1 - t^2) + 1)
end

local function outInCirc(t)
	if t < 0.5 then return outCirc(t * 2) * 0.5 end
	return inCirc((t - 0.5) * 2) * 0.5 + 0.5
end

-- Elastic (factory with amplitude and period)
function inElastic(t, a, p)
	a = a or 1
	p = p or 0.3
	if t == 0 or t == 1 then return t end
	local s = p / (2 * pi) * asin(1 / a)
	t = t - 1
	return -(a * pow(2, 10 * t) * sin((t - s) * (2 * pi) / p))
end

function outElastic(t, a, p)
	a = a or 1
	p = p or 0.3
	if t == 0 or t == 1 then return t end
	local s = p / (2 * pi) * asin(1 / a)
	return a * pow(2, -10 * t) * sin((t - s) * (2 * pi) / p) + 1
end

function inOutElastic(t, a, p)
	a = a or 1
	p = p or 0.45
	if t == 0 or t == 1 then return t end
	t = t * 2
	local s = p / (2 * pi) * asin(1 / a)
	if t < 1 then
		t = t - 1
		return -0.5 * (a * pow(2, 10 * t) * sin((t - s) * (2 * pi) / p))
	else
		t = t - 1
		return a * pow(2, -10 * t) * sin((t - s) * (2 * pi) / p) * 0.5 + 1
	end
end

function outInElastic(t, a, p)
	if t < 0.5 then
		return 0.5 * outElastic(t * 2, a, p)
	else
		return 0.5 * inElastic((t * 2) - 1, a, p) + 0.5
	end
end

-- Back (factory with overshoot s)
function inBack(t, s)
	s = s or 1.70158
	return t^2 * ((s + 1) * t - s)
end

function outBack(t, s)
	s = s or 1.70158
	t = t - 1
	return t^2 * ((s + 1) * t + s) + 1
end

function inOutBack(t, s)
	s = (s or 1.70158) * 1.525
	t = t * 2
	if t < 1 then return 0.5 * t^2 * ((s + 1) * t - s) end
	t = t - 2
	return 0.5 * (t^2 * ((s + 1) * t + s) + 2)
end

function outInBack(t, s)
	if t < 0.5 then
		return 0.5 * outBack(t * 2, s)
	else
		return 0.5 * inBack((t * 2) - 1, s) + 0.5
	end
end

-- Bounce
local function outBounce(t)
	if t < 1 / 2.75 then
		return 7.5625 * t^2
	elseif t < 2 / 2.75 then
		t = t - 1.5 / 2.75
		return 7.5625 * t^2 + 0.75
	elseif t < 2.5 / 2.75 then
		t = t - 2.25 / 2.75
		return 7.5625 * t^2 + 0.9375
	else
		t = t - 2.625 / 2.75
		return 7.5625 * t^2 + 0.984375
	end
end

local function inBounce(t)
	return 1 - outBounce(1 - t)
end

local function inOutBounce(t)
	if t < 0.5 then return inBounce(t * 2) * 0.5 end
	return outBounce(t * 2 - 1) * 0.5 + 0.5
end

local function outInBounce(t)
	if t < 0.5 then return outBounce(t * 2) * 0.5 end
	return inBounce((t - 0.5) * 2) * 0.5 + 0.5
end

---@alias GN.Easings string
---| "linear"
---
---| "inQuad"
---| "outQuad"
---| "inOutQuad"
---| "outInQuad"
---
---| "inCubic"
---| "outCubic"
---| "inOutCubic"
---| "outInCubic"
---
---| "inQuart"
---| "outQuart"
---| "inOutQuart"
---| "outInQuart"
---
---| "inQuint"
---| "outQuint"
---| "inOutQuint"
---| "outInQuint"
---
---| "inSine"
---| "outSine"
---| "inOutSine"
---| "outInSine"
---
---| "inExpo"
---| "outExpo"
---| "inOutExpo"
---| "outInExpo"
---
---| "inCirc"
---| "outCirc"
---| "inOutCirc"
---| "outInCirc"
---
---| "inElastic"
---| "outElastic"
---| "inOutElastic"
---| "outInElastic"
---
---| "inBack"
---| "outBack"
---| "inOutBack"
---| "outInBack"
---
---| "inBounce"
---| "outBounce"
---| "inOutBounce"
---| "outInBounce"


local Easings = {
  linear    = linear,
  inQuad    = inQuad,    outQuad    = outQuad,    inOutQuad    = inOutQuad,    outInQuad    = outInQuad,
  inCubic   = inCubic,   outCubic   = outCubic,   inOutCubic   = inOutCubic,   outInCubic   = outInCubic,
  inQuart   = inQuart,   outQuart   = outQuart,   inOutQuart   = inOutQuart,   outInQuart   = outInQuart,
  inQuint   = inQuint,   outQuint   = outQuint,   inOutQuint   = inOutQuint,   outInQuint   = outInQuint,
  inSine    = inSine,    outSine    = outSine,    inOutSine    = inOutSine,    outInSine    = outInSine,
  inExpo    = inExpo,    outExpo    = outExpo,    inOutExpo    = inOutExpo,    outInExpo    = outInExpo,
  inCirc    = inCirc,    outCirc    = outCirc,    inOutCirc    = inOutCirc,    outInCirc    = outInCirc,
  inElastic = inElastic, outElastic = outElastic, inOutElastic = inOutElastic, outInElastic = outInElastic,
  inBack    = inBack,    outBack    = outBack,    inOutBack    = inOutBack,    outInBack    = outInBack,
  inBounce  = inBounce,  outBounce  = outBounce,  inOutBounce  = inOutBounce,  outInBounce  = outInBounce
}
return Easings