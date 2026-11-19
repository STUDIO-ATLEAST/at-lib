local cards = {}   ---@type table<integer, table>
local nextId = 0
local nearby = {}
local loopRunning = false

---@param card table
---@return boolean
local function resolve(card)
    if not card.entity then return true end
    if not DoesEntityExist(card.entity) then return false end
    if not card.showWhileMoving and IsEntityAVehicle(card.entity)
        and (cache.vehicle == card.entity or GetEntitySpeed(card.entity) > 0.8) then
        return false
    end
    local o = card.offset or vec3(0.0, 0.0, 1.0)
    card.coords = GetOffsetFromEntityInWorldCoords(card.entity, o.x, o.y, o.z)
    return true
end

local function texture(card)
    local payload = { kind = 'card', label = card.label, icon = card.icon, color = card.color }
    local tex = card.tex
    if not tex or tex.dead then
        tex = WorldUi.get(('card#%d'):format(card.id), payload, 768, 96)
        card.tex = tex
        card.dirty = false
    elseif card.dirty and tex.ready then
        WorldUi.update(tex, payload)
        card.dirty = false
    end
    return tex
end

local function startLoop()
    if loopRunning then return end
    loopRunning = true

    CreateThread(function()
        local visible, nextTick = {}, 0

        while #nearby > 0 do
            local now = GetGameTimer()
            if now >= nextTick then
                nextTick = now + 33
                visible = {}
                if not (IsPauseMenuActive() or IsNuiFocused()) then
                    local pedPos = GetEntityCoords(cache.ped)
                    for i = 1, #nearby do
                        local c = nearby[i]
                        if resolve(c) and #(pedPos - c.coords) <= c.distance then
                            visible[#visible + 1] = c
                        end
                    end
                end
            end

            for i = 1, #visible do
                local c = visible[i]
                WorldUi.draw(texture(c), c.coords)
            end

            Wait(0)
        end

        loopRunning = false
    end)
end

CreateThread(function()
    while true do
        local pedPos = GetEntityCoords(cache.ped)
        local list = {}
        for _, c in pairs(cards) do
            if resolve(c) and #(pedPos - c.coords) <= c.distance + 2.0 then list[#list + 1] = c end
        end
        nearby = list
        if #list > 0 then startLoop() end
        Wait(500)
    end
end)

local function apply(card, data)
    if data.coords then card.coords = vec3(data.coords.x, data.coords.y, data.coords.z) end
    if data.entity ~= nil then card.entity = data.entity or nil end
    if data.offset then card.offset = vec3(data.offset.x, data.offset.y, data.offset.z) end
    if data.label then card.label = tostring(data.label) end
    if data.icon then card.icon = data.icon end
    if data.color then card.color = data.color end
    if data.distance then card.distance = data.distance end
    if data.showWhileMoving ~= nil then card.showWhileMoving = data.showWhileMoving end
    card.dirty = true
end

---@return integer id
function lib.addWorldCard(data)
    assert(type(data) == 'table' and (data.coords or data.entity), 'addWorldCard needs coords or entity')
    nextId += 1
    local card = { id = nextId, label = '', icon = false, color = 'blue', distance = 2.0, coords = vec3(0.0, 0.0, 0.0), resource = GetInvokingResource() }
    apply(card, data)
    cards[nextId] = card
    return nextId
end

function lib.updateWorldCard(id, data)
    local card = cards[id]
    if card and type(data) == 'table' then apply(card, data) end
end

function lib.removeWorldCard(id)
    if not cards[id] then return end
    WorldUi.release(('card#%d'):format(id))
    cards[id] = nil
    for i = #nearby, 1, -1 do
        if nearby[i].id == id then table.remove(nearby, i) end
    end
end

exports('addWorldCard', lib.addWorldCard)
exports('updateWorldCard', lib.updateWorldCard)
exports('removeWorldCard', lib.removeWorldCard)

AddEventHandler('onResourceStop', function(res)
    for id, c in pairs(cards) do
        if c.resource == res then lib.removeWorldCard(id) end
    end
end)
