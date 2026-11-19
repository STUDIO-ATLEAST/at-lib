---@diagnostic disable: undefined-global
--- Shared difficulty presets + TeamsGG-style option aliases for all minigames.

local Config = {}

---@alias DifficultyName 'easy'|'medium'|'hard'

--- Dev tools / test commands: set convar `setr at_minigames_dev true`
function Config.IsDev()
    local v = GetConvar('at_minigames_dev', 'false')
    return v == 'true' or v == '1'
end

--- Numeric scale used by existing ResolveDifficulty helpers (1-5).
local LEVEL_SCALE = { easy = 2, medium = 3, hard = 5 }

--- Default option tables per game. Explicit export opts always win.
Config.Presets = {
    -- tries = wrong "Try" presses allowed before the safe jams; duration = whole safe (ms)
    safecrack = {
        easy = { rounds = 2, tries = 5, duration = 90000 },
        medium = { rounds = 3, tries = 3, duration = 75000 },
        hard = { rounds = 5, tries = 2, duration = 90000 },
    },
    alphabet = {
        easy = { rounds = 8, duration = 12000 },
        medium = { rounds = 15, duration = 10000 },
        hard = { rounds = 22, duration = 8000 },
    },
    keypad = {
        easy = { length = 4, tries = 8, duration = 45000 },
        medium = { length = 4, tries = 6, duration = 35000 },
        hard = { length = 4, tries = 4, duration = 25000 },
    },
    decrypt = {
        easy = { rounds = 3, tokenLength = 5, duration = 35000 },
        medium = { rounds = 5, tokenLength = 6, duration = 28000 },
        hard = { rounds = 6, tokenLength = 8, duration = 22000 },
    },
    overflow = {
        easy = { duration = 45000 },
        medium = { duration = 35000 },
        hard = { duration = 25000 },
    },
    remember = {
        easy = { targets = 4, lives = 1, preview = 4000, duration = 18000 },
        medium = { targets = 6, lives = 1, preview = 3000, duration = 14000 },
        hard = { targets = 8, lives = 1, preview = 2000, duration = 10000 },
    },
    pairs = {
        easy = { pairs = 4, duration = 50000, stages = 1 },
        medium = { pairs = 8, duration = 36000, stages = 1 },
        hard = { pairs = 10, duration = 22000, stages = 2 },
    },
    untangle = {
        easy = { dots = 5, duration = 50000, stages = 1 },
        medium = { dots = 7, duration = 40000, stages = 1 },
        hard = { dots = 9, duration = 30000, stages = 2 },
    },
    merge = {
        easy = { target = 64, duration = 50000, stages = 1 },
        medium = { target = 128, duration = 40000, stages = 1 },
        hard = { target = 256, duration = 30000, stages = 2 },
    },
    circlelock = {
        easy = { stages = 2, zoneSize = 48, speed = 120, lives = 3 },
        medium = { stages = 3, zoneSize = 34, speed = 180, lives = 2 },
        hard = { stages = 5, zoneSize = 22, speed = 260, lives = 1 },
    },
    lockpick = {
        easy = { nodes = 3, spinTolerance = 16, nodeLifetime = 2200, duration = 40000 },
        medium = { nodes = 4, spinTolerance = 12, nodeLifetime = 1600, duration = 32000 },
        hard = { nodes = 6, spinTolerance = 8, nodeLifetime = 1100, duration = 24000 },
    },
    wires = {
        easy = { wires = 3, duration = 45000 },
        medium = { wires = 4, duration = 32000 },
        hard = { wires = 5, duration = 22000 },
    },
    colormatch = {
        easy = { preview = 3500, tolerance = 55, duration = 40000, stages = 1 },
        medium = { preview = 2200, tolerance = 32, duration = 28000, stages = 1 },
        hard = { preview = 1300, tolerance = 18, duration = 20000, stages = 2 },
    },
    signaltune = {
        easy = { freqTolerance = 0.45, ampTolerance = 10, phaseTolerance = 22, duration = 45000 },
        medium = { freqTolerance = 0.28, ampTolerance = 6, phaseTolerance = 12, duration = 32000 },
        hard = { freqTolerance = 0.16, ampTolerance = 4, phaseTolerance = 7, duration = 22000 },
    },
    binary = {
        easy = { length = 6, preview = 3200, reverse = false, glitches = false, duration = 40000 },
        medium = { length = 8, preview = 2100, reverse = false, glitches = true, duration = 28000 },
        hard = { length = 10, preview = 1400, reverse = true, glitches = true, duration = 20000 },
    },
    circuit = {
        easy = { size = 3, sources = 1, outputs = 1, dangers = 0, maxRotations = 0, duration = 50000 },
        medium = { size = 4, sources = 1, outputs = 2, dangers = 1, maxRotations = 0, duration = 36000 },
        hard = { size = 5, sources = 2, outputs = 3, dangers = 2, maxRotations = 18, duration = 26000 },
    },
    portscan = {
        easy = { ports = 8, required = 3, tick = 1100, trapPenalty = 2500, similar = false, duration = 40000 },
        medium = { ports = 12, required = 5, tick = 750, trapPenalty = 3500, similar = true, duration = 28000 },
        hard = { ports = 16, required = 7, tick = 480, trapPenalty = 5000, similar = true, duration = 20000 },
    },
    pintension = {
        easy = { pins = 3, zoneSize = 14, tensionTol = 16, durability = 5, fallSpeed = 28 },
        medium = { pins = 4, zoneSize = 10, tensionTol = 12, durability = 3, fallSpeed = 42 },
        hard = { pins = 6, zoneSize = 6, tensionTol = 8, durability = 2, fallSpeed = 64 },
    },
    skillbar = {
        easy = { segmentSpeed = 55, targetZoneSize = 22, hitsRequired = 2 },
        medium = { segmentSpeed = 90, targetZoneSize = 14, hitsRequired = 3 },
        hard = { segmentSpeed = 135, targetZoneSize = 8, hitsRequired = 5 },
    },
    lasergrid = {
        -- laserCount = gates per sector, laserSpeed = how fast each gate's gap slides (% / sec)
        easy = { laserCount = 3, laserSpeed = 14, sections = 1, detectionHits = 5, fog = false, cameraSway = false, duration = 50000 },
        medium = { laserCount = 4, laserSpeed = 20, sections = 2, detectionHits = 4, fog = false, cameraSway = false, duration = 45000 },
        hard = { laserCount = 6, laserSpeed = 28, sections = 2, detectionHits = 3, fog = true, cameraSway = false, duration = 42000 },
    },
    pathing = {
        easy = { stages = 1, dots = 5, duration = 25000 },
        medium = { stages = 2, dots = 7, duration = 18000 },
        hard = { stages = 3, dots = 9, duration = 12000 },
    },
    oddoneout = {
        easy = { size = 3, oddCount = 1, visibility = 1, animated = false, stages = 1, lives = 2, duration = 20000 },
        medium = { size = 4, oddCount = 1, visibility = 3, animated = false, stages = 2, lives = 1, duration = 13000 },
        hard = { size = 6, oddCount = 2, visibility = 5, animated = true, stages = 3, lives = 1, duration = 9000 },
    },
    sequence = {
        easy = { stages = 1, gridSize = 6, sequenceLength = 3, duration = 28000, penalty = 2000, scrambleCount = 0, instantFail = false },
        medium = { stages = 2, gridSize = 8, sequenceLength = 4, duration = 20000, penalty = 3000, scrambleCount = 1, instantFail = false },
        hard = { stages = 3, gridSize = 10, sequenceLength = 5, duration = 13000, penalty = 4000, scrambleCount = 3, instantFail = true },
    },
    arrows = {
        easy = { length = 5, stages = 1, duration = 12000 },
        medium = { length = 8, stages = 1, duration = 8000 },
        hard = { length = 12, stages = 1, duration = 5500 },
    },
    search = {
        easy = { itemCount = 3, required = 2, searchTime = 900, duration = 35000 },
        medium = { itemCount = 4, required = 3, searchTime = 1400, duration = 26000 },
        hard = { itemCount = 6, required = 4, searchTime = 2000, duration = 18000 },
    },
    smash = {
        easy = { key = 'E', gain = 12, decay = 8, duration = 20000 },
        medium = { key = 'E', gain = 8, decay = 15, duration = 14000 },
        hard = { key = 'E', gain = 5, decay = 26, duration = 10000 },
    },
    notch = {
        easy = { notches = 3, speed = 90, tolerance = 16, duration = 25000 },
        medium = { notches = 4, speed = 130, tolerance = 12, duration = 20000 },
        hard = { notches = 5, speed = 180, tolerance = 8, duration = 16000 },
    },
    pedloot = {
        -- required is forced to all loot slots in BuildConfig (partial grabs still keep items)
        easy = { slots = 4, empties = 1, speed = 55, duration = 22000 },
        medium = { slots = 5, empties = 2, speed = 90, duration = 15000 },
        hard = { slots = 6, empties = 3, speed = 130, duration = 11000 },
    },
    drill = {
        easy = { hitsRequired = 5, fallMs = 3200 },
        medium = { hitsRequired = 9, fallMs = 2400 },
        hard = { hitsRequired = 12, fallMs = 1700 },
    },
    datacrack = {
        easy = { numberOfStages = 1, segments = 6, segmentSpeed = 45, gapSize = 26 },
        medium = { numberOfStages = 2, segments = 8, segmentSpeed = 60, gapSize = 22 },
        hard = { numberOfStages = 3, segments = 10, segmentSpeed = 85, gapSize = 17 },
    },
    stacker = {
        easy = { numberOfStages = 1, rowsToGoal = 5, startWidthPercent = 50, segmentSpeed = 50, speedUpEachRow = false },
        medium = { numberOfStages = 1, rowsToGoal = 7, startWidthPercent = 40, segmentSpeed = 70, speedUpEachRow = true },
        hard = { numberOfStages = 2, rowsToGoal = 9, startWidthPercent = 32, segmentSpeed = 90, speedUpEachRow = true },
    },
    pulsebar = {
        easy = { segmentSpeed = 32, targetZoneSize = 16, numberOfSegments = 3 },
        medium = { segmentSpeed = 45, targetZoneSize = 12, numberOfSegments = 4 },
        hard = { segmentSpeed = 62, targetZoneSize = 8, numberOfSegments = 6 },
    },
    pinlock = {
        easy = { numberOfPins = 4, gravity = 115, zoneTolerance = 9, maxAttempts = 5, instantFail = false },
        medium = { numberOfPins = 6, gravity = 140, zoneTolerance = 7, maxAttempts = 3, instantFail = false },
        hard = { numberOfPins = 8, gravity = 180, zoneTolerance = 4, maxAttempts = 1, instantFail = true },
    },
}

