---@diagnostic disable: undefined-global

local Decrypt = {}

---@param difficulty number?
---@return number rounds, number tokenLen, number durationMs
function Decrypt.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local rounds = ({ 3, 4, 5, 5, 6 })[d]
    local tokenLen = ({ 5, 6, 6, 7, 8 })[d]
    local durationMs = ({ 35000, 32000, 28000, 25000, 22000 })[d]
    return rounds, tokenLen, durationMs
end

---@param opts table?
---@return table
function Decrypt.BuildConfig(opts)
    opts = opts or {}
    local rounds, tokenLen, durationMs = Decrypt.ResolveDifficulty(opts.difficulty)

    if type(opts.rounds) == 'number' then
        rounds = math.min(8, math.max(1, math.floor(opts.rounds)))
    end

    if type(opts.tokenLength) == 'number' then
        tokenLen = math.min(12, math.max(4, math.floor(opts.tokenLength)))
    end

    return {
        rounds = rounds,
        tokenLength = tokenLen,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return Decrypt
