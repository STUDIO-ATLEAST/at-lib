---@diagnostic disable: undefined-global

local Smash = {}

---@param difficulty number?
---@return number gain, number decay, number durationMs
function Smash.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    -- % per keypress, % decay per second, time limit
    local gain = ({ 12, 10, 8, 6.5, 5 })[d]
    local decay = ({ 8, 11, 15, 20, 26 })[d]
    local durationMs = ({ 20000, 16000, 14000, 12000, 10000 })[d]
    return gain, decay, durationMs
end

---@param opts table?
---@return table
function Smash.BuildConfig(opts)
    opts = opts or {}
    local gain, decay, durationMs = Smash.ResolveDifficulty(opts.difficulty)

    if type(opts.gain) == 'number' then
        gain = math.min(40, math.max(2, opts.gain + 0.0))
    end

    if type(opts.decay) == 'number' then
        decay = math.min(60, math.max(0, opts.decay + 0.0))
    end

    if type(opts.duration) == 'number' then
        durationMs = math.min(60000, math.max(4000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        durationMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
        durationMs = math.min(60000, math.max(4000, durationMs))
    end

    local key = 'E'
    if type(opts.key) == 'string' and opts.key ~= '' then
        key = opts.key:sub(1, 1):upper()
    end

    local start = 6
    if type(opts.start) == 'number' then
        start = math.min(40, math.max(0, opts.start + 0.0))
    end

    return {
        key = key,
        gain = gain,
        decay = decay,
        start = start,
        duration = durationMs,
    }
end

return Smash
