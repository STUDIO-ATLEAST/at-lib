---@diagnostic disable: undefined-global

local PulseBar = {}

local function num(v, fallback)
    return type(v) == 'number' and v or fallback
end

---@param opts table?
---@return table
function PulseBar.BuildConfig(opts)
    opts = opts or {}
    local d = math.min(5, math.max(1, math.floor(tonumber(opts.difficulty) or 3)))

    local speed = num(opts.segmentSpeed, ({ 30, 38, 45, 55, 68 })[d])
    local zone = num(opts.targetZoneSize, ({ 16, 14, 12, 10, 8 })[d])
    local count = num(opts.numberOfSegments, num(opts.segments, ({ 3, 4, 4, 5, 6 })[d]))

    return {
        segmentSpeed = math.min(200, math.max(10, speed + 0.0)),
        targetZoneSize = math.min(30, math.max(4, zone + 0.0)),
        numberOfSegments = math.min(15, math.max(1, math.floor(count))),
        seed = math.floor(tonumber(opts.seed) or math.random(1, 2147483646)),
    }
end

return PulseBar
