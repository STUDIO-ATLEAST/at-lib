---@diagnostic disable: undefined-global

local LaserGrid = {}

---@param difficulty number?
---@return number laserCount, number laserSpeed, number sections, number detectionHits, boolean fog, boolean cameraSway, number durationMs
function LaserGrid.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local laserCount = ({ 3, 3, 4, 5, 6 })[d] -- gates per sector
    local laserSpeed = ({ 14, 17, 20, 24, 28 })[d] -- gap slide speed, % per second
    local sections = ({ 1, 1, 2, 2, 2 })[d]
    local detectionHits = ({ 5, 5, 4, 3, 3 })[d]
    local fog = d >= 5
    local cameraSway = false
    local durationMs = ({ 50000, 48000, 45000, 43000, 42000 })[d]
    return laserCount, laserSpeed, sections, detectionHits, fog, cameraSway, durationMs
end

---@param opts table?
---@return table
function LaserGrid.BuildConfig(opts)
    opts = opts or {}
    local laserCount, laserSpeed, sections, detectionHits, fog, cameraSway, durationMs =
        LaserGrid.ResolveDifficulty(opts.difficulty)

    if type(opts.laserCount) == 'number' then
        laserCount = math.min(10, math.max(2, math.floor(opts.laserCount)))
    end
    if type(opts.laserSpeed) == 'number' then
        laserSpeed = math.min(80, math.max(8, opts.laserSpeed + 0.0))
    end
    if type(opts.sections) == 'number' then
        sections = math.min(4, math.max(1, math.floor(opts.sections)))
    end
    if type(opts.detectionHits) == 'number' then
        detectionHits = math.min(6, math.max(1, math.floor(opts.detectionHits)))
    end
    if type(opts.fog) == 'boolean' then
        fog = opts.fog
    end
    if type(opts.cameraSway) == 'boolean' then
        cameraSway = opts.cameraSway
    end

    return {
        laserCount = laserCount,
        laserSpeed = laserSpeed,
        sections = sections,
        detectionHits = detectionHits,
        fog = fog,
        cameraSway = cameraSway,
        duration = tonumber(opts.duration) or durationMs,
        seed = math.floor(tonumber(opts.seed) or ((GetGameTimer() + math.random(1, 999999)) % 2147483646)),
    }
end

return LaserGrid
