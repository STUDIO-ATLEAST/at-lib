<script lang="ts">
  import { onMount } from "svelte";
  import { onNui } from "./lib/nui";
  import {
    closeDevTools,
    game,
    openDevTools,
    startGame,
    stopGame,
  } from "./stores/minigame.svelte";
  import {
    browserConfigs,
    randomColorMatchTarget,
  } from "./stores/minigameStore";
  import { isEnvBrowser } from "./utils/misc";
  import type { MinigameId, StartMinigamePayload } from "./types/minigame";
  import DevMenu from "./components/DevMenu.svelte";
  import Hud from "./components/hud/Hud.svelte";
  import SafeCrack from "./components/UI/minigames/SafeCrack/SafeCrack.svelte";
  import Alphabet from "./components/UI/minigames/Alphabet/Alphabet.svelte";
  import Keypad from "./components/UI/minigames/Keypad/Keypad.svelte";
  import Decrypt from "./components/UI/minigames/Decrypt/Decrypt.svelte";
  import Overflow from "./components/UI/minigames/Overflow/Overflow.svelte";
  import Remember from "./components/UI/minigames/Remember/Remember.svelte";
  import Pairs from "./components/UI/minigames/Pairs/Pairs.svelte";
  import Untangle from "./components/UI/minigames/Untangle/Untangle.svelte";
  import Merge from "./components/UI/minigames/Merge/Merge.svelte";
  import CircleLock from "./components/UI/minigames/CircleLock/CircleLock.svelte";
  import LockpickV2 from "./components/UI/minigames/LockpickV2/LockpickV2.svelte";
  import Lockpick from "./components/UI/minigames/Lockpick/Lockpick.svelte";
  import Wires from "./components/UI/minigames/Wires/Wires.svelte";
  import ColorMatch from "./components/UI/minigames/ColorMatch/ColorMatch.svelte";
  import SignalTune from "./components/UI/minigames/SignalTune/SignalTune.svelte";
  import Binary from "./components/UI/minigames/Binary/Binary.svelte";
  import Circuit from "./components/UI/minigames/Circuit/Circuit.svelte";
  import PortScan from "./components/UI/minigames/PortScan/PortScan.svelte";
  import PinTension from "./components/UI/minigames/PinTension/PinTension.svelte";
  import SkillBar from "./components/UI/minigames/SkillBar/SkillBar.svelte";
  import LaserGrid from "./components/UI/minigames/LaserGrid/LaserGrid.svelte";
  import Pathing from "./components/UI/minigames/Pathing/Pathing.svelte";
  import OddOneOut from "./components/UI/minigames/OddOneOut/OddOneOut.svelte";
  import Sequence from "./components/UI/minigames/Sequence/Sequence.svelte";
  import Arrows from "./components/UI/minigames/Arrows/Arrows.svelte";
  import Search from "./components/UI/minigames/Search/Search.svelte";
  import Smash from "./components/UI/minigames/Smash/Smash.svelte";
  import Notch from "./components/UI/minigames/Notch/Notch.svelte";
  import PedLoot from "./components/UI/minigames/PedLoot/PedLoot.svelte";
  import Drill from "./components/UI/minigames/Drill/Drill.svelte";
  import DataCrack from "./components/UI/minigames/DataCrack/DataCrack.svelte";
  import Stacker from "./components/UI/minigames/Stacker/Stacker.svelte";
  import PulseBar from "./components/UI/minigames/PulseBar/PulseBar.svelte";
  import PinLock from "./components/UI/minigames/PinLock/PinLock.svelte";

  onMount(() => {
    const offs = [
      onNui<StartMinigamePayload>("START_MINIGAME", (data) => {
        if (!data?.id || !data?.config) return;
        startGame(data.id, data.config);
      }),
      onNui("STOP_MINIGAME", () => stopGame()),
      onNui("OPEN_DEVTOOLS", () => openDevTools()),
      onNui("CLOSE_DEVTOOLS", () => closeDevTools()),
    ];
    return () => offs.forEach((off) => off());
  });

  function onBrowserLaunch(gameId: MinigameId) {
    const seed = () => Math.floor(Math.random() * 2147483646) + 1;
    if (gameId === "colormatch") {
      startGame(gameId, { ...browserConfigs.colormatch, target: randomColorMatchTarget() });
      return;
    }
    if (gameId === "circuit") {
      startGame(gameId, { ...browserConfigs.circuit, seed: seed() });
      return;
    }
    if (gameId === "lasergrid") {
      startGame(gameId, { ...browserConfigs.lasergrid, seed: seed() });
      return;
    }
    if (gameId === "pathing") {
      startGame(gameId, { ...browserConfigs.pathing, seed: seed() });
      return;
    }
    if (gameId === "oddoneout") {
      startGame(gameId, { ...browserConfigs.oddoneout, seed: seed() });
      return;
    }
    if (gameId === "sequence") {
      startGame(gameId, { ...browserConfigs.sequence, seed: seed() });
      return;
    }
    if (gameId === "arrows") {
      startGame(gameId, { ...browserConfigs.arrows, seed: seed(), sequence: [] });
      return;
    }
    if (gameId === "drill") {
      startGame(gameId, { ...browserConfigs.drill, seed: seed() });
      return;
    }
    if (gameId === "datacrack" || gameId === "pulsebar" || gameId === "pinlock") {
      startGame(gameId, { ...browserConfigs[gameId], seed: seed() });
      return;
    }
    startGame(gameId, browserConfigs[gameId]);
  }
