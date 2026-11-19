---@diagnostic disable: undefined-global

local Sequence = {}

---@param difficulty number?
---@return number stages, number gridSize, number sequenceLength, number duration, number penalty, number scrambleCount, boolean instantFail
function Sequence.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local stages = ({ 1, 2, 2, 3, 3 })[d]
    local gridSize = ({ 6, 7, 8, 9, 10 })[d]
    local sequenceLength = ({ 3, 3, 4, 4, 5 })[d]
    local duration = ({ 28000, 24000, 20000, 16000, 13000 })[d]
    local penalty = ({ 2000, 2500, 3000, 3500, 4000 })[d]
    local scrambleCount = ({ 0, 0, 1, 2, 3 })[d]
    local instantFail = d >= 5
    return stages, gridSize, sequenceLength, duration, penalty, scrambleCount, instantFail
end

---@param opts table?
---@return table
function Sequence.BuildConfig(opts)
    opts = opts or {}
    local stages, gridSize, sequenceLength, duration, penalty, scrambleCount, instantFail =
        Sequence.ResolveDifficulty(opts.difficulty)

    if type(opts.numberOfStages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.numberOfStages)))
    elseif type(opts.stages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.stages)))
    end

    if type(opts.gridSize) == 'number' then
        gridSize = math.min(12, math.max(5, math.floor(opts.gridSize)))
    elseif type(opts.size) == 'number' then
        gridSize = math.min(12, math.max(5, math.floor(opts.size)))
    end

    if type(opts.sequenceLength) == 'number' then
        sequenceLength = math.min(6, math.max(2, math.floor(opts.sequenceLength)))
    end

    if type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        duration = t < 1000 and math.floor(t * 1000) or math.floor(t)
        duration = math.min(90000, math.max(5000, duration))
    elseif type(opts.duration) == 'number' then
        duration = math.min(90000, math.max(5000, math.floor(opts.duration)))
    end

    if type(opts.penaltySeconds) == 'number' then
        local p = opts.penaltySeconds
        penalty = p < 100 and math.floor(p * 1000) or math.floor(p)
        penalty = math.min(15000, math.max(0, penalty))
    elseif type(opts.penalty) == 'number' then
        penalty = math.min(15000, math.max(0, math.floor(opts.penalty)))
    end

    if type(opts.scrambleCount) == 'number' then
        scrambleCount = math.min(8, math.max(0, math.floor(opts.scrambleCount)))
    end

    if type(opts.instantFail) == 'boolean' then
        instantFail = opts.instantFail
    end

    sequenceLength = math.min(sequenceLength, gridSize)

    return {
        stages = stages,
        gridSize = gridSize,
        sequenceLength = sequenceLength,
        duration = duration,
        penalty = penalty,
        scrambleCount = scrambleCount,
        instantFail = instantFail,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return Sequence
