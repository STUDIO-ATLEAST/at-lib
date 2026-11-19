# AT Lib

at-lib is a UI library for FiveM. It gives your scripts one shared set of HUD pieces and minigames: dialogue with NPCs, mission panels, timers, progress bars, key prompts, gang zone capture cards, status cards pinned in the world, and 34 minigames for hacking, lockpicking, safe cracking and looting. Everything is driven by client exports, so any resource can use it with one line of Lua. The interface is built with Svelte 5 and ships prebuilt in `web/build`.

The full minigame reference is in [EXPORTS.md](EXPORTS.md).

## Features

- **Dialogue** with an NPC name, text and answer options, plus an optional scripted camera on the NPC.
- **Mission status** panel on the left with objectives and progress.
- **Mission card** in the top right: steps, tasks, optional objectives, gauges, a stat footer and a hint line.
- **Timers**: a top-centre countdown and a compact heist timer, each with a callback when time runs out.
- **Progress bar** for suspicion, noise, hack progress and the like.
- **TextUI** key prompts such as `[E] Grab bag`.
- **Gang zone** capture card with both gangs, the capture percentage and the time left.
- **World cards**: a small icon and label drawn at a spot in the world or following an entity.
- **34 minigames** with easy, medium and hard presets, TeamsGG-style option names and one generic `Play` export.
- **Search and Ped Loot** minigames that hand out items through ox_inventory, checked on the server.
- **Dev tools**: a minigame picker and a `/test<game>` command for every game, behind a convar.

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory), only for the Search and Ped Loot minigames

at-lib has no framework dependency. It works on Qbox, QBCore, ESX or a standalone server.

## Installation

1. Put the `at-lib` folder in your `resources` directory.
2. Start it after ox_lib in `server.cfg`:

   ```cfg
   ensure ox_lib
   ensure ox_inventory   # only needed for Search and Ped Loot
   ensure at-lib
   ```

3. Start every resource that uses at-lib after it.

The built UI is already in `web/build`, so there is nothing to compile for a normal install.

## Building the UI

Only needed if you change the Svelte source in `web/src`.

```bash
cd web
pnpm install
pnpm run build
```

`pnpm start` runs a browser dev server on port 3001 with mock data. `pnpm run start:game` rebuilds on every save so you can restart the resource in game.

## Minigames

```lua
-- Generic
local ok = exports['at-lib']:Play('arrows', { difficulty = 'easy' })

-- Named export with options
local ok = exports['at-lib']:Arrows({
    difficulty = 'hard',
    numberOfArrows = 14,
    timeLimit = 6,
})

-- Cancel whatever is running
exports['at-lib']:CancelGame()
```

Every game returns `true` on success and `false` on failure, timeout or Esc. Search and Ped Loot also return the items found. `difficulty` takes `'easy'`, `'medium'` (default), `'hard'` or a number from 1 to 5, and any option you pass wins over the preset. Presets live in `modules/minigames/config.lua`.

| Game | Export |
|------|--------|
| Safe Crack | `SafeCrack` |
| Alphabet | `Alphabet` / `Keys` |
| Keypad | `Keypad` |
| Decrypt | `Decrypt` |
| Overflow | `Overflow` |
| Remember | `Remember` |
| Pairs | `Pairs` |
| Untangle | `Untangle` / `AMess` |
| Merge | `Merge` / `Game20471` |
| Circle Lock | `CircleLock` / `CircleClick` |
| Lockpick V2 | `LockpickV2` |
| Lockpick | `Lockpick` |
| Wires | `Wires` |
| Color Match | `ColorMatch` / `ChromaLock` |
| Signal Tune | `SignalTune` |
| Binary Code | `Binary` |
| Circuit Flow | `Circuit` / `PipePressure` |
| Port Scan | `PortScan` |
| Pin Tension | `PinTension` |
| Skill Bar | `SkillBar` |
| Laser Grid | `LaserGrid` |
| Pathing | `Pathing` |
| Odd One Out | `OddOneOut` |
| Sequence | `Sequence` |
| Arrows | `Arrows` |
| Search | `Search` |
| Smash | `Smash` |
| Notch | `Notch` |
| Ped Loot | `PedLoot` |
| Drill | `Drill` |
| Data Crack | `DataCrack` |
| Stacker | `Stacker` |
| Pulse Bar | `PulseBar` |
| Pin Lock | `PinLock` |

