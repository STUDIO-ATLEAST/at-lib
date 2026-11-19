---@diagnostic disable: undefined-global

local Merge = {}

---@param difficulty number?
---@return number target, number durationMs
function Merge.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local target = ({ 64, 128, 128, 256, 256 })[d]
    local durationMs = ({ 50000, 45000, 40000, 35000, 30000 })[d]
    return target, durationMs
end

---@param opts table?
---@return table
function Merge.BuildConfig(opts)
    opts = opts or {}
    local target, durationMs = Merge.ResolveDifficulty(opts.difficulty)

    if type(opts.target) == 'number' then
        -- snap to nearest power of two between 32 and 1024
        local t = math.min(1024, math.max(32, math.floor(opts.target)))
        local p = 32
        while p * 2 <= t do
            p = p * 2
        end
        target = p
    end

    return {
        size = 4,
        target = target,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Merge