</script>

{#if isEnvBrowser()}
  <div
    class="preview-bg"
    style="background-image: url(https://i.imgur.com/kiK65kg.jpeg)"
  ></div>
{/if}

<Hud />

<DevMenu
  mounted={game.showDevTools && !game.active}
  onClose={closeDevTools}
  {onBrowserLaunch}
/>

{#if game.active && game.config}
  {#if game.id === "safecrack"}<SafeCrack config={game.config} />
  {:else if game.id === "alphabet"}<Alphabet config={game.config} />
  {:else if game.id === "keypad"}<Keypad config={game.config} />
  {:else if game.id === "decrypt"}<Decrypt config={game.config} />
  {:else if game.id === "overflow"}<Overflow config={game.config} />
  {:else if game.id === "remember"}<Remember config={game.config} />
  {:else if game.id === "pairs"}<Pairs config={game.config} />
  {:else if game.id === "untangle"}<Untangle config={game.config} />
  {:else if game.id === "merge"}<Merge config={game.config} />
  {:else if game.id === "circlelock"}<CircleLock config={game.config} />
  {:else if game.id === "lockpickv2"}<LockpickV2 config={game.config} />
  {:else if game.id === "lockpick"}<Lockpick config={game.config} />
  {:else if game.id === "wires"}<Wires config={game.config} />
  {:else if game.id === "colormatch"}<ColorMatch config={game.config} />
  {:else if game.id === "signaltune"}<SignalTune config={game.config} />
  {:else if game.id === "binary"}<Binary config={game.config} />
  {:else if game.id === "circuit"}<Circuit config={game.config} />
  {:else if game.id === "portscan"}<PortScan config={game.config} />
  {:else if game.id === "pintension"}<PinTension config={game.config} />
  {:else if game.id === "skillbar"}<SkillBar config={game.config} />
  {:else if game.id === "lasergrid"}<LaserGrid config={game.config} />
  {:else if game.id === "pathing"}<Pathing config={game.config} />
  {:else if game.id === "oddoneout"}<OddOneOut config={game.config} />
  {:else if game.id === "sequence"}<Sequence config={game.config} />
  {:else if game.id === "arrows"}<Arrows config={game.config} />
  {:else if game.id === "search"}<Search config={game.config} />
  {:else if game.id === "smash"}<Smash config={game.config} />
  {:else if game.id === "notch"}<Notch config={game.config} />
  {:else if game.id === "pedloot"}<PedLoot config={game.config} />
  {:else if game.id === "drill"}<Drill config={game.config} />
  {:else if game.id === "datacrack"}<DataCrack config={game.config} />
  {:else if game.id === "stacker"}<Stacker config={game.config} />
  {:else if game.id === "pulsebar"}<PulseBar config={game.config} />
  {:else if game.id === "pinlock"}<PinLock config={game.config} />
  {/if}
{/if}

<style>
  .preview-bg {
    position: fixed;
    inset: 0;
    background-size: cover;
    background-position: center;
  }
</style>
