---@diagnostic disable: undefined-global
--[[
  Safe crack helpers derived from TimothyDexter / FiveM-SafeCrackingMinigame
  https://github.com/TimothyDexter/FiveM-SafeCrackingMinigame
]]

local Safecrack = {}

---@alias RotationDirection 'clockwise'|'anticlockwise'

---@param difficulty number?
---@param rounds number?
---@return number
function Safecrack.ResolveLockCount(difficulty, rounds)
    if rounds then
        return math.min(6, math.max(1, math.floor(tonumber(rounds) or 3)))
    end

    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    return ({ 2, 3, 3, 4, 5 })[d]
end

--- Build / sanitize combination list (original uses List of lock numbers 0-99)
---@param locks number
---@param custom number[]?
---@return number[]
function Safecrack.BuildCombination(locks, custom)
    if type(custom) == 'table' and #custom > 0 then
        local combo = {}
        for i = 1, math.min(locks, #custom) do
            combo[i] = math.floor(tonumber(custom[i]) or 0) % 100
        end
        while #combo < locks do
            combo[#combo + 1] = math.random(0, 99)
        end
        return combo
    end

    local combo = {}
    local last = -20
    for _ = 1, locks do
        local n
        repeat
            n = math.random(0, 99)
        until math.abs(n - last) >= 15
        combo[#combo + 1] = n
        last = n
    end
    return combo
end

--- Mirror SetSafeDialStartNumber()
---@return number
function Safecrack.SetSafeDialStartNumber()
    return math.random(0, 99)
end

---@param startDirection string?
---@return RotationDirection
function Safecrack.ResolveStartDirection(startDirection)
    if startDirection == 'left' or startDirection == 'anticlockwise' then
        return 'anticlockwise'
    end
    return 'clockwise'
end

--- Play SAFE_CRACK_SOUNDSET frontend sounds (original NativeWrappers.PlaySoundFrontend)
---@param name 'turn'|'pin'|'pinFinal'|'reset'
function Safecrack.PlaySound(name)
    local map = {
        turn = { 'TUMBLER_TURN', 'SAFE_CRACK_SOUNDSET' },
        pin = { 'TUMBLER_PIN_FALL', 'SAFE_CRACK_SOUNDSET' },
        pinFinal = { 'TUMBLER_PIN_FALL_FINAL', 'SAFE_CRACK_SOUNDSET' },
        reset = { 'TUMBLER_RESET', 'SAFE_CRACK_SOUNDSET' },
    }

    local sound = map[name]
    if not sound then return end
    PlaySoundFrontend(-1, sound[1], sound[2], true)
end

---@param opts table?
---@return table
function Safecrack.BuildConfig(opts)
    opts = opts or {}
    local locks = Safecrack.ResolveLockCount(opts.difficulty, opts.rounds)

    -- A wrong Try used to be free, so you could step the dial one notch and press Enter
    -- until a pin dropped (brute force 100 numbers). Now wrong tries are limited and the
    -- whole safe has a time limit.
    local tries = math.floor(tonumber(opts.tries or opts.attempts) or 3)
    local duration = tonumber(opts.duration)
    if not duration and type(opts.timeLimit) == 'number' then
        duration = opts.timeLimit < 1000 and opts.timeLimit * 1000 or opts.timeLimit
    end
    duration = math.floor(duration or (locks * 25000))

    return {
        combination = Safecrack.BuildCombination(locks, opts.combination),
        startDirection = Safecrack.ResolveStartDirection(opts.startDirection),
        dialStart = type(opts.dialStart) == 'number' and (math.floor(opts.dialStart) % 100)
            or Safecrack.SetSafeDialStartNumber(),
        tries = math.min(20, math.max(1, tries)),
        duration = math.min(600000, math.max(15000, duration)),
        wrongLockoutMs = 900,
    }
end

return Safecrack
