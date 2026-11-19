---@diagnostic disable: undefined-global

local Keypad = {}

---@param difficulty number?
---@return number length, number tries, number durationMs
function Keypad.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local length = 4
    local tries = ({ 8, 7, 6, 5, 4 })[d]
    local durationMs = ({ 45000, 40000, 35000, 30000, 25000 })[d]
    return length, tries, durationMs
end

---@param length number
---@return number[]
function Keypad.BuildCode(length)
    local code = {}
    for i = 1, length do
        code[i] = math.random(0, 9)
    end
    return code
end

---@param opts table?
---@return table
function Keypad.BuildConfig(opts)
    opts = opts or {}
    local length, tries, durationMs = Keypad.ResolveDifficulty(opts.difficulty)

    if type(opts.length) == 'number' then
        length = math.min(6, math.max(3, math.floor(opts.length)))
    end

    local code
    if type(opts.code) == 'table' and #opts.code > 0 then
        code = {}
        for i = 1, length do
            code[i] = math.floor(tonumber(opts.code[i]) or math.random(0, 9)) % 10
        end
    else
        code = Keypad.BuildCode(length)
    end

    return {
        code = code,
        length = length,
        tries = tonumber(opts.tries) or tries,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Keypad
