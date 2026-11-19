---@diagnostic disable: undefined-global

local Stacker = {}

local function num(v, fallback)
    return type(v) == 'number' and v or fallback
end

--- `duration` 0 disables the timer (row progress only).
---@param opts table?
---@return table
function Stacker.BuildConfig(opts)
    opts = opts or {}
    local d = math.min(5, math.max(1, math.floor(tonumber(opts.difficulty) or 3)))

    local stages = num(opts.stages, 1)
    local rows = num(opts.rowsToGoal, ({ 5, 6, 7, 8, 10 })[d])
    local width = num(opts.startWidthPercent, ({ 50, 45, 40, 35, 30 })[d])
    local speed = num(opts.segmentSpeed, ({ 45, 55, 70, 85, 100 })[d])
    local duration = num(opts.duration, 0)

    local speedUp = d >= 3
    if type(opts.speedUpEachRow) == 'boolean' then
        speedUp = opts.speedUpEachRow
    end

    return {
        stages = math.min(5, math.max(1, math.floor(stages))),
        rowsToGoal = math.min(14, math.max(2, math.floor(rows))),
        startWidthPercent = math.min(90, math.max(10, width + 0.0)),
        segmentSpeed = math.min(250, math.max(15, speed + 0.0)),
        speedUpEachRow = speedUp,
        duration = duration <= 0 and 0 or math.min(120000, math.max(5000, math.floor(duration))),
    }
end

return Stacker
