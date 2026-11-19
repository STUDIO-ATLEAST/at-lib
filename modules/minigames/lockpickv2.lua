---@diagnostic disable: undefined-global

local LockpickV2 = {}

---@param difficulty number?
---@return number segments, number greenCount, number speed, number lives, number durationMs
function LockpickV2.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local segments = ({ 6, 7, 8, 9, 10 })[d]
    local greenCount = ({ 4, 4, 4, 3, 3 })[d]
    local speed = ({ 90, 110, 130, 160, 190 })[d]
    local lives = ({ 3, 3, 2, 2, 1 })[d]
    local durationMs = 0 -- lives end the game: no overall timer unless opts.duration
    return segments, greenCount, speed, lives, durationMs
end

---@param opts table?
---@return table
function LockpickV2.BuildConfig(opts)
    opts = opts or {}
    local segments, greenCount, speed, lives, durationMs = LockpickV2.ResolveDifficulty(opts.difficulty)

    if type(opts.segments) == 'number' then
        segments = math.min(16, math.max(4, math.floor(opts.segments)))
    end
    if type(opts.greenCount) == 'number' then
        greenCount = math.floor(opts.greenCount)
    end
    -- At least one segment must stay red, or there's nothing to avoid.
    greenCount = math.max(1, math.min(segments - 1, greenCount))

    -- Neutral filler segments - press-and-nothing-happens spacers so the ring isn't wall-to-wall
    -- red/green. Defaults to roughly a third of the ring, but never eats into the last red slot.
    local emptyCount = math.floor(segments / 3)
    if type(opts.emptyCount) == 'number' then
        emptyCount = math.floor(opts.emptyCount)
    end
    emptyCount = math.max(0, math.min(segments - greenCount - 1, emptyCount))

    if type(opts.speed) == 'number' then
        speed = math.min(400, math.max(40, math.floor(opts.speed)))
    end
    if type(opts.lives) == 'number' then
        lives = math.min(5, math.max(1, math.floor(opts.lives)))
    end

    return {
        segments = segments,
        greenCount = greenCount,
        emptyCount = emptyCount,
        speed = speed,
        lives = lives,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return LockpickV2
