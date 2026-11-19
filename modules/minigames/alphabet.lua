---@diagnostic disable: undefined-global

local Alphabet = {}

local KEY_POOL = { 'W', 'A', 'S', 'D', 'Q' }

---@param difficulty number?
---@param rounds number?
---@return number length, number durationMs
function Alphabet.ResolveDifficulty(difficulty, rounds)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local length = rounds or ({ 8, 12, 15, 18, 22 })[d]
    local durationMs = ({ 12000, 11000, 10000, 9000, 8000 })[d]
    return length, durationMs
end

---@param length number
---@return string[]
function Alphabet.BuildSequence(length)
    local sequence = {}
    for i = 1, length do
        sequence[i] = KEY_POOL[math.random(1, #KEY_POOL)]
    end
    return sequence
end

---@param opts table?
---@return table
function Alphabet.BuildConfig(opts)
    opts = opts or {}
    local length, durationMs = Alphabet.ResolveDifficulty(opts.difficulty, opts.rounds)

    if type(opts.sequence) == 'table' and #opts.sequence > 0 then
        local sequence = {}
        for i = 1, #opts.sequence do
            local letter = tostring(opts.sequence[i] or 'A'):upper():sub(1, 1)
            sequence[i] = letter
        end
        length = #sequence
        return {
            sequence = sequence,
            duration = tonumber(opts.duration) or durationMs,
        }
    end

    return {
        sequence = Alphabet.BuildSequence(length),
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Alphabet
