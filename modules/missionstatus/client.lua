local isShowing = false
local currentMission = nil

--- Shows a mission status panel on the left side of the screen.
--- @param data table { title: string, objectives: { id: string, label: string, completed: boolean }[] }
function lib.setMission(data)
    if not data or not data.title or type(data.objectives) ~= "table" or #data.objectives < 1 then return end
    currentMission = data
    isShowing = true

    SendNUIMessage({
        action = 'SET_MISSION',
        data = data,
    })
end

--- Updates a specific objective's completed state.
--- @param objectiveId string The objective id to update
--- @param completed boolean Whether the objective is completed
function lib.updateObjective(objectiveId, completed)
    if not currentMission then return end

    for _, obj in ipairs(currentMission.objectives) do
        if obj.id == objectiveId then
            obj.completed = completed
            break
        end
    end

    SendNUIMessage({
        action = 'UPDATE_OBJECTIVE',
        data = {
            id = objectiveId,
            completed = completed,
        },
    })
end

--- Updates multiple objectives at once.
--- @param objectives table[] Array of { id: string, completed: boolean }
function lib.updateObjectives(objectives)
    if not currentMission then return end

    for _, update in ipairs(objectives) do
        for _, obj in ipairs(currentMission.objectives) do
            if obj.id == update.id then
                obj.completed = update.completed
                break
            end
        end

        SendNUIMessage({
            action = 'UPDATE_OBJECTIVE',
            data = {
                id = update.id,
                completed = update.completed,
            },
        })
    end
end

--- Closes the mission status panel.
function lib.closeMission()
    if not isShowing then return end
    isShowing = false
    currentMission = nil

    SendNUIMessage({
        action = 'CLOSE_MISSION',
        data = true,
    })
end

--- Returns the current mission data or nil.
--- @return table|nil
function lib.getMission()
    return currentMission
end

--- Returns whether the mission panel is currently showing.
--- @return boolean
function lib.isMissionActive()
    return isShowing
end

exports('setMission', lib.setMission)
exports('updateObjective', lib.updateObjective)
exports('updateObjectives', lib.updateObjectives)
exports('closeMission', lib.closeMission)
exports('getMission', lib.getMission)
exports('isMissionActive', lib.isMissionActive)
