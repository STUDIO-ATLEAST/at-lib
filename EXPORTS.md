# at-lib - Exports & Usage

All games share the same pattern. Pass `difficulty = 'easy' | 'medium' | 'hard'` (default **medium**), or override any option. Explicit options always win over the preset.

## Standard API

```lua
-- Generic
local ok = exports['at-lib']:Play('arrows', {
    difficulty = 'easy', -- or 'medium' / 'hard' / 1-5
})

-- Named (TeamsGG-style)
local ok = exports['at-lib']:Arrows({
    difficulty = 'hard',
    numberOfArrows = 14,
    timeLimit = 6,        -- seconds (or ms if >= 1000)
    numberOfStages = 2,
})

-- Cancel
exports['at-lib']:CancelGame()

-- Inspect presets
exports['at-lib']:GetPresets('arrows')
exports['at-lib']:GetMinigames()
```

## Common option aliases

| Alias | Maps to |
|-------|---------|
| `numberOfStages` | `stages` |
| `timeLimit` / `timePerStage` / `stageTime` / `gameTime` | `duration` (ms; values `< 1000` treated as seconds) |
| `penaltySeconds` | `penalty` (ms) |
| `numberOfArrows` / `numberOfKeys` | `length` / `rounds` |
| `numberOfDots` | `dots` |
| `numberOfClicks` / `numberOfHits` | `hitsRequired` |
| `gridSize` | `size` / `gridSize` |
| `incorrect` | `oddCount` |
| `subtlety` | `visibility` |
| `targetNumber` | `target` |
| `previewTime` | `preview` |
| `maxFails` | `lives` |

## Difficulty presets

Defaults live in `modules/minigames/config.lua` (`Config.Presets`). Levels:

- **easy** - forgiving timings / fewer stages  
- **medium** - default balance  
- **hard** - tight timers / more stages / less room for error  

Numeric `difficulty` 1-5 still works (`1-2` → easy, `3` → medium, `4-5` → hard).

## Named exports

| Export | Game id |
|--------|---------|
| `SafeCrack` | safecrack |
| `Alphabet` / `Keys` | alphabet |
| `Keypad` | keypad |
| `Decrypt` | decrypt |
| `Overflow` | overflow |
| `Remember` | remember |
| `Pairs` | pairs |
| `Untangle` / `AMess` | untangle |
| `Merge` / `Game20471` | merge |
| `CircleLock` / `CircleClick` | circlelock |
| `LockpickV2` | lockpickv2 |
| `Lockpick` | lockpick |
| `Wires` | wires |
| `ColorMatch` / `ChromaLock` | colormatch |
| `SignalTune` | signaltune |
| `Binary` | binary |
| `Circuit` / `PipePressure` | circuit |
| `PortScan` | portscan |
| `PinTension` | pintension |
| `SkillBar` | skillbar |
| `LaserGrid` | lasergrid |
| `Pathing` | pathing |
| `OddOneOut` | oddoneout |
| `Sequence` | sequence |
| `Arrows` | arrows |
| `Search` | search |
| `Smash` | smash |
| `Notch` | notch |
| `PedLoot` | pedloot |
| `Drill` | drill |
| `DataCrack` | datacrack |
| `Stacker` | stacker |
| `PulseBar` | pulsebar |
| `PinLock` | pinlock |

## Search (ox_inventory)

```lua
-- Returns success, foundItems - timeout/Esc still grants items already opened
local ok, items = exports['at-lib']:Search({
    difficulty = 'medium',
    items = {
        { item = 'lockpick', count = 1 },
        { item = 'money', count = 50 },
        { item = 'phone', count = 1 },
        { item = 'radio', count = 1 },
    },
    required = 2,       -- how many loot slots to find to "succeed"
    searchTime = 1400,  -- ms per box
    timeLimit = 26,     -- seconds
})

-- items are also added via ox_inventory automatically (success or fail)
-- ok == false on timeout / Esc, but items still contains what was searched
```

## Smash / Notch / Ped Loot

```lua
exports['at-lib']:Smash({ difficulty = 'medium', key = 'E' })
exports['at-lib']:Notch({ difficulty = 'hard', notches = 5 })

-- Ped loot: clear every loot slot to succeed; miss still keeps grabbed items
local ok, items = exports['at-lib']:PedLoot({
    difficulty = 'medium',
    slots = 5,
    empties = 2,
    speed = 90,
    timeLimit = 15,
})
```

## Examples

```lua
-- Skill bar like TeamsGG
exports['at-lib']:SkillBar({
    segmentSpeed = 90,
    targetZoneSize = 14,
    hitsRequired = 3,
})

-- Pathing
exports['at-lib']:Pathing({
    numberOfStages = 3,
    numberOfDots = 8,
    timeLimit = 12,
})

-- Sequence
exports['at-lib']:Sequence({
    difficulty = 'medium',
    instantFail = false,
    timeLimit = 30,
    penaltySeconds = 2,
    sequenceLength = 4,
    scrambleCount = 2,
})

-- Odd one out
exports['at-lib']:OddOneOut({
    difficulty = 'hard',
    gridSize = 5,
    oddCount = 2,
    timeLimit = 10,
})
```

## Test commands

Dev only - enable with:

```
setr at_minigames_dev true
```

Then:

```
/minigames
/testnotch
/testsmash
/testarrows easy
```

Exports (`Play`, `Notch`, …) always work; only `/test*` and `/minigames` are gated.

## Edit defaults

Change values in `modules/minigames/config.lua` → `Config.Presets` for each game’s `easy` / `medium` / `hard` tables.

## World cards (status label pinned in the world)

A small icon + label card drawn by the game at a world spot or following an entity. Shown within `distance` metres.

```lua
local id = exports['at-lib']:addWorldCard({
    coords = vec3(x, y, z),          -- or entity = vehicle, offset = vec3(0.0, -4.0, 1.2)
    label = 'Locked',
    icon = 'lock',                   -- lock, lock-open, trash-2, truck, banknote, trees, hard-hat, package, check, user
    color = 'red',                   -- red | green | blue | orange | grey
    distance = 2.0,
    showWhileMoving = false,         -- vehicle cards hide while driving or occupied unless true
})

exports['at-lib']:updateWorldCard(id, { label = 'Unlocked', icon = 'lock-open', color = 'green' })
exports['at-lib']:removeWorldCard(id)
```

## Interactions

Removed. Use ox_target instead: markers show nearby, hold ALT and aim at one, scroll to pick an option, E to use it.
