---@diagnostic disable: undefined-global

local CircleLock = {}

---@param difficulty number?
---@return number stages, number zoneSize, number speed, number lives, number durationMs
function CircleLock.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local stages = ({ 2, 3, 3, 4, 5 })[d]
    local zoneSize = ({ 48, 40, 34, 28, 22 })[d]
    local speed = ({ 120, 150, 180, 220, 260 })[d]
    local lives = ({ 3, 3, 2, 2, 1 })[d]
    local durationMs = 0 -- lives end the game: no overall timer unless opts.duration
    return stages, zoneSize, speed, lives, durationMs
end

---@param opts table?
---@return table
function CircleLock.BuildConfig(opts)
    opts = opts or {}
    local stages, zoneSize, speed, lives, durationMs = CircleLock.ResolveDifficulty(opts.difficulty)

    if type(opts.stages) == 'number' then
        stages = math.min(8, math.max(1, math.floor(opts.stages)))
    end
    if type(opts.zoneSize) == 'number' then
        zoneSize = math.min(80, math.max(12, math.floor(opts.zoneSize)))
    end
    if type(opts.speed) == 'number' then
        speed = math.min(400, math.max(60, math.floor(opts.speed)))
    end
    if type(opts.lives) == 'number' then
        lives = math.min(5, math.max(1, math.floor(opts.lives)))
    end

    return {
        stages = stages,
        zoneSize = zoneSize,
        speed = speed,
        lives = lives,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return CircleLock
