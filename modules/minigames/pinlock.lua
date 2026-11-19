---@diagnostic disable: undefined-global

local PinLock = {}

local function num(v, fallback)
    return type(v) == 'number' and v or fallback
end

--- `duration` 0 disables the timer.
---@param opts table?
---@return table
function PinLock.BuildConfig(opts)
    opts = opts or {}
    local d = math.min(5, math.max(1, math.floor(tonumber(opts.difficulty) or 3)))

    local pins = num(opts.numberOfPins, num(opts.pins, ({ 3, 4, 5, 6, 8 })[d]))
    local push = num(opts.pushStrength, 55)
    local gravity = num(opts.gravity, ({ 110, 125, 140, 165, 190 })[d])
    local tolerance = num(opts.zoneTolerance, ({ 10, 8, 7, 5, 4 })[d])
    local attempts = num(opts.maxAttempts, num(opts.lives, ({ 5, 4, 3, 2, 1 })[d]))
    local duration = num(opts.duration, 0)

    return {
        numberOfPins = math.min(8, math.max(2, math.floor(pins))),
        pushStrength = math.min(200, math.max(10, push + 0.0)),
        gravity = math.min(600, math.max(20, gravity + 0.0)),
        zoneTolerance = math.min(25, math.max(2, tolerance + 0.0)),
        instantFail = opts.instantFail == true,
        maxAttempts = math.min(10, math.max(1, math.floor(attempts))),
        duration = duration <= 0 and 0 or math.min(120000, math.max(5000, math.floor(duration))),
        seed = math.floor(tonumber(opts.seed) or math.random(1, 2147483646)),
    }
end

return PinLock
