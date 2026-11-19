--- Top-center gang zone capture card - logo + name on each side, capture % and time in the
--- middle. Whichever side currently owns/is capturing gets its gang color as background;
--- the other side stays on the default neutral background.
--- @param data table {
---   percent: number, seconds: number,
---   left: { name: string, logo?: string, color?: string },
---   right: { name: string, logo?: string, color?: string },
---   owner?: 'left'|'right' (nil = contested/neutral, both sides default bg)
--- }
function lib.showGangZone(data)
    if not data then return end

    SendNUIMessage({
        action = 'SHOW_GANGZONE',
        data = data,
    })
end

--- Partial update - only the given fields change (e.g. push a fresh percent/owner each tick
--- without re-sending the logos/names).
--- @param data table (subset of lib.showGangZone's data)
function lib.updateGangZone(data)
    if not data then return end

    SendNUIMessage({
        action = 'UPDATE_GANGZONE',
        data = data,
    })
end

function lib.closeGangZone()
    SendNUIMessage({
        action = 'CLOSE_GANGZONE',
        data = true,
    })
end

exports('showGangZone', lib.showGangZone)
exports('updateGangZone', lib.updateGangZone)
exports('closeGangZone', lib.closeGangZone)
