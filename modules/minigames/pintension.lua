---@diagnostic disable: undefined-global

local PinTension = {}

---@param difficulty number?
---@return number pins, number zoneSize, number tensionTol, number durability, number fallSpeed, number durationMs
function PinTension.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local pins = ({ 3, 4, 4, 5, 6 })[d]
    local zoneSize = ({ 14, 12, 10, 8, 6 })[d]
    local tensionTol = ({ 16, 14, 12, 10, 8 })[d]
    local durability = ({ 5, 4, 3, 3, 2 })[d]
    local fallSpeed = ({ 28, 34, 42, 52, 64 })[d]
    local durationMs = 0 -- pick durability ends the game: no overall timer unless opts.duration
    return pins, zoneSize, tensionTol, durability, fallSpeed, durationMs
end

---@param count number
---@param zoneSize number
---@param tensionTol number
---@return table[]
local function buildPins(count, zoneSize, tensionTol)
    local pins = {}
    for i = 1, count do
        local target = math.random(28, 78)
        local tension = math.random(30, 75)
        pins[i] = {
            target = target,
            zone = zoneSize,
            tension = tension,
            tensionTol = tensionTol,
        }
    end
    return pins
end

---@param opts table?
---@return table
function PinTension.BuildConfig(opts)
    opts = opts or {}
    local pins, zoneSize, tensionTol, durability, fallSpeed, durationMs = PinTension.ResolveDifficulty(opts.difficulty)

    if type(opts.pins) == 'number' then
        pins = math.min(8, math.max(3, math.floor(opts.pins)))
    end
    if type(opts.zoneSize) == 'number' then
        zoneSize = math.min(22, math.max(4, math.floor(opts.zoneSize)))
    end
    if type(opts.tensionTol) == 'number' then
        tensionTol = math.min(24, math.max(4, math.floor(opts.tensionTol)))
    end
    if type(opts.durability) == 'number' then
        durability = math.min(8, math.max(1, math.floor(opts.durability)))
    end
    if type(opts.fallSpeed) == 'number' then
        fallSpeed = math.min(100, math.max(10, math.floor(opts.fallSpeed)))
    end

    return {
        pins = buildPins(pins, zoneSize, tensionTol),
        durability = durability,
        fallSpeed = fallSpeed,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return PinTension
