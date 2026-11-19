---@diagnostic disable: undefined-global

local Remember = {}

local GRID_SIZE = 5

---@param difficulty number?
---@return number targets, number lives, number previewMs, number durationMs
function Remember.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local targets = ({ 4, 5, 6, 7, 8 })[d]
    local lives = ({ 1, 1, 1, 1, 1 })[d]
    local previewMs = ({ 4000, 3500, 3000, 2500, 2000 })[d]
    local durationMs = ({ 18000, 16000, 14000, 12000, 10000 })[d]
    return targets, lives, previewMs, durationMs
end

---@param opts table?
---@return table
function Remember.BuildConfig(opts)
    opts = opts or {}
    local targets, lives, previewMs, durationMs = Remember.ResolveDifficulty(opts.difficulty)

    if type(opts.targets) == 'number' then
        targets = math.min(12, math.max(3, math.floor(opts.targets)))
    end

    if type(opts.lives) == 'number' then
        lives = math.min(6, math.max(1, math.floor(opts.lives)))
    end

    return {
        size = GRID_SIZE,
        targets = targets,
        lives = lives,
        preview = tonumber(opts.preview) or previewMs,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Remember
