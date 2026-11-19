local utils = require 'modules.minigames.utils'
local Config = require 'modules.minigames.config'
local Safecrack = require 'modules.minigames.safecrack'
local Search = require 'modules.minigames.search'
local PedLoot = require 'modules.minigames.pedloot'

local GAMES = {
    { id = 'safecrack', title = 'Safe Crack', module = Safecrack },
    { id = 'alphabet', title = 'Alphabet' },
    { id = 'keypad', title = 'Keypad' },
    { id = 'decrypt', title = 'Decrypt' },
    { id = 'overflow', title = 'Overflow' },
    { id = 'remember', title = 'Remember' },
    { id = 'pairs', title = 'Pairs' },
    { id = 'untangle', title = 'Untangle' },
    { id = 'merge', title = 'Merge' },
    { id = 'circlelock', title = 'Circle Lock' },
    { id = 'lockpickv2', title = 'Lockpick V2' },
    { id = 'lockpick', title = 'Lockpick' },
    { id = 'wires', title = 'Wires' },
    { id = 'colormatch', title = 'Color Match' },
    { id = 'signaltune', title = 'Signal Tune' },
    { id = 'binary', title = 'Binary Code' },
    { id = 'circuit', title = 'Circuit Flow' },
    { id = 'portscan', title = 'Port Scan' },
    { id = 'pintension', title = 'Pin Tension' },
    { id = 'skillbar', title = 'Skill Bar' },
    { id = 'lasergrid', title = 'Laser Grid' },
    { id = 'pathing', title = 'Pathing' },
    { id = 'oddoneout', title = 'Odd One Out' },
    { id = 'sequence', title = 'Sequence' },
    { id = 'arrows', title = 'Arrows' },
    { id = 'search', title = 'Search', module = Search },
    { id = 'smash', title = 'Smash' },
    { id = 'notch', title = 'Notch' },
    { id = 'pedloot', title = 'Ped Loot', module = PedLoot },
    { id = 'drill', title = 'Drill' },
    { id = 'datacrack', title = 'Data Crack' },
    { id = 'stacker', title = 'Stacker' },
    { id = 'pulsebar', title = 'Pulse Bar' },
    { id = 'pinlock', title = 'Pin Lock' },
}

local MINIGAME_IDS = {}
local MODULES = {}

for i = 1, #GAMES do
    local game = GAMES[i]
    MINIGAME_IDS[i] = game.id
    MODULES[game.id] = game.module or require('modules.minigames.' .. game.id)
end

local LOOT_GAMES = { search = true, pedloot = true }

local active = false
local activeId = nil ---@type string|nil
local activeGrantItems = true
local devToolsOpen = false
---@type promise | nil
local resultPromise = nil

CreateThread(function()
    RequestAmbientAudioBank('SAFE_CRACK', false)
end)

---@param id string
---@param opts table?
---@return boolean success
---@return table? items
local function playMinigame(id, opts)
    if active then
        return false
    end

    id = type(id) == 'string' and id:lower() or id
    if id == 'signal' then
        id = 'lockpick'
    end

    local module = MODULES[id]
    if not module then
        warn(('[at-lib] Unknown minigame "%s"'):format(tostring(id)))
        return false
    end

    opts = Config.Prepare(id, opts or {})

    local config = module.BuildConfig(opts)
    if not config then
        warn(('[at-lib] Unknown minigame "%s"'):format(tostring(id)))
        return false
    end

    if devToolsOpen then
        devToolsOpen = false
        utils.SendReactMessage('CLOSE_DEVTOOLS', {})
    end

    active = true
    activeId = id
    activeGrantItems = not LOOT_GAMES[id] or opts.grantItems ~= false
    if config.grantItems == false then
        activeGrantItems = false
    end
    resultPromise = promise.new()

    if activeGrantItems then
        if id == 'search' then
            TriggerServerEvent('at-lib:registerSearch', Search.ListLoot(config.slots))
        elseif id == 'pedloot' then
            TriggerServerEvent('at-lib:registerSearch', PedLoot.ListLoot(config.board))
        end
    end

    SetNuiFocus(true, true)
    utils.SendReactMessage('START_MINIGAME', {
        id = id,
        config = config,
    })

    local result = Citizen.Await(resultPromise)
    local finishedId = activeId
    active = false
    activeId = nil
    activeGrantItems = true
    resultPromise = nil

    if LOOT_GAMES[finishedId] then
        if type(result) == 'table' then
            return result.success == true, result.items or {}
        end
        return false, {}
    end

    return result == true
