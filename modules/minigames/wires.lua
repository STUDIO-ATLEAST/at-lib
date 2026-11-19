---@diagnostic disable: undefined-global

local Wires = {}

---@param difficulty number?
---@return number wireCount, number durationMs
function Wires.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local wireCount = ({ 3, 4, 4, 5, 5 })[d]
    local durationMs = ({ 45000, 38000, 32000, 26000, 22000 })[d]
    return wireCount, durationMs
end

---@param opts table?
---@return table
function Wires.BuildConfig(opts)
    opts = opts or {}
    local wireCount, durationMs = Wires.ResolveDifficulty(opts.difficulty)

    if type(opts.wires) == 'number' then
        wireCount = math.min(5, math.max(3, math.floor(opts.wires)))
    end

    return {
        wires = wireCount,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Wires
