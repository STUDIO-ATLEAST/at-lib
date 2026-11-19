---@diagnostic disable: undefined-global

local OddOneOut = {}

---@param difficulty number?
---@return number size, number oddCount, number duration, number visibility, boolean animated, number stages
function OddOneOut.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local size = ({ 3, 4, 4, 5, 6 })[d]
    local oddCount = ({ 1, 1, 1, 2, 2 })[d]
    local duration = ({ 20000, 16000, 13000, 11000, 9000 })[d]
    -- 1 = obvious, 5 = very subtle
    local visibility = ({ 1, 2, 3, 4, 5 })[d]
    local animated = d >= 4
    local stages = ({ 1, 2, 2, 3, 3 })[d]
    return size, oddCount, duration, visibility, animated, stages
end

---@param opts table?
---@return table
function OddOneOut.BuildConfig(opts)
    opts = opts or {}
    local size, oddCount, duration, visibility, animated, stages = OddOneOut.ResolveDifficulty(opts.difficulty)

    if type(opts.size) == 'number' then
        size = math.min(7, math.max(3, math.floor(opts.size)))
    elseif type(opts.gridSize) == 'number' then
        size = math.min(7, math.max(3, math.floor(opts.gridSize)))
    end

    if type(opts.oddCount) == 'number' then
        oddCount = math.min(4, math.max(1, math.floor(opts.oddCount)))
    elseif type(opts.incorrect) == 'number' then
        oddCount = math.min(4, math.max(1, math.floor(opts.incorrect)))
    end

    if type(opts.visibility) == 'number' then
        visibility = math.min(5, math.max(1, math.floor(opts.visibility)))
    elseif type(opts.subtlety) == 'number' then
        visibility = math.min(5, math.max(1, math.floor(opts.subtlety)))
    end

    if type(opts.stages) == 'number' then
        stages = math.min(5, math.max(1, math.floor(opts.stages)))
    end

    if type(opts.duration) == 'number' then
        duration = math.min(60000, math.max(4000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        duration = t < 1000 and math.floor(t * 1000) or math.floor(t)
        duration = math.min(60000, math.max(4000, duration))
    end

    if type(opts.animated) == 'boolean' then
        animated = opts.animated
    end

    local lives = 1
    if type(opts.lives) == 'number' then
        lives = math.min(5, math.max(1, math.floor(opts.lives)))
    elseif type(opts.difficulty) == 'number' and opts.difficulty <= 2 then
        lives = 2
    end

    -- Cap odd count so the grid still has normals
    local cells = size * size
    oddCount = math.min(oddCount, math.max(1, cells - 2))

    return {
        size = size,
        oddCount = oddCount,
        visibility = visibility,
        animated = animated,
        stages = stages,
        lives = lives,
        duration = duration,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return OddOneOut
