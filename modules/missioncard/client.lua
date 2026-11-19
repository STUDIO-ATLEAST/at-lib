local isShowing = false
local currentMission = nil
local DETAIL_KEYS = { 'task', 'detail', 'meta', 'icon', 'badge', 'steps', 'tasks', 'optional', 'gauges', 'stat', 'hint' }

--- @param data table { title: string, objectives?: table[], steps?: table[], tasks?: table[], optional?: table[], gauges?: table[], badge?: table, stat?: table, task?: string, detail?: string, meta?: string, icon?: string, hint?: string }
function lib.setMissionCard(data)
    if not data or not data.title then return end
    local hasObjectives = type(data.objectives) == 'table' and #data.objectives > 0
    local hasSteps = type(data.steps) == 'table' and #data.steps > 0
    if not hasObjectives and not hasSteps then return end
    if type(data.objectives) ~= 'table' then data.objectives = {} end
    currentMission = data
    isShowing = true

    SendNUIMessage({
        action = 'SET_MISSION_CARD',
        data = data,
    })
end

local function markCompleted(objectiveId, completed)
    for _, obj in ipairs(currentMission.objectives or {}) do
        if obj.id == objectiveId then obj.completed = completed end
    end
    for _, key in ipairs({ 'steps', 'tasks', 'optional' }) do
        for _, entry in ipairs(currentMission[key] or {}) do
            if entry.id == objectiveId then entry.done = completed end
        end
    end

    SendNUIMessage({
        action = 'UPDATE_OBJECTIVE_CARD',
        data = {
            id = objectiveId,
            completed = completed,
        },
    })
end

--- @param objectiveId string
--- @param completed boolean
function lib.updateObjectiveCard(objectiveId, completed)
    if not currentMission then return end
    markCompleted(objectiveId, completed)
end

--- @param objectives table[]
function lib.updateObjectivesCard(objectives)
    if not currentMission then return end
    for _, update in ipairs(objectives) do
        markCompleted(update.id, update.completed)
    end
end

function lib.updateMissionCardDetails(data)
    if not currentMission or type(data) ~= 'table' then return end

    for _, key in ipairs(DETAIL_KEYS) do
        if data[key] ~= nil then currentMission[key] = data[key] end
    end

    SendNUIMessage({
        action = 'UPDATE_MISSION_CARD',
        data = data,
    })
end

function lib.closeMissionCard()
    if not isShowing then return end
    isShowing = false
    currentMission = nil

    SendNUIMessage({
        action = 'CLOSE_MISSION_CARD',
        data = true,
    })
end

--- @return table|nil
function lib.getMissionCard()
    return currentMission
end

--- @return boolean
function lib.isMissionCardActive()
    return isShowing
end

exports('setMissionCard', lib.setMissionCard)
exports('updateObjectiveCard', lib.updateObjectiveCard)
exports('updateObjectivesCard', lib.updateObjectivesCard)
exports('updateMissionCardDetails', lib.updateMissionCardDetails)
exports('closeMissionCard', lib.closeMissionCard)
exports('getMissionCard', lib.getMissionCard)
exports('isMissionCardActive', lib.isMissionCardActive)
