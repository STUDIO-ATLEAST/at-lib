--- Bottom-center generic progress bar (0-100). Optional header/label for any script.

--- @param data table { progress: number, header?: string, label?: string }
function lib.showProgress(data)
    if not data or type(data.progress) ~= 'number' then return end

    local p = math.max(0, math.min(100, data.progress + 0.0))
    SendNUIMessage({
        action = 'SHOW_PROGRESS',
        data = {
            progress = p,
            header = data.header,
            label = data.label,
        },
    })
end

--- @param data table { progress?: number, header?: string, label?: string }
function lib.updateProgress(data)
    if not data then return end

    local p = data.progress
    if p ~= nil then
        p = math.max(0, math.min(100, p + 0.0))
    end

    SendNUIMessage({
        action = 'UPDATE_PROGRESS',
        data = {
            progress = p,
            header = data.header,
            label = data.label,
        },
    })
end

function lib.closeProgress()
    SendNUIMessage({
        action = 'CLOSE_PROGRESS',
        data = true,
    })
end

exports('showProgress', lib.showProgress)
exports('updateProgress', lib.updateProgress)
exports('closeProgress', lib.closeProgress)