`InitializeSafe(combination, startDirection)` followed by `RunMiniGame()` is also available for scripts written for other safe-cracking resources.

### Dev tools

```cfg
setr at_minigames_dev true
```

With the convar on, `/minigames` opens a picker with every game and difficulty, and `/test<game> [easy|medium|hard]` runs one game, for example `/testarrows hard`. Exports always work, only the commands are gated.

## Dialogue

Opens a dialogue box and takes NUI focus. The callback gets the chosen option id, or `nil` when the player closes it.

| Export | Parameters | Returns |
|--------|------------|---------|
| `dialogue` | `data, cb?` | |
| `closeDialogue` | | |
| `isDialogueOpen` | | `boolean` |
| `getDialogue` | | current data or `nil` |

```lua
exports['at-lib']:dialogue({
    name = 'Officer Davis',
    text = 'We need your help with a case. Are you in?',
    ped = npcPed, -- optional, points a camera at this NPC
    options = {
        { id = 'accept', label = "Yes, I'm in" },
        { id = 'decline', label = 'Not right now' },
    },
}, function(optionId)
    if optionId == 'accept' then
        -- start the job
    end
end)
```

## Mission status

Left side panel with a title and a list of objectives. Does not take NUI focus.

| Export | Parameters |
|--------|------------|
| `setMission` | `data` |
| `updateObjective` | `objectiveId, completed` |
| `updateObjectives` | `objectives` |
| `closeMission` | |
| `getMission` | |
| `isMissionActive` | |

```lua
exports['at-lib']:setMission({
    title = 'Drug Bust Operation',
    objectives = {
        { id = 'goto', label = 'Go to the marked location', completed = false },
        { id = 'talk', label = 'Talk to the informant', completed = false },
    },
})

exports['at-lib']:updateObjective('goto', true)
exports['at-lib']:closeMission()
```

## Mission card

Compact card in the top right. It takes the same data as `setMission` and can be shown on its own or next to the panel.

| Export | Parameters |
|--------|------------|
| `setMissionCard` | `data` |
| `updateMissionCardDetails` | `data` |
| `updateObjectiveCard` | `objectiveId, completed` |
| `updateObjectivesCard` | `objectives` |
| `closeMissionCard` | |
| `getMissionCard` | |
| `isMissionCardActive` | |

| Field | Type | Description |
|-------|------|-------------|
| `title` | `string` | Mission title. |
| `objectives` | `table[]` | `{ id, label, completed }`. Required unless `steps` is given. |
| `steps` | `table[]?` | `{ id?, label, done?, active?, progress?, count? }`, replaces `objectives`. |
| `optional` | `table[]?` | `{ id?, label, done? }` under an Optional heading. |
| `task` | `string?` | Current step heading. |
| `detail` | `string?` | Current step description. |
| `meta` | `string?` | Line under the title, defaults to `Step X of N`. |
| `icon` | `string?` | Lucide icon name from `web/src/lib/icons.ts`. |
| `tasks` | `table[]?` | `{ id?, label, done?, progress?, count? }` checklist under the current step. |
| `badge` | `table?` | `{ icon?, text }` shown in the header. |
| `gauges` | `table[]?` | `{ id?, label?, icon?, kind = 'bar' \| 'segments' \| 'text', value?, max?, tone?, text?, ttl? }`. |
| `stat` | `table?` | `{ id?, label, value, icon?, format? = 'money' \| 'number' }` footer value. |
| `hint` | `string?` | Highlighted line at the bottom. |

