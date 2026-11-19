local timerCallback = nil

--- Shows a countdown timer on the screen.
--- @param data table { seconds: number, header?: string, text?: string, position?: 'top-center'|'bottom-center', variant?: 'default'|'heist' }
--- @param cb? fun() Called once when the countdown reaches zero (not called if lib.closeTimer is used first)
function lib.showTimer(data, cb)
    if not data or type(data.seconds) ~= 'number' or data.seconds < 0 then return end

    timerCallback = cb
    SendNUIMessage({
        action = 'SHOW_TIMER',
        data = {
            seconds = math.floor(data.seconds + 0.5),
            header = data.header,
            text = data.text,
            position = data.position,
            variant = data.variant,
        },
    })
end

--- Updates header, text, and/or remaining seconds without hiding the timer.
--- @param data table { seconds?: number, header?: string, text?: string, position?: 'top-center'|'bottom-center' }
function lib.updateTimer(data)
    if not data then return end

    SendNUIMessage({
        action = 'UPDATE_TIMER',
        data = {
            seconds = data.seconds ~= nil and math.floor(data.seconds + 0.5) or nil,
            header = data.header,
            text = data.text,
            position = data.position,
            variant = data.variant,
        },
    })
end

--- Shows the compact heist countdown: TIME above an MM:SS readout.
--- @param data table { seconds: number, header?: string, position?: 'top-center'|'bottom-center' }
--- @param cb? fun()
function lib.showTimedObjectiveV2(data, cb)
    if not data then return end
    data.variant = 'heist'
    data.header = data.header or 'TIME'
    lib.showTimer(data, cb)
end

function lib.updateTimedObjectiveV2(data)
    if not data then return end
    data.variant = 'heist'
    lib.updateTimer(data)
end

function lib.closeTimedObjectiveV2()
    lib.closeTimer()
end

--- Hides the timer. Does not fire the completion callback.
function lib.closeTimer()
    SendNUIMessage({
        action = 'CLOSE_TIMER',
        data = true,
    })
    timerCallback = nil
end

RegisterNUICallback('timerComplete', function(_, cb)
    cb('ok')

    local fn = timerCallback
    timerCallback = nil
    if fn then
        fn()
    end
end)

exports('showTimer', lib.showTimer)
exports('updateTimer', lib.updateTimer)
exports('closeTimer', lib.closeTimer)
exports('showTimedObjectiveV2', lib.showTimedObjectiveV2)
exports('updateTimedObjectiveV2', lib.updateTimedObjectiveV2)
exports('closeTimedObjectiveV2', lib.closeTimedObjectiveV2)
