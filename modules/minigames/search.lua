---@diagnostic disable: undefined-global

local Search = {}

local GRID_SIZE = 3

--- Fallback loot names (resolved via ox_inventory when present)
local DEFAULT_LOOT = {
    'lockpick',
    'money',
    'phone',
    'radio',
    'bandage',
    'water',
    'burger',
    'advancedlockpick',
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

--- Enrich a slot entry with ox_inventory label / image
---@param entry table
---@return table
function Search.EnrichEntry(entry)
    local name = tostring(entry.id or entry.item or entry.name or 'item'):lower()
    -- Callers that roll loot server-side (warehouse/train_robbery/contraband/bobcat
    -- robbery.lua) all name the rolled quantity `amount`, not `count` - only reading
    -- `count` silently dropped it to the default of 1 regardless of what was actually
    -- rolled, so every found item showed/granted exactly 1 no matter the roll.
    local count = math.max(1, math.floor(tonumber(entry.count or entry.amount) or 1))
    local metadata = type(entry.metadata) == 'table' and entry.metadata or nil

    return {
        id = name,
        label = type(entry.label) == 'string' and entry.label ~= '' and entry.label or oxLabel(name, name),
        count = count,
        image = type(entry.image) == 'string' and entry.image ~= '' and entry.image or oxImage(name),
        metadata = metadata,
    }
end

---@param difficulty number?
---@return number itemCount, number required, number searchMs, number durationMs
function Search.ResolveDifficulty(difficulty)
    local d = math.min(5, math.max(1, math.floor(tonumber(difficulty) or 3)))
    local itemCount = ({ 3, 4, 4, 5, 6 })[d]
    local required = ({ 2, 2, 3, 3, 4 })[d]
    local searchMs = ({ 900, 1100, 1400, 1700, 2000 })[d]
    local durationMs = ({ 35000, 30000, 26000, 22000, 18000 })[d]
    return itemCount, required, searchMs, durationMs
end

---@param list table
local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

---@param slots table
---@return table[] flat list of loot entries
function Search.ListLoot(slots)
    local list = {}
    if type(slots) ~= 'table' then return list end
    for i = 1, #slots do
        local entry = slots[i]
        if type(entry) == 'table' and entry.id then
            list[#list + 1] = {
                name = entry.id,
                count = entry.count or 1,
                metadata = entry.metadata,
            }
        end
    end
    return list
end

---@param opts table?
---@return table
function Search.BuildConfig(opts)
    opts = opts or {}
    local itemCount, required, searchMs, durationMs = Search.ResolveDifficulty(opts.difficulty)
    local size = GRID_SIZE
    local total = size * size

    if type(opts.size) == 'number' then
        size = math.min(4, math.max(3, math.floor(opts.size)))
        total = size * size
    end

    if type(opts.itemCount) == 'number' then
        itemCount = math.min(total, math.max(1, math.floor(opts.itemCount)))
    end

    if type(opts.required) == 'number' then
        required = math.min(itemCount, math.max(1, math.floor(opts.required)))
    end

    if type(opts.searchTime) == 'number' then
        searchMs = math.min(5000, math.max(400, math.floor(opts.searchTime)))
    end

    if type(opts.duration) == 'number' then
        durationMs = math.min(90000, math.max(8000, math.floor(opts.duration)))
    elseif type(opts.timeLimit) == 'number' then
        local t = opts.timeLimit
        durationMs = t < 1000 and math.floor(t * 1000) or math.floor(t)
    end

    required = math.min(required, itemCount)

    ---@type table[]
    local slots = {}

    if type(opts.slots) == 'table' and #opts.slots > 0 then
        for i = 1, total do
            local entry = opts.slots[i]
            if type(entry) == 'table' and (entry.id or entry.item or entry.name) then
                slots[i] = Search.EnrichEntry(entry)
            else
                slots[i] = false
            end
        end
    else
        local loot = {}
        if type(opts.items) == 'table' and #opts.items > 0 then
            for _, entry in ipairs(opts.items) do
                if type(entry) == 'table' then
                    loot[#loot + 1] = Search.EnrichEntry(entry)
                elseif type(entry) == 'string' then
                    loot[#loot + 1] = Search.EnrichEntry({ id = entry, count = 1 })
                end
            end
        else
            for _, name in ipairs(DEFAULT_LOOT) do
                loot[#loot + 1] = Search.EnrichEntry({ id = name, count = 1 })
            end
        end

        shuffle(loot)
        local filled = {}
        for i = 1, total do
            filled[i] = i
        end
        shuffle(filled)

        for i = 1, total do
            slots[i] = false
        end

        for i = 1, math.min(itemCount, #loot, total) do
            slots[filled[i]] = loot[i]
        end
    end

    local actualItems = 0
    for i = 1, total do
        if slots[i] then actualItems = actualItems + 1 end
    end
    required = math.min(required, math.max(1, actualItems))

    return {
        size = size,
        itemCount = actualItems,
        required = required,
        searchTime = searchMs,
        duration = durationMs,
        slots = slots,
        grantItems = opts.grantItems ~= false,
        seed = tonumber(opts.seed) or math.random(1, 2147483646),
    }
end

return Search
