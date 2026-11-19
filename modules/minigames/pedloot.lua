---@diagnostic disable: undefined-global

local PedLoot = {}

--- Default loot pool: chance is relative weight (higher = more common + longer green window)
local DEFAULT_LOOT = {
    { id = 'lockpick', chance = 40, count = 1 },
    { id = 'money', chance = 35, count = 50, value = 50 },
    { id = 'phone', chance = 22, count = 1 },
    { id = 'radio', chance = 18, count = 1 },
    { id = 'bandage', chance = 28, count = 1 },
}

---@param name string
---@return table|nil
local function oxItem(name)
    if GetResourceState('ox_inventory') ~= 'started' then
        return nil
    end
    local ok, item = pcall(function()
        return exports.ox_inventory:Items(name)
    end)
    if ok and type(item) == 'table' then
        return item
    end
    return nil
end

---@param name string
---@return string
local function oxImage(name)
    local item = oxItem(name)
    if item and item.client and type(item.client.image) == 'string' and item.client.image ~= '' then
        return item.client.image
    end
    local path = GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images')
    return ('%s/%s.png'):format(path:gsub('/$', ''), name)
end

---@param name string
---@param fallback? string
---@return string
local function oxLabel(name, fallback)
    local item = oxItem(name)
    if item and type(item.label) == 'string' and item.label ~= '' then
        return item.label
    end
    return fallback or name
end

--- Map spawn chance (1-100) → green window fraction (how easy to hit)
---@param chance number
---@return number window 0.22-0.88
local function windowFromChance(chance)
    local c = math.min(100, math.max(1, chance + 0.0))
    -- rare (low chance) = short green; common = long green
    return 0.22 + (c / 100) * 0.66
end

---@param entry table|string
---@return table
local function enrich(entry)
    if type(entry) == 'string' then
        entry = { id = entry, chance = 30, count = 1 }
    end
    local name = tostring(entry.id or entry.item or entry.name or 'item'):lower()
    local chance = math.min(100, math.max(1, math.floor(tonumber(entry.chance) or 30)))
    local count = math.max(1, math.floor(tonumber(entry.count) or 1))
    local value = math.max(0, math.floor(tonumber(entry.value) or (name == 'money' and count or 0)))

    return {
        id = name,
        label = type(entry.label) == 'string' and entry.label ~= '' and entry.label or oxLabel(name, name),
        count = count,
        image = type(entry.image) == 'string' and entry.image ~= '' and entry.image or oxImage(name),
        value = value,
        chance = chance,
        window = tonumber(entry.window) or windowFromChance(chance),
        metadata = type(entry.metadata) == 'table' and entry.metadata or nil,
    }
end

---@param list table
local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

