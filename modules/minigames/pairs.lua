---@diagnostic disable: undefined-global

local Pairs = {}

---@param difficulty number?
---@return number pairCount, number durationMs
function Pairs.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local pairCount = ({ 4, 6, 8, 8, 10 })[d]
    local durationMs = ({ 50000, 42000, 36000, 28000, 22000 })[d]
    return pairCount, durationMs
end

---@param opts table?
---@return table
function Pairs.BuildConfig(opts)
    opts = opts or {}
    local pairCount, durationMs = Pairs.ResolveDifficulty(opts.difficulty)

    if type(opts.pairs) == 'number' then
        pairCount = math.min(12, math.max(3, math.floor(opts.pairs)))
    end

    return {
        pairs = pairCount,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Pairs