`updateMissionCardDetails` accepts any of the fields above except `title` and `objectives`. `updateObjectiveCard` also matches `steps`, `tasks` and `optional` entries by id.

```lua
exports['at-lib']:setMissionCard({
    title = 'Delivery run',
    icon = 'truck',
    objectives = {
        { id = 'meet', label = 'Meet the buyer at the GPS mark', completed = false },
        { id = 'return', label = 'Return to the depot for payment', completed = false },
    },
})

exports['at-lib']:updateObjectiveCard('meet', true)
exports['at-lib']:closeMissionCard()
```

## Timers

A top-centre countdown. The callback runs once when it reaches zero and does not run if you close the timer first.

| Export | Parameters |
|--------|------------|
| `showTimer` | `{ seconds, header?, text? }, cb?` |
| `updateTimer` | `{ seconds?, header?, text? }` |
| `closeTimer` | |

```lua
exports['at-lib']:showTimer({
    seconds = 300,
    header = 'Timed objective',
    text = 'Reach the drop-off before time runs out.',
}, function()
    exports['at-lib']:closeMission()
end)

exports['at-lib']:updateTimer({ seconds = 120, text = 'Two minutes left' })
exports['at-lib']:closeTimer()
```

The heist timer is a compact `MM:SS` display that sits above the mission card:

```lua
exports['at-lib']:showTimedObjectiveV2({ seconds = 35 * 60 }, function()
    print('Heist time expired')
end)

exports['at-lib']:updateTimedObjectiveV2({ seconds = 120 })
exports['at-lib']:closeTimedObjectiveV2()
```

## Progress bar

Bottom-centre bar from 0 to 100.

```lua
exports['at-lib']:showProgress({ progress = 25, header = 'Suspicion', label = 'Stay out of sight' })
exports['at-lib']:updateProgress({ progress = 80 })
exports['at-lib']:closeProgress()
```

## TextUI

Key prompt on the right side of the screen. Does not take NUI focus.

```lua
exports['at-lib']:showTextUI('E', 'Grab bag')
local open = exports['at-lib']:isTextUIOpen()
exports['at-lib']:hideTextUI()
```

## Gang zone

Top-centre capture card. The side that owns or is capturing the zone gets its gang colour, and `owner = nil` shows the zone as contested.

```lua
exports['at-lib']:showGangZone({
    percent = 40,
    seconds = 90,
    left = { name = 'Ballas', logo = 'https://example.com/ballas.png', color = '#7b2fbe' },
    right = { name = 'Families', color = '#2f9e44' },
    owner = 'left',
})

exports['at-lib']:updateGangZone({ percent = 55, seconds = 75 })
exports['at-lib']:closeGangZone()
```

## World cards

A small icon and label drawn by the game at a world position or on an entity, visible within `distance` metres.

```lua
local id = exports['at-lib']:addWorldCard({
    coords = vec3(x, y, z),    -- or entity = vehicle, offset = vec3(0.0, -4.0, 1.2)
    label = 'Locked',
    icon = 'lock',             -- lock, lock-open, trash-2, truck, banknote, trees, hard-hat, package, check, user
    color = 'red',             -- red, green, blue, orange or grey
    distance = 2.0,
    showWhileMoving = false,   -- vehicle cards hide while driving unless true
})

exports['at-lib']:updateWorldCard(id, { label = 'Unlocked', icon = 'lock-open', color = 'green' })
exports['at-lib']:removeWorldCard(id)
```

## Helpers

```lua
local ped = exports['at-lib']:getPlayerPed() -- cache.ped from ox_lib
```

## Moving from rm-lib

at-lib is the renamed rm-lib. The exports and their arguments are the same, so replace `exports['rm-lib']` with `exports['at-lib']` and `dependency 'rm-lib'` with `dependency 'at-lib'` in your resources. The internal events are now `at-lib:*`, and the dev convar is `at_minigames_dev`.
