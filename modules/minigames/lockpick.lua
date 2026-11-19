---@diagnostic disable: undefined-global

local Lockpick = {}

---@param difficulty number?
---@return number nodes, number spinTolerance, number nodeLifetimeMs, number durationMs
function Lockpick.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local nodes = ({ 3, 4, 4, 5, 6 })[d]
    local spinTolerance = ({ 16, 14, 12, 10, 8 })[d]
    local nodeLifetimeMs = ({ 2200, 1900, 1600, 1350, 1100 })[d]
    local durationMs = ({ 40000, 36000, 32000, 28000, 24000 })[d]
    return nodes, spinTolerance, nodeLifetimeMs, durationMs
end

---@param opts table?
---@return table
function Lockpick.BuildConfig(opts)
    opts = opts or {}
    local nodes, spinTolerance, nodeLifetimeMs, durationMs = Lockpick.ResolveDifficulty(opts.difficulty)

    if type(opts.nodes) == 'number' then
        nodes = math.min(8, math.max(3, math.floor(opts.nodes)))
    end
    if type(opts.spinTolerance) == 'number' then
        spinTolerance = math.min(30, math.max(4, math.floor(opts.spinTolerance)))
    end
    if type(opts.nodeLifetime) == 'number' then
        nodeLifetimeMs = math.min(4000, math.max(600, math.floor(opts.nodeLifetime)))
    end

    return {
        nodes = nodes,
        spinTolerance = spinTolerance,
        nodeLifetime = nodeLifetimeMs,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Lockpick
