---@diagnostic disable: undefined-global

local SignalTune = {}

---@param difficulty number?
---@return number freqTol, number ampTol, number phaseTol, number durationMs
function SignalTune.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local freqTol = ({ 0.45, 0.35, 0.28, 0.22, 0.16 })[d]
    local ampTol = ({ 10, 8, 6, 5, 4 })[d]
    local phaseTol = ({ 22, 16, 12, 9, 7 })[d]
    local durationMs = ({ 45000, 38000, 32000, 26000, 22000 })[d]
    return freqTol, ampTol, phaseTol, durationMs
end

---@return number frequency, number amplitude, number phase
local function randomTarget()
    local frequency = 1.5 + math.random() * 5.5 -- 1.5-7.0
    local amplitude = 35 + math.random(0, 55) -- 35-90
    local phase = math.random(0, 359)
    return frequency, amplitude, phase
end

---@param opts table?
---@return table
function SignalTune.BuildConfig(opts)
    opts = opts or {}
    local freqTol, ampTol, phaseTol, durationMs = SignalTune.ResolveDifficulty(opts.difficulty)

    if type(opts.freqTolerance) == 'number' then
        freqTol = math.min(1.5, math.max(0.08, opts.freqTolerance + 0.0))
    end
    if type(opts.ampTolerance) == 'number' then
        ampTol = math.min(30, math.max(2, math.floor(opts.ampTolerance)))
    end
    if type(opts.phaseTolerance) == 'number' then
        phaseTol = math.min(45, math.max(3, math.floor(opts.phaseTolerance)))
    end

    local frequency, amplitude, phase = randomTarget()
    if type(opts.frequency) == 'number' then
        frequency = math.min(8, math.max(1, opts.frequency + 0.0))
    end
    if type(opts.amplitude) == 'number' then
        amplitude = math.min(100, math.max(10, math.floor(opts.amplitude)))
    end
    if type(opts.phase) == 'number' then
        phase = math.floor(opts.phase) % 360
    end

    return {
        frequency = frequency,
        amplitude = amplitude,
        phase = phase,
        freqTolerance = freqTol,
        ampTolerance = ampTol,
        phaseTolerance = phaseTol,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return SignalTune