---@param value any
---@return DifficultyName
function Config.NormalizeDifficulty(value)
    if type(value) == 'string' then
        local d = value:lower()
        if d == 'easy' then return 'easy' end
        if d == 'hard' then return 'hard' end
        if d == 'medium' or d == 'normal' or d == 'med' then return 'medium' end
    end

    local n = tonumber(value)
    if n then
        if n <= 2 then return 'easy' end
        if n >= 4 then return 'hard' end
        return 'medium'
    end

    return 'medium'
end

---@param value any
---@return number scale 1-5
function Config.ToScale(value)
    if type(value) == 'string' then
        return LEVEL_SCALE[Config.NormalizeDifficulty(value)] or 3
    end
    local n = math.floor(tonumber(value) or 3)
    return math.min(5, math.max(1, n))
end

---@param value any
---@return number|nil ms
local function toMs(value)
    local n = tonumber(value)
    if not n then return nil end
    if n > 0 and n < 1000 then
        return math.floor(n * 1000)
    end
    return math.floor(n)
end

--- Map TeamsGG-style option names onto our internal fields.
---@param opts table
---@return table
function Config.NormalizeAliases(opts)
    opts = opts or {}

    if opts.numberOfStages ~= nil and opts.stages == nil then
        opts.stages = opts.numberOfStages
    end

    if opts.timeLimit ~= nil and opts.duration == nil then
        opts.duration = toMs(opts.timeLimit)
    end
    if opts.timePerStage ~= nil and opts.duration == nil then
        opts.duration = toMs(opts.timePerStage)
    end
    if opts.stageTime ~= nil and opts.duration == nil then
        opts.duration = toMs(opts.stageTime)
    end
    if opts.stageTimer ~= nil and opts.duration == nil then
        opts.duration = toMs(opts.stageTimer)
    end
    if opts.timerPerStage ~= nil and opts.duration == nil then
        opts.duration = toMs(opts.timerPerStage)
    end
    if opts.gameTime ~= nil and opts.duration == nil then
        opts.duration = toMs(opts.gameTime)
    end

    if opts.penaltySeconds ~= nil and opts.penalty == nil then
        opts.penalty = toMs(opts.penaltySeconds)
    end

    if opts.numberOfArrows ~= nil and opts.length == nil then
        opts.length = opts.numberOfArrows
    end
    if opts.numberOfKeys ~= nil then
        if opts.length == nil then opts.length = opts.numberOfKeys end
        if opts.rounds == nil then opts.rounds = opts.numberOfKeys end
    end
    if opts.numberOfDots ~= nil and opts.dots == nil then
        opts.dots = opts.numberOfDots
    end
    if opts.numberOfClicks ~= nil and opts.hitsRequired == nil then
        opts.hitsRequired = opts.numberOfClicks
    end
    if opts.hitsRequired == nil and opts.numberOfHits ~= nil then
        opts.hitsRequired = opts.numberOfHits
    end

    if opts.gridSize ~= nil then
        if opts.size == nil then opts.size = opts.gridSize end
    end
    if opts.size ~= nil and opts.gridSize == nil then
        opts.gridSize = opts.size
    end

    if opts.incorrect ~= nil and opts.oddCount == nil then
        opts.oddCount = opts.incorrect
    end
    if opts.subtlety ~= nil and opts.visibility == nil then
        opts.visibility = opts.subtlety
    end

    if opts.pinSize ~= nil and opts.length == nil then
        opts.length = opts.pinSize
    end
    if opts.targetNumber ~= nil and opts.target == nil then
        opts.target = opts.targetNumber
    end
    if opts.minesCount ~= nil and opts.targets == nil then
        opts.targets = opts.minesCount
    end
    if opts.previewTime ~= nil and opts.preview == nil then
        opts.preview = toMs(opts.previewTime)
    end
    if opts.maxFails ~= nil and opts.lives == nil then
        opts.lives = opts.maxFails
    end

    return opts
end

---@param gameId string
---@param level DifficultyName
---@return table
function Config.GetPreset(gameId, level)
    level = Config.NormalizeDifficulty(level)
    local game = Config.Presets[gameId]
    if not game then return {} end
    local preset = game[level]
    if not preset then return {} end

    local copy = {}
    for k, v in pairs(preset) do
        copy[k] = v
    end
    return copy
end

--- Merge difficulty preset + caller opts + aliases. Ready for BuildConfig.
---@param gameId string
---@param opts table?
---@return table
function Config.Prepare(gameId, opts)
    opts = opts or {}
    local level = Config.NormalizeDifficulty(opts.difficulty)
    local merged = Config.GetPreset(gameId, level)

    for k, v in pairs(opts) do
        if k ~= 'difficulty' then
            merged[k] = v
        end
    end

    merged = Config.NormalizeAliases(merged)
    merged.difficulty = LEVEL_SCALE[level] or 3
    merged.difficultyName = level
    return merged
end

return Config
