---@diagnostic disable: undefined-global

local Overflow = {}

local GRID_SIZE = 5

---@param difficulty number?
---@return number durationMs
function Overflow.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    return ({ 45000, 40000, 35000, 30000, 25000 })[d]
end

---@param opts table?
---@return table
function Overflow.BuildConfig(opts)
    opts = opts or {}
    local durationMs = Overflow.ResolveDifficulty(opts.difficulty)

    return {
        size = GRID_SIZE,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Overflow
