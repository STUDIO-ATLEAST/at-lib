---@diagnostic disable: undefined-global

local Pathing = {}

---@param difficulty number?
---@return number stages, number dots, number timeLimitMs
function Pathing.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local stages = ({ 1, 2, 2, 3, 3 })[d]
    local dots = ({ 5, 6, 7, 8, 9 })[d]
    local timeLimitMs = ({ 25000, 22000, 18000, 15000, 12000 })[d]
    return stages, dots, timeLimitMs
end

---@param opts table?
---@return table
function Pathing.BuildConfig(opts)
    opts = opts or {}
    local stages, dots, timeLimitMs = Pathing.ResolveDifficulty(opts.difficulty)

    if type(opts.numberOfStages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.numberOfStages)))
    elseif type(opts.stages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.stages)))
    end

    if type(opts.numberOfDots) == 'number' then
        dots = math.min(12, math.max(4, math.floor(opts.numberOfDots)))
    elseif type(opts.dots) == 'number' then
        dots = math.min(12, math.max(4, math.floor(opts.dots)))
    end

    if type(opts.timeLimit) == 'number' then
        -- allow seconds or ms
        local t = opts.timeLimit
        timeLimitMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
        timeLimitMs = math.min(60000, math.max(5000, timeLimitMs))
    elseif type(opts.duration) == 'number' then
        timeLimitMs = math.min(60000, math.max(5000, math.floor(opts.duration)))
    end

    return {
        stages = stages,
        dots = dots,
        duration = timeLimitMs,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return Pathing