end

---@param id string
---@return fun(opts: table?): boolean
local function namedExport(id)
    return function(opts)
        return playMinigame(id, opts)
    end
end

---@return boolean
local function cancelGame()
    if not active or not resultPromise then
        return false
    end

    local loot = LOOT_GAMES[activeId]
    if loot then
        TriggerServerEvent('at-lib:cancelSearch')
    end

    SetNuiFocus(false, false)
    utils.SendReactMessage('STOP_MINIGAME', {})
    resultPromise:resolve(loot and { success = false, items = {} } or false)
    return true
end

---@param args table?
---@param fallback string
---@return string
local function difficultyFromArgs(args, fallback)
    local a = args and args[1]
    if type(a) ~= 'string' or a == '' then
        return fallback
    end
    return Config.NormalizeDifficulty(a)
end

local function openDevTools()
    if active then return end
    devToolsOpen = true
    SetNuiFocus(true, true)
    utils.SendReactMessage('OPEN_DEVTOOLS', {})
end

local function closeDevTools()
    if not devToolsOpen then return end
    devToolsOpen = false
    if not active then
        SetNuiFocus(false, false)
    end
    utils.SendReactMessage('CLOSE_DEVTOOLS', {})
end

exports('Play', playMinigame)
exports('CancelGame', cancelGame)

exports('GetMinigames', function()
    return MINIGAME_IDS
end)

exports('GetPresets', function(gameId)
    if type(gameId) == 'string' then
        return {
            easy = Config.GetPreset(gameId:lower(), 'easy'),
            medium = Config.GetPreset(gameId:lower(), 'medium'),
            hard = Config.GetPreset(gameId:lower(), 'hard'),
        }
    end
    return Config.Presets
end)

local NAMED_EXPORTS = {
    SafeCrack = 'safecrack',
    Alphabet = 'alphabet',
    Keys = 'alphabet',
    Keypad = 'keypad',
    Decrypt = 'decrypt',
    Overflow = 'overflow',
    Remember = 'remember',
    Pairs = 'pairs',
    Untangle = 'untangle',
    AMess = 'untangle',
    Merge = 'merge',
    Game20471 = 'merge',
    CircleLock = 'circlelock',
    CircleClick = 'circlelock',
    LockpickV2 = 'lockpickv2',
    Lockpick = 'lockpick',
    Wires = 'wires',
    ColorMatch = 'colormatch',
    ChromaLock = 'colormatch',
    SignalTune = 'signaltune',
    Binary = 'binary',
    Circuit = 'circuit',
    PipePressure = 'circuit',
    PortScan = 'portscan',
    PinTension = 'pintension',
    SkillBar = 'skillbar',
    LaserGrid = 'lasergrid',
    Pathing = 'pathing',
    OddOneOut = 'oddoneout',
    Sequence = 'sequence',
    Arrows = 'arrows',
    Search = 'search',
    Smash = 'smash',
    Notch = 'notch',
    PedLoot = 'pedloot',
    Drill = 'drill',
    DataCrack = 'datacrack',
    Stacker = 'stacker',
    PulseBar = 'pulsebar',
    PinLock = 'pinlock',
}

for name, id in pairs(NAMED_EXPORTS) do
    exports(name, namedExport(id))
end

---@param combination number[]
---@param startDirection string|nil
---@return boolean
exports('InitializeSafe', function(combination, startDirection)
    Safecrack._pending = Safecrack.BuildConfig({
        combination = combination,
        startDirection = startDirection,
        rounds = type(combination) == 'table' and #combination or 3,
    })
    return Safecrack._pending ~= nil
end)

