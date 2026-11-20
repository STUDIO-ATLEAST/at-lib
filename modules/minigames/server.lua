---@diagnostic disable: undefined-global

--- Loot pools keyed by player source. completeSearch only grants found items inside the pool.
---
--- Pools come from the server: a server script calls exports['at-lib']:AllowLoot(source, items)
--- before it starts Search or Ped Loot on that player. The client cannot add items to a pool.
--- Setting the convar at_lib_client_loot to true also accepts the pool the client sends, which
--- is how rm-lib worked. Only do that on a test server: any player could then give themselves items.
local pending = {}
local POOL_TTL = 10 * 60 * 1000

local function trustClient()
    local v = GetConvar('at_lib_client_loot', 'false')
    return v == 'true' or v == '1'
end

local function clearPending(src)
    pending[src] = nil
end

---@param loot table[] { name|item|id, count?, metadata? }
---@return table<string, number> pool, table<string, table> metadata
local function buildPool(loot)
    local pool, meta = {}, {}
    for i = 1, #loot do
        local entry = loot[i]
        if type(entry) == 'table' then
            local name = entry.name or entry.id or entry.item
            if type(name) == 'string' and name ~= '' then
                name = name:lower()
                local count = math.max(1, math.floor(tonumber(entry.count or entry.amount) or 1))
                pool[name] = (pool[name] or 0) + count
                if type(entry.metadata) == 'table' then meta[name] = entry.metadata end
            end
        end
    end
    return pool, meta
end

local function setPending(src, loot, fromClient)
    local pool, meta = buildPool(loot)
    pending[src] = { pool = pool, meta = meta, fromClient = fromClient, expires = GetGameTimer() + POOL_TTL }
end

AddEventHandler('playerDropped', function()
    clearPending(source)
end)

--- Server export: let this player receive up to these items from their next Search or Ped Loot.
---@param src number player server id
---@param items table[] { name|item, count? }
---@return boolean
local function allowLoot(src, items)
    src = tonumber(src)
    if not src or type(items) ~= 'table' or not GetPlayerName(src) then return false end
    setPending(src, items, false)
    return true
end
exports('AllowLoot', allowLoot)

--- Sent by the client when a loot game starts. Ignored unless at_lib_client_loot is on.
RegisterNetEvent('at-lib:registerSearch', function(loot)
    local src = source
    if not trustClient() or type(loot) ~= 'table' then return end
    local current = pending[src]
    if current and not current.fromClient and GetGameTimer() <= current.expires then return end
    setPending(src, loot, true)
end)

local warned = false

--- Grant items the player already revealed (success or timeout fail).
---@param found table[] { name|id, count?, metadata? }
RegisterNetEvent('at-lib:completeSearch', function(found)
    local src = source
    local entry = pending[src]
    clearPending(src)

    if type(found) ~= 'table' then return end
    if type(entry) ~= 'table' or GetGameTimer() > entry.expires then
        if not warned and #found > 0 then
            warned = true
            warn(("[at-lib] %s finished a loot game with no allowed loot. Call exports['at-lib']:AllowLoot(source, items) on the server before starting Search or Ped Loot."):format(GetPlayerName(src) or src))
        end
        return
    end
    local pool = entry.pool

    if GetResourceState('ox_inventory') ~= 'started' then
        warn('[at-lib] ox_inventory is not started - search loot not given')
        return
    end

    for i = 1, #found do
        local item = found[i]
        if type(item) == 'table' then
            local name = item.name or item.id or item.item
            if type(name) == 'string' and name ~= '' then
                name = name:lower()
                local want = math.max(1, math.floor(tonumber(item.count or item.amount) or 1))
                local allowed = pool[name] or 0
                if allowed > 0 then
                    local give = math.min(want, allowed)
                    pool[name] = allowed - give
                    local metadata = entry.meta[name]
                    if not metadata and entry.fromClient and type(item.metadata) == 'table' then
                        metadata = item.metadata
                    end
                    exports.ox_inventory:AddItem(src, name, give, metadata)
                end
            end
        end
    end
end)

RegisterNetEvent('at-lib:cancelSearch', function()
    clearPending(source)
end)