---@param pool table[]
---@return table|nil
local function pickWeighted(pool)
    if #pool == 0 then return nil end
    local total = 0
    for i = 1, #pool do
        total = total + (pool[i].chance or 30)
    end
    if total <= 0 then
        return pool[math.random(1, #pool)]
    end
    local roll = math.random() * total
    local acc = 0
    for i = 1, #pool do
        acc = acc + (pool[i].chance or 30)
        if roll <= acc then
            return pool[i]
        end
    end
    return pool[#pool]
end

---@param difficulty number?
---@return number slotCount, number empties, number required, number speed, number durationMs
function PedLoot.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local slotCount = ({ 4, 5, 5, 6, 7 })[d]
    local empties = ({ 1, 2, 2, 3, 3 })[d]
    local required = ({ 1, 1, 2, 2, 3 })[d]
    local speed = ({ 55, 70, 90, 115, 140 })[d]
    local durationMs = ({ 22000, 18000, 15000, 12000, 10000 })[d]
    return slotCount, empties, required, speed, durationMs
end

---@param opts table?
---@return table
function PedLoot.BuildConfig(opts)
    opts = opts or {}
    local slotCount, empties, required, speed, durationMs = PedLoot.ResolveDifficulty(opts.difficulty)

    if type(opts.slots) == 'number' then
        slotCount = math.min(8, math.max(3, math.floor(opts.slots)))
    elseif type(opts.slotCount) == 'number' then
        slotCount = math.min(8, math.max(3, math.floor(opts.slotCount)))
    end

    if type(opts.empties) == 'number' then
        empties = math.min(slotCount - 1, math.max(1, math.floor(opts.empties)))
    end

    if type(opts.required) == 'number' then
        required = math.min(slotCount - empties, math.max(1, math.floor(opts.required)))
    end

    if type(opts.speed) == 'number' then
        speed = math.min(220, math.max(30, opts.speed + 0.0))
    end

    if type(opts.duration) == 'number' then
        durationMs = math.min(60000, math.max(5000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        durationMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
        durationMs = math.min(60000, math.max(5000, durationMs))
    end

    local key = 'SPACE'
    if type(opts.key) == 'string' and opts.key ~= '' then
        key = opts.key:upper()
        if key == ' ' then key = 'SPACE' end
    end

    ---@type table[]
    local board = {}

    -- Caller-supplied board (e.g. pickpocket): use as-is after enriching loot slots
    if type(opts.board) == 'table' and #opts.board > 0 then
        slotCount = math.min(8, math.max(3, #opts.board))
        for i = 1, slotCount do
            local entry = opts.board[i]
            if type(entry) == 'table' and not entry.empty and (entry.id or entry.item or entry.name) then
                local e = enrich(entry)
                board[i] = {
                    empty = false,
                    id = e.id,
                    label = e.label,
                    count = e.count,
                    image = e.image,
                    value = e.value,
                    chance = e.chance,
                    window = math.min(0.92, math.max(0.18, e.window)),
                    metadata = e.metadata,
                    sourceIndex = tonumber(entry.sourceIndex),
                }
            else
                board[i] = { empty = true, window = 0, chance = 0 }
            end
        end
    else
        local lootPool = {}
        if type(opts.items) == 'table' and #opts.items > 0 then
            for _, entry in ipairs(opts.items) do
                lootPool[#lootPool + 1] = enrich(entry)
            end
        else
            for _, entry in ipairs(DEFAULT_LOOT) do
                lootPool[#lootPool + 1] = enrich(entry)
            end
        end

        local lootCount = slotCount - empties
        for i = 1, slotCount do
            board[i] = { empty = true, window = 0, chance = 0 }
        end

        local indices = {}
        for i = 1, slotCount do indices[i] = i end
        shuffle(indices)

        for i = 1, lootCount do
            local picked = pickWeighted(lootPool)
            if picked then
                local slotIndex = indices[i]
                local win = math.min(0.92, math.max(0.18, picked.window or windowFromChance(picked.chance)))
                board[slotIndex] = {
                    empty = false,
                    id = picked.id,
                    label = picked.label,
                    count = picked.count,
                    image = picked.image,
                    value = picked.value,
                    chance = picked.chance,
                    window = win,
                    metadata = picked.metadata,
                }
            end
        end
    end

    local actualLoot = 0
    for i = 1, slotCount do
        if board[i] and not board[i].empty then
            actualLoot = actualLoot + 1
        end
    end
    -- Must clear every loot slot for a full success (no early win mid-board)
    required = math.max(1, actualLoot)

    return {
        slotCount = slotCount,
        empties = empties,
        required = required,
        speed = speed,
        key = key,
        duration = durationMs,
        board = board,
        grantItems = opts.grantItems ~= false,
        seed = tonumber(opts.seed) or math.random(1, 2147483646),
    }
end

---@param board table
---@return table[] flat list of loot entries
function PedLoot.ListLoot(board)
    local list = {}
    if type(board) ~= 'table' then return list end
    for i = 1, #board do
        local entry = board[i]
        if type(entry) == 'table' and not entry.empty and entry.id then
            list[#list + 1] = {
                name = entry.id,
                count = entry.count or 1,
                metadata = entry.metadata,
            }
        end
    end
    return list
end

return PedLoot
