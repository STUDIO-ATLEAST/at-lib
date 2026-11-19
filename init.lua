if not lib then
    lib = {}
end

---@return number
function lib.getPlayerPed()
    if cache and cache.ped then
        return cache.ped
    end
    return PlayerPedId()
end

exports('getPlayerPed', lib.getPlayerPed)
