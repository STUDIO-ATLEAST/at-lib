---@diagnostic disable: undefined-global

local PortScan = {}

---@param difficulty number?
---@return number ports, number required, number tickMs, number trapPenaltyMs, boolean similar, number durationMs
function PortScan.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local ports = ({ 8, 9, 12, 12, 16 })[d]
    local required = ({ 3, 4, 5, 6, 7 })[d]
    local tickMs = ({ 1100, 900, 750, 600, 480 })[d]
    local trapPenaltyMs = ({ 2500, 3000, 3500, 4000, 5000 })[d]
    local similar = d >= 3
    local durationMs = ({ 40000, 34000, 28000, 24000, 20000 })[d]
    return ports, required, tickMs, trapPenaltyMs, similar, durationMs
end

---@param opts table?
---@return table
function PortScan.BuildConfig(opts)
    opts = opts or {}
    local ports, required, tickMs, trapPenaltyMs, similar, durationMs = PortScan.ResolveDifficulty(opts.difficulty)

    if type(opts.ports) == 'number' then
        ports = math.min(20, math.max(6, math.floor(opts.ports)))
    end
    if type(opts.required) == 'number' then
        required = math.min(12, math.max(2, math.floor(opts.required)))
    end
    if type(opts.tick) == 'number' then
        tickMs = math.min(2000, math.max(280, math.floor(opts.tick)))
    end
    if type(opts.trapPenalty) == 'number' then
        trapPenaltyMs = math.min(8000, math.max(500, math.floor(opts.trapPenalty)))
    end
    if type(opts.similar) == 'boolean' then
        similar = opts.similar
    end

    return {
        ports = ports,
        required = required,
        tick = tickMs,
        trapPenalty = trapPenaltyMs,
        similar = similar,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return PortScan
