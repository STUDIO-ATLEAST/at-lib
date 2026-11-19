---@diagnostic disable: undefined-global

local Binary = {}

---@param difficulty number?
---@return number length, number previewMs, number sequences, boolean reverse, boolean glitches, number durationMs
function Binary.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local length = ({ 6, 7, 8, 9, 10 })[d]
    local previewMs = ({ 3200, 2600, 2100, 1700, 1400 })[d]
    local sequences = 1 -- always one line to memorize
    local reverse = d >= 4
    local glitches = d >= 3
    local durationMs = ({ 40000, 34000, 28000, 24000, 20000 })[d]
    return length, previewMs, sequences, reverse, glitches, durationMs
end

---@param length number
---@return number[]
local function randomBits(length)
    local bits = {}
    for i = 1, length do
        bits[i] = math.random(0, 1)
    end
    return bits
end

---@param bits number[]
---@return number[]
local function copyBits(bits)
    local out = {}
    for i = 1, #bits do
        out[i] = bits[i]
    end
    return out
end

---@param bits number[]
---@return number[]
local function mutateBits(bits)
    local out = copyBits(bits)
    local flips = math.max(1, math.floor(#out / 3))
    for _ = 1, flips do
        local i = math.random(1, #out)
        out[i] = 1 - out[i]
    end
    -- Ensure not identical
    local same = true
    for i = 1, #bits do
        if out[i] ~= bits[i] then
            same = false
            break
        end
    end
    if same then
        out[1] = 1 - out[1]
    end
    return out
end

---@param opts table?
---@return table
function Binary.BuildConfig(opts)
    opts = opts or {}
    local length, previewMs, sequences, reverse, glitches, durationMs = Binary.ResolveDifficulty(opts.difficulty)

    if type(opts.length) == 'number' then
        length = math.min(16, math.max(4, math.floor(opts.length)))
    end
    if type(opts.preview) == 'number' then
        previewMs = math.min(8000, math.max(800, math.floor(opts.preview)))
    end
    -- Force a single memorize line (multi-row decoys disabled).
    sequences = 1
    if type(opts.reverse) == 'boolean' then
        reverse = opts.reverse
    end
    if type(opts.glitches) == 'boolean' then
        glitches = opts.glitches
    end

    local target = randomBits(length)
    if type(opts.sequence) == 'table' then
        local custom = {}
        for i = 1, length do
            local v = tonumber(opts.sequence[i])
            custom[i] = (v and v ~= 0) and 1 or 0
        end
        if #opts.sequence >= length then
            target = custom
        end
    end

    local correctRow = math.random(1, sequences)
    local rows = {}
    for i = 1, sequences do
        if i == correctRow then
            rows[i] = copyBits(target)
        else
            rows[i] = mutateBits(target)
        end
    end

    return {
        sequence = target,
        rows = rows,
        correctRow = correctRow - 1, -- 0-based for JS
        preview = previewMs,
        reverse = reverse,
        glitches = glitches,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Binary
