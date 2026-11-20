# Changelog

## 1.2.0

- Search and Ped Loot only give items that a server script allowed with the new server export `AllowLoot(source, items)`. Before, the client sent the loot list itself, so a cheater could give themselves any item. Set `at_lib_client_loot` to `true` to get the old behaviour on a test server.
- Item metadata for loot now comes from the server list, not the client.
- New README and EXPORTS.md with screenshots of every minigame and HUD piece, the options of each game and a tutorial.

## 1.1.0

- Renamed from rm-lib to at-lib.
- Dialogue, mission status, mission card, timers, progress bar, TextUI, gang zone, world cards and 34 minigames.
