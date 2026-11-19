WorldUi = {}

local TXD_NAME = 'at_lib_worldui'
local PAGE = ('nui://%s/web/world/index.html'):format(cache.resource)
local txd = CreateRuntimeTxd(TXD_NAME)

local pool = {}   ---@type table<string, table> look key -> texture entry
local idle = {}   ---@type table<string, table[]> size key -> parked { dui, txn }
local count = 0
local IDLE_MAX = 8

---@param entry table
local function retire(entry)
    local dui, txn = entry.dui, entry.txn
    entry.dui, entry.ready, entry.dead = nil, false, true
    if not dui then return end
    local sizeKey = ('%dx%d'):format(entry.w, entry.h)
    local parked = idle[sizeKey] or {}
    idle[sizeKey] = parked
    if entry.textured and #parked < IDLE_MAX then
        parked[#parked + 1] = { dui = dui, txn = txn }
    else
        DestroyDui(dui)
    end
end

---@param key string unique per look, e.g. 'prompt:E:Knock on the door'
---@param payload table what web/world/index.html renders ({ kind = 'prompt'|'card'|'ring', ... })
---@param w integer texture width in px (rendered at 2x)
---@param h integer texture height in px
function WorldUi.get(key, payload, w, h)
    local entry = pool[key]
    if entry then
        entry.used = GetGameTimer()
        return entry
    end

    local parked = idle[('%dx%d'):format(w, h)]
    local reuse = parked and table.remove(parked)
    if reuse then
        entry = { txn = reuse.txn, dui = reuse.dui, w = w, h = h, ready = false, textured = true, used = GetGameTimer(), payload = payload }
        pool[key] = entry
        SendDuiMessage(entry.dui, json.encode(payload))
        SetTimeout(150, function()
            if entry.dui then entry.ready = true end
        end)
        return entry
    end

    count += 1
    entry = { txn = ('t%d'):format(count), w = w, h = h, ready = false, used = GetGameTimer(), payload = payload }
    pool[key] = entry
    entry.dui = CreateDui(PAGE, w, h)

    CreateThread(function()
        local giveUp = GetGameTimer() + 10000
        while not IsDuiAvailable(entry.dui) and GetGameTimer() < giveUp do Wait(0) end
        if not IsDuiAvailable(entry.dui) then return end
        if not entry.dui then return end
        CreateRuntimeTextureFromDuiHandle(txd, entry.txn, GetDuiHandle(entry.dui))
        entry.textured = true

        for _, delay in ipairs({ 100, 250, 600 }) do
            Wait(delay)
            if not entry.dui then return end
            SendDuiMessage(entry.dui, json.encode(entry.payload))
            if delay == 250 then entry.ready = true end
        end
    end)

    return entry
end

---@param entry table
---@param payload table
function WorldUi.update(entry, payload)
    if not entry or not entry.dui then return end
    entry.used = GetGameTimer()
    entry.payload = payload
    SendDuiMessage(entry.dui, json.encode(payload))
end

---@param key string
function WorldUi.release(key)
    local entry = pool[key]
    if not entry then return end
    retire(entry)
    pool[key] = nil
end

---@param scale? number 1.0 = normal size (used for the pop-in animation)
---@param alpha? integer 0-255
function WorldUi.draw(entry, coords, scale, alpha)
    if not entry.ready then return end
    entry.used = GetGameTimer()
    scale = scale or 1.0
    local h = entry.h * 0.5 / 1080 * scale
    local w = entry.w * 0.5 / (1080 * GetAspectRatio(false)) * scale
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawSprite(TXD_NAME, entry.txn, 0.0, 0.0, w, h, 0.0, 255, 255, 255, alpha or 255)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        Wait(15000)
        local now = GetGameTimer()
        for key, entry in pairs(pool) do
            if entry.ready and now - entry.used > 60000 then
                retire(entry)
                pool[key] = nil
            end
        end
    end
end)

RegisterCommand('worldui_test', function()
    local prompt = WorldUi.get('prompt:Test prompt', { kind = 'prompt', key = 'E', label = 'Test prompt' }, 1024, 96)
    local locked = WorldUi.get('card:lock:red:Locked', { kind = 'card', label = 'Locked', icon = 'lock', color = 'red' }, 768, 96)
    local unlocked = WorldUi.get('card:lock-open:green:Unlocked', { kind = 'card', label = 'Unlocked', icon = 'lock-open', color = 'green' }, 768, 96)
    local ring = WorldUi.get('ring', { kind = 'ring' }, 64, 64)
    local base = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.6)
    local endAt = GetGameTimer() + 10000
    while GetGameTimer() < endAt do
        WorldUi.draw(prompt, base + vec3(0.0, 0.0, 0.45))
        WorldUi.draw(locked, base + vec3(0.0, 0.0, 0.15))
        WorldUi.draw(unlocked, base - vec3(0.0, 0.0, 0.15))
        WorldUi.draw(ring, base - vec3(0.0, 0.0, 0.45))
        Wait(0)
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    for _, entry in pairs(pool) do
        if entry.dui then DestroyDui(entry.dui) end
    end
    for _, parked in pairs(idle) do
        for i = 1, #parked do DestroyDui(parked[i].dui) end
    end
end)
