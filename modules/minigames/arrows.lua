---@diagnostic disable: undefined-global

local Arrows = {}

local DIRS = { 'up', 'down', 'left', 'right' }

---@param difficulty number?
---@return number length, number durationMs, number stages
function Arrows.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local length = ({ 5, 6, 8, 10, 12 })[d]
    local durationMs = ({ 10000, 9000, 8000, 7000, 6000 })[d]
    local stages = ({ 1, 1, 1, 1, 1 })[d]
    return length, durationMs, stages
end

---@param length number
---@return string[]
function Arrows.BuildSequence(length)
    local sequence = {}
    for i = 1, length do
        sequence[i] = DIRS[math.random(1, #DIRS)]
    end
    return sequence
end

---@param opts table?
---@return table
function Arrows.BuildConfig(opts)
    opts = opts or {}
    local length, durationMs, stages = Arrows.ResolveDifficulty(opts.difficulty)

    if type(opts.length) == 'number' then
        length = math.min(16, math.max(3, math.floor(opts.length)))
    elseif type(opts.rounds) == 'number' then
        length = math.min(16, math.max(3, math.floor(opts.rounds)))
    end

    if type(opts.stages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.stages)))
    elseif type(opts.numberOfStages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.numberOfStages)))
    end

    if type(opts.duration) == 'number' then
        durationMs = math.min(60000, math.max(3000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        durationMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
        durationMs = math.min(60000, math.max(3000, durationMs))
    end

    local sequence = nil
    if type(opts.sequence) == 'table' and #opts.sequence > 0 then
        sequence = {}
        for i = 1, #opts.sequence do
            local dir = tostring(opts.sequence[i] or 'up'):lower()
            if dir == 'w' then dir = 'up' end
            if dir == 's' then dir = 'down' end
            if dir == 'a' then dir = 'left' end
            if dir == 'd' then dir = 'right' end
            if dir ~= 'up' and dir ~= 'down' and dir ~= 'left' and dir ~= 'right' then
                dir = 'up'
            end
            sequence[i] = dir
        end
        length = #sequence
    else
        sequence = Arrows.BuildSequence(length)
    end

    return {
        sequence = sequence,
        length = length,
        stages = stages,
        duration = durationMs,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return Arrows
