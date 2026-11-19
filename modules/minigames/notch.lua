---@diagnostic disable: undefined-global

local Notch = {}

---@param difficulty number?
---@return number notches, number speed, number tolerance, number durationMs
function Notch.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local notches = ({ 3, 3, 4, 5, 6 })[d]
    local speed = ({ 90, 110, 130, 160, 190 })[d] -- deg / sec
    local tolerance = ({ 16, 14, 12, 9, 7 })[d]
    local durationMs = ({ 28000, 24000, 20000, 17000, 14000 })[d]
    return notches, speed, tolerance, durationMs
end

---@param count number
---@return number[] angles in degrees 0-360
function Notch.BuildAngles(count)
    local angles = {}
    local start = math.random() * 360
    local step = 360 / count
    -- slight jitter so notches aren't perfectly even
    for i = 1, count do
        local jitter = (math.random() - 0.5) * (step * 0.18)
        local a = (start + (i - 1) * step + jitter) % 360
        angles[i] = a
    end
    table.sort(angles)
    return angles
end

---@param opts table?
---@return table
function Notch.BuildConfig(opts)
    opts = opts or {}
    local notches, speed, tolerance, durationMs = Notch.ResolveDifficulty(opts.difficulty)

    if type(opts.notches) == 'number' then
        notches = math.min(8, math.max(2, math.floor(opts.notches)))
    elseif type(opts.rounds) == 'number' then
        notches = math.min(8, math.max(2, math.floor(opts.rounds)))
    end

    if type(opts.speed) == 'number' then
        speed = math.min(360, math.max(40, opts.speed + 0.0))
    end

    if type(opts.tolerance) == 'number' then
        tolerance = math.min(30, math.max(4, opts.tolerance + 0.0))
    end

    if type(opts.duration) == 'number' then
        durationMs = math.min(90000, math.max(5000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        durationMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
        durationMs = math.min(90000, math.max(5000, durationMs))
    end

    local key = 'E'
    if type(opts.key) == 'string' and opts.key ~= '' then
        key = opts.key:sub(1, 1):upper()
    end

    local angles = opts.angles
    if type(angles) ~= 'table' or #angles < 2 then
        angles = Notch.BuildAngles(notches)
    end

    return {
        notches = #angles,
        angles = angles,
        speed = speed,
        tolerance = tolerance,
        key = key,
        duration = durationMs,
        seed = tonumber(opts.seed) or math.random(1, 2147483646),
    }
end

return Notch
