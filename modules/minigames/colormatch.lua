---@diagnostic disable: undefined-global

local ColorMatch = {}

---@param difficulty number?
---@return number previewMs, number tolerance, number durationMs
function ColorMatch.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local previewMs = ({ 3500, 2800, 2200, 1700, 1300 })[d]
    local tolerance = ({ 55, 42, 32, 24, 18 })[d]
    local durationMs = ({ 40000, 34000, 28000, 24000, 20000 })[d]
    return previewMs, tolerance, durationMs
end

--- HSL → RGB so picks stay vivid / memorable (not muddy greys).
---@param h number 0-1
---@param s number 0-1
---@param l number 0-1
---@return number, number, number
local function hslToRgb(h, s, l)
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue2rgb(p, q, h + 1 / 3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1 / 3)
    end

    return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

---@return number, number, number
local function randomColor()
    local h = math.random()
    local s = 0.55 + math.random() * 0.4 -- 55-95%
    local l = 0.38 + math.random() * 0.28 -- 38-66%
    return hslToRgb(h, s, l)
end

---@param opts table?
---@return table
function ColorMatch.BuildConfig(opts)
    opts = opts or {}
    local previewMs, tolerance, durationMs = ColorMatch.ResolveDifficulty(opts.difficulty)

    if type(opts.preview) == 'number' then
        previewMs = math.min(8000, math.max(800, math.floor(opts.preview)))
    end
    if type(opts.tolerance) == 'number' then
        tolerance = math.min(120, math.max(8, math.floor(opts.tolerance)))
    end

    local r, g, b = randomColor()
    if type(opts.target) == 'table' then
        r = math.min(255, math.max(0, math.floor(tonumber(opts.target[1]) or r)))
        g = math.min(255, math.max(0, math.floor(tonumber(opts.target[2]) or g)))
        b = math.min(255, math.max(0, math.floor(tonumber(opts.target[3]) or b)))
    end

    return {
        target = { r, g, b },
        preview = previewMs,
        tolerance = tolerance,
        duration = tonumber(opts.duration) or durationMs,
    }
end

return ColorMatch
