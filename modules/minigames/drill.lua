---@diagnostic disable: undefined-global

local Drill = {}

---@param difficulty number?
---@return number hits, number fallMs, number durationMs
function Drill.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local hits = ({ 5, 7, 9, 11, 13 })[d]
    local fallMs = ({ 3200, 2800, 2400, 2000, 1700 })[d]
    local durationMs = 0 -- every bar has its own fall time: no overall timer unless opts.duration
    return hits, fallMs, durationMs
end

---@param opts table?
---@return table
function Drill.BuildConfig(opts)
    opts = opts or {}
    local hits, fallMs, durationMs = Drill.ResolveDifficulty(opts.difficulty)

    if type(opts.hitsRequired) == 'number' then
        hits = math.min(20, math.max(3, math.floor(opts.hitsRequired)))
    elseif type(opts.rounds) == 'number' then
        hits = math.min(20, math.max(3, math.floor(opts.rounds)))
    elseif type(opts.numberOfHits) == 'number' then
        hits = math.min(20, math.max(3, math.floor(opts.numberOfHits)))
    end

    if type(opts.fallMs) == 'number' then
        fallMs = math.min(6000, math.max(900, math.floor(opts.fallMs)))
    elseif type(opts.fallSpeed) == 'number' then
        -- Higher fallSpeed = faster fall (shorter ms). 1-100 scale.
        local spd = math.min(100, math.max(1, opts.fallSpeed))
        fallMs = math.floor(3800 - (spd / 100) * 2800)
    end

    if type(opts.duration) == 'number' then
        durationMs = opts.duration <= 0 and 0 or math.min(120000, math.max(8000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        durationMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
        durationMs = durationMs <= 0 and 0 or math.min(120000, math.max(8000, durationMs))
    end

    return {
        hitsRequired = hits,
        fallMs = fallMs,
        duration = durationMs,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return Drill