---@return boolean success
exports('RunMiniGame', function()
    local pending = Safecrack._pending
    Safecrack._pending = nil
    if not pending then
        return playMinigame('safecrack', {})
    end

    return playMinigame('safecrack', {
        combination = pending.combination,
        startDirection = pending.startDirection,
        dialStart = pending.dialStart,
        rounds = #pending.combination,
    })
end)

---@param data table?
---@return table[]
local function normalizeLoot(data)
    local items = {}
    if type(data) ~= 'table' or type(data.items) ~= 'table' then
        return items
    end

    for i = 1, #data.items do
        local entry = data.items[i]
        if type(entry) == 'table' then
            items[#items + 1] = {
                name = entry.id or entry.name or entry.item,
                count = entry.count or 1,
                metadata = entry.metadata,
                slot = entry.slot,
                sourceIndex = entry.sourceIndex,
            }
        end
    end

    return items
end

RegisterNuiCallback('minigameInput', function(data, cb)
    cb(1)
    if active then TriggerEvent('at-lib:minigameInput', activeId, data and data.hit == true) end
end)

RegisterNuiCallback('minigameResult', function(data, cb)
    SetNuiFocus(false, false)
    utils.SendReactMessage('STOP_MINIGAME', {})

    if resultPromise then
        if LOOT_GAMES[activeId] then
            local items = normalizeLoot(data)
            if activeGrantItems then
                TriggerServerEvent('at-lib:completeSearch', items)
            end
            resultPromise:resolve({
                success = data and data.success == true,
                items = items,
            })
        else
            resultPromise:resolve(data and data.success == true)
        end
    end

    cb(true)
end)

RegisterNuiCallback('safeCrackSound', function(data, cb)
    if data and data.sound then
        Safecrack.PlaySound(data.sound)
    end
    cb(true)
end)

RegisterNuiCallback('devLaunch', function(data, cb)
    cb(true)

    if not Config.IsDev() then
        return
    end

    if active or type(data) ~= 'table' or type(data.id) ~= 'string' then
        return
    end

    CreateThread(function()
        local ok = playMinigame(data.id, data.opts or { difficulty = 3 })
        lib.notify({
            title = 'Minigame',
            description = ('%s - %s'):format(data.id, ok and 'success' or 'failed'),
            type = ok and 'success' or 'error',
        })
    end)
end)

RegisterNuiCallback('closeDevTools', function(_, cb)
    closeDevTools()
    cb(true)
end)

RegisterNuiCallback('hideApp', function(_, cb)
    if active and resultPromise then
        local loot = LOOT_GAMES[activeId]
        if loot then
            TriggerServerEvent('at-lib:cancelSearch')
        end
        SetNuiFocus(false, false)
        utils.SendReactMessage('STOP_MINIGAME', {})
        resultPromise:resolve(loot and { success = false, items = {} } or false)
    else
        closeDevTools()
    end
    cb(true)
end)

RegisterCommand('minigames', function()
    if not Config.IsDev() then
        lib.notify({
            title = 'Minigames',
            description = 'Dev mode is off (setr at_minigames_dev true)',
            type = 'error',
        })
        return
    end
    openDevTools()
end, false)

for i = 1, #GAMES do
    local id, title = GAMES[i].id, GAMES[i].title

    RegisterCommand('test' .. id, function(_, args)
        if not Config.IsDev() then
            lib.notify({
                title = title,
                description = 'Dev mode is off (setr at_minigames_dev true)',
                type = 'error',
            })
            return
        end

        local diff = difficultyFromArgs(args, 'medium')
        local ok = playMinigame(id, { difficulty = diff })
        lib.notify({
            title = title,
            description = ('%s - %s'):format(diff, ok and 'Success' or 'Failed'),
            type = ok and 'success' or 'error',
        })
    end, false)
end
