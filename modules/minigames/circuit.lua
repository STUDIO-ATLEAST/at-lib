---@diagnostic disable: undefined-global

local Circuit = {}

---@param difficulty number?
---@return number size, number sources, number outputs, number dangers, number maxRotations, number durationMs
function Circuit.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local size = ({ 3, 4, 4, 5, 5 })[d]
    local sources = ({ 1, 1, 1, 1, 2 })[d]
    local outputs = ({ 1, 1, 2, 2, 3 })[d]
    local dangers = ({ 0, 0, 1, 1, 2 })[d]
    -- 0 = unlimited
    local maxRotations = ({ 0, 0, 0, 24, 18 })[d]
    local durationMs = ({ 50000, 42000, 36000, 30000, 26000 })[d]
    return size, sources, outputs, dangers, maxRotations, durationMs
end

---@param opts table?
---@return table
function Circuit.BuildConfig(opts)
    opts = opts or {}
    local size, sources, outputs, dangers, maxRotations, durationMs = Circuit.ResolveDifficulty(opts.difficulty)

    if type(opts.size) == 'number' then
        size = math.min(6, math.max(3, math.floor(opts.size)))
    end
    if type(opts.sources) == 'number' then
        sources = math.min(3, math.max(1, math.floor(opts.sources)))
    end
    if type(opts.outputs) == 'number' then
        outputs = math.min(4, math.max(1, math.floor(opts.outputs)))
    end
    if type(opts.dangers) == 'number' then
        dangers = math.min(4, math.max(0, math.floor(opts.dangers)))
    end
    if type(opts.maxRotations) == 'number' then
        maxRotations = math.min(80, math.max(0, math.floor(opts.maxRotations)))
    end

    return {
        size = size,
        sources = sources,
        outputs = outputs,
        dangers = dangers,
        maxRotations = maxRotations,
        duration = tonumber(opts.duration) or durationMs,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return Circuit
