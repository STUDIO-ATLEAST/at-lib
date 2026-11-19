---@diagnostic disable: undefined-global

--- Pending search loot pools keyed by player source.
--- Client registers the package contents; completeSearch only grants found items within that pool.
local pending = {}

local function clearPending(src)
    pending[src] = nil
end

AddEventHandler('playerDropped', function()
    clearPending(source)
end)

---@param loot table[] { name, count, metadata? }
RegisterNetEvent('at-lib:registerSearch', function(loot)
    local src = source
    if type(loot) ~= 'table' then
        clearPending(src)
        return
    end

    local pool = {}
    for i = 1, #loot do
        local entry = loot[i]
        if type(entry) == 'table' then
            local name = entry.name or entry.id or entry.item
            if type(name) == 'string' and name ~= '' then
                name = name:lower()
                local count = math.max(1, math.floor(tonumber(entry.count) or 1))
                pool[name] = (pool[name] or 0) + count
            end
        end
    end

    pending[src] = pool
end)

--- Grant items the player already revealed (success or timeout fail).
---@param found table[] { name|id, count?, metadata? }
RegisterNetEvent('at-lib:completeSearch', function(found)
    local src = source
    local pool = pending[src]
    clearPending(src)

    if type(pool) ~= 'table' or type(found) ~= 'table' then
        return
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        warn('[at-lib] ox_inventory is not started - search loot not given')
        return
    end

    for i = 1, #found do
        local entry = found[i]
        if type(entry) == 'table' then
            local name = entry.name or entry.id or entry.item
            if type(name) == 'string' and name ~= '' then
                name = name:lower()
                local want = math.max(1, math.floor(tonumber(entry.count) or 1))
                local allowed = pool[name] or 0
                if allowed > 0 then
                    local give = math.min(want, allowed)
                    pool[name] = allowed - give
                    local metadata = type(entry.metadata) == 'table' and entry.metadata or nil
                    exports.ox_inventory:AddItem(src, name, give, metadata)
                end
            end
        end
    end
end)

RegisterNetEvent('at-lib:cancelSearch', function()
    clearPending(source)
end)
