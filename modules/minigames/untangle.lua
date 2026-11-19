---@diagnostic disable: undefined-global

local Untangle = {}

---@param difficulty number?
---@return number dots, number durationMs
function Untangle.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local dots = ({ 5, 6, 7, 8, 9 })[d]
    local durationMs = ({ 50000, 45000, 40000, 35000, 30000 })[d]
    return dots, durationMs
end

---@param opts table?
---@return table
function Untangle.BuildConfig(opts)
    opts = opts or {}
    local dots, durationMs = Untangle.ResolveDifficulty(opts.difficulty)

    if type(opts.dots) == 'number' then
        dots = math.min(12, math.max(4, math.floor(opts.dots)))
    end

    return {
        dots = dots,
        duration = math.max(30000, tonumber(opts.duration) or durationMs),
    }
end

return Untangle
