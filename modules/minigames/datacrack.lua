---@diagnostic disable: undefined-global

local DataCrack = {}

local function num(v, fallback)
    return type(v) == 'number' and v or fallback
end

--- `duration` 0 disables the timer (lock progress only).
---@param opts table?
---@return table
function DataCrack.BuildConfig(opts)
    opts = opts or {}
    local d = math.min(5, math.max(1, math.floor(tonumber(opts.difficulty) or 3)))

    local stages = num(opts.stages, ({ 1, 1, 2, 2, 3 })[d])
    local segments = num(opts.numberOfSegments, num(opts.segments, ({ 5, 6, 8, 9, 10 })[d]))
    local speed = num(opts.segmentSpeed, ({ 40, 50, 60, 75, 90 })[d])
    local gapSize = num(opts.gapSize, ({ 28, 25, 22, 19, 16 })[d])
    local lineWidth = num(opts.lineWidth, 34)
    local duration = num(opts.duration, 0)

    return {
        stages = math.min(5, math.max(1, math.floor(stages))),
        segments = math.min(12, math.max(3, math.floor(segments))),
        segmentSpeed = math.min(250, math.max(15, speed + 0.0)),
        gapSize = math.min(40, math.max(10, gapSize + 0.0)),
        lineWidth = math.min(80, math.max(4, lineWidth + 0.0)),
        duration = duration <= 0 and 0 or math.min(120000, math.max(5000, math.floor(duration))),
        seed = math.floor(tonumber(opts.seed) or math.random(1, 2147483646)),
    }
end

return DataCrack
