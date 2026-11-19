---@diagnostic disable: undefined-global

local SkillBar = {}

---@param difficulty number?
---@return number segmentSpeed, number targetZoneSize, number hitsRequired
function SkillBar.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local segmentSpeed = ({ 55, 70, 90, 110, 135 })[d]
    local targetZoneSize = ({ 22, 18, 14, 11, 8 })[d]
    local hitsRequired = ({ 2, 3, 3, 4, 5 })[d]
    return segmentSpeed, targetZoneSize, hitsRequired
end

---@param opts table?
---@return table
function SkillBar.BuildConfig(opts)
    opts = opts or {}
    local segmentSpeed, targetZoneSize, hitsRequired = SkillBar.ResolveDifficulty(opts.difficulty)

    if type(opts.segmentSpeed) == 'number' then
        segmentSpeed = math.min(200, math.max(20, opts.segmentSpeed + 0.0))
    end
    if type(opts.targetZoneSize) == 'number' then
        targetZoneSize = math.min(40, math.max(4, opts.targetZoneSize + 0.0))
    end
    if type(opts.hitsRequired) == 'number' then
        hitsRequired = math.min(10, math.max(1, math.floor(opts.hitsRequired)))
    end
    local hitPause = 0
    if type(opts.hitPause) == 'number' then
        hitPause = math.min(3000, math.max(0, math.floor(opts.hitPause)))
    end

    return {
        segmentSpeed = segmentSpeed,
        targetZoneSize = targetZoneSize,
        hitsRequired = hitsRequired,
        hitPause = hitPause,
    }
end

return SkillBar
