local isOpen = false
local currentCallback = nil
local currentDialogue = nil

---@type number | nil
local cam = nil
---@type number | nil
local camPed = nil

---@param ped number
---@param overShoulder? boolean camera behind the player's shoulder (player stays visible)
local function createCam(ped, overShoulder)
    -- Same ped as the active dialogue cam (e.g. rm-mining "Tell me about mining" → next line): keep the
    -- shot - no second zoom / blend back to gameplay.
    if cam and camPed == ped then
        return
    end

    if cam then
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(cam, false)
        cam = nil
        camPed = nil
    end

    local coords = GetEntityCoords(ped, true)

    if overShoulder then
        -- Behind the player's right shoulder, looking at the NPC's face: both in the shot.
        local me = GetEntityCoords(lib.getPlayerPed(), true)
        local dir = vector3(coords.x - me.x, coords.y - me.y, 0.0)
        if #dir < 0.1 then dir = vector3(GetEntityForwardX(ped), GetEntityForwardY(ped), 0.0) * -1 end
        dir = dir / #dir
        local right = vector3(dir.y, -dir.x, 0.0)
        local pos = me - dir * 0.85 + right * 0.45 + vector3(0.0, 0.0, 0.62)
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 50.0, false, 0)
        PointCamAtCoord(cam, coords.x, coords.y, coords.z + 0.55)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 1200, true, true)
        camPed = ped
        return
    end

    local fwdX = GetEntityForwardX(ped) * 1.2
    local fwdY = GetEntityForwardY(ped) * 1.2
    local camRot = GetEntityRotation(ped, 2)

    cam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        coords.x + fwdX,
        coords.y + fwdY,
        coords.z + 0.52,
        camRot.x,
        camRot.y,
        camRot.z + 181.0,
        GetGameplayCamFov(),
        false,
        0
    )
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 2000, true, true)
    camPed = ped
end

local function destroyCam()
    if not cam then return end
    RenderScriptCams(false, true, 2000, true, false)
    DestroyCam(cam, false)
    cam = nil
    camPed = nil
end

local function cleanup()
    isOpen = false
    currentCallback = nil
    currentDialogue = nil

    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'CLOSE_DIALOGUE',
        data = true,
    })

    destroyCam()
    ResetEntityAlpha(lib.getPlayerPed())
end

--- Opens a dialogue UI with ped name, text, and answer options.
--- @param data table { name: string, text: string, ped?: number, hidePlayer?: boolean, options: { id: string, label: string }[], input?: { type?: 'number'|'text', placeholder?: string, submitLabel?: string, min?: number, max?: number } }
--- @param cb? fun(response: string|nil) Callback with the selected option id or typed input value (nil if closed without answering)
function lib.dialogue(data, cb)
    if not data or not data.name or not data.text or not data.options then return end

    -- Chaining: NUI callback can open the next step without cleanup(); same `ped` reuses the existing cam.
    isOpen = true
    currentCallback = cb
    currentDialogue = data

    -- camera if a ped entity is provided. Default: face-on shot of the NPC with the player
    -- hidden (they would block it). `hidePlayer = false`: over-the-shoulder shot, player visible.
    if data.ped and DoesEntityExist(data.ped) then
        local keepPlayer = data.hidePlayer == false
        createCam(data.ped, keepPlayer)
        if keepPlayer then
            ResetEntityAlpha(lib.getPlayerPed())
        else
            SetEntityAlpha(lib.getPlayerPed(), 0, true)
        end
    else
        destroyCam()
        ResetEntityAlpha(lib.getPlayerPed())
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'OPEN_DIALOGUE',
        data = {
            name = data.name,
            text = data.text,
            options = data.options,
            input = data.input,
        },
    })
end

--- Closes the dialogue UI programmatically.
function lib.closeDialogue()
    if not isOpen then return end
    local responseCallback = currentCallback

    cleanup()

    if responseCallback then
        responseCallback(nil)
    end
end

--- Returns whether the dialogue is currently open.
--- @return boolean
function lib.isDialogueOpen()
    return isOpen
end

--- Returns the current dialogue data or nil.
--- @return table|nil
function lib.getDialogue()
    return currentDialogue
end

RegisterNUICallback('dialogueResponse', function(data, cb)
    cb('ok')

    local selectedId = data and (data.value ~= nil and data.value or data.id)
    local responseCallback = currentCallback
    local hadOpenDialogue = isOpen

    isOpen = false
    currentCallback = nil
    currentDialogue = nil

    if responseCallback then
        -- a callback error must never leave the player stuck in the dialogue camera with focus
        local ok, err = pcall(responseCallback, selectedId)
        if not ok then
            print(('^5[%s]^7 ^1dialogue callback error: %s^7'):format(GetCurrentResourceName(), err))
            if isOpen then cleanup() end
        end
    end

    -- If callback did not open the next step, tear down NUI/camera; otherwise lib.dialogue already ran.
    if hadOpenDialogue and not isOpen then
        cleanup()
    end
end)

exports('dialogue', lib.dialogue)
exports('closeDialogue', lib.closeDialogue)
exports('isDialogueOpen', lib.isDialogueOpen)
exports('getDialogue', lib.getDialogue)
