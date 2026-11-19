<script lang="ts">
  import X from "@lucide/svelte/icons/x";
  import { fetchNui } from "../utils/fetchNui";
  import { isEnvBrowser } from "../utils/misc";
  import { devPreview } from "../stores/hud.svelte";
  import type { MinigameId } from "../types/minigame";
  import type { DevPreviewKey } from "../types/hud";
  import { iconSize } from "../utils/vp";
  import "./UI/DevTools/DevTools.css";

  let {
    mounted,
    onClose,
    onBrowserLaunch,
  }: {
    mounted: boolean;
    onClose: () => void;
    onBrowserLaunch: (id: MinigameId) => void;
  } = $props();

  type GameEntry = { id: MinigameId; name: string };

  const HACKS: GameEntry[] = [
    { id: "safecrack", name: "Safe Crack" },
    { id: "keypad", name: "Keypad" },
    { id: "decrypt", name: "Decrypt" },
    { id: "overflow", name: "Overflow" },
    { id: "remember", name: "Remember" },
    { id: "pairs", name: "Pairs" },
    { id: "untangle", name: "Untangle" },
    { id: "merge", name: "Merge" },
    { id: "wires", name: "Wires" },
    { id: "colormatch", name: "Color Match" },
    { id: "signaltune", name: "Signal Tune" },
    { id: "circuit", name: "Circuit Flow" },
    { id: "portscan", name: "Port Scan" },
    { id: "pintension", name: "Pin Tension" },
    { id: "lasergrid", name: "Laser Grid" },
    { id: "pathing", name: "Pathing" },
    { id: "oddoneout", name: "Odd One Out" },
    { id: "sequence", name: "Sequence" },
    { id: "search", name: "Search" },
    { id: "datacrack", name: "Data Crack" },
    { id: "pinlock", name: "Pin Lock" },
    { id: "stacker", name: "Stacker" },
    { id: "notch", name: "Notch" },
    { id: "pedloot", name: "Ped Loot" },
    { id: "drill", name: "Drill" },
    { id: "lockpick", name: "Lockpick" },
    { id: "circlelock", name: "Circle Lock" },
    { id: "lockpickv2", name: "Lockpick V2" },
  ];

  const SKILL_CHECKS: GameEntry[] = [
    { id: "skillbar", name: "Skill Bar" },
    { id: "pulsebar", name: "Pulse Bar" },
    { id: "smash", name: "Smash" },
    { id: "arrows", name: "Arrows" },
    { id: "alphabet", name: "Alphabet" },
    { id: "binary", name: "Binary Code" },
  ];

  const SECTIONS = [
    { title: "Hacks", games: HACKS },
    { title: "Skill Checks", games: SKILL_CHECKS },
  ];

  const HUD_ROWS: { key: DevPreviewKey; label: string }[] = [
    { key: "dialogue", label: "Dialogue" },
    { key: "mission", label: "Mission status (left)" },
    { key: "missionCard", label: "Mission card (right)" },
    { key: "timer", label: "Timer" },
    { key: "timerV2", label: "Timer v2 (heist)" },
    { key: "textui", label: "Text UI (keybind)" },
    { key: "textuiPlain", label: "Text UI (plain)" },
    { key: "progress", label: "Progress bar" },
    { key: "gangZone", label: "Gang zone" },
  ];

  const inBrowser = isEnvBrowser();

  let tab = $state<"minigames" | "hud">("minigames");

  const activeHud = $derived(HUD_ROWS.filter((row) => devPreview.toggles[row.key]).length);

  function setAll(value: boolean) {
    for (const row of HUD_ROWS) devPreview.toggles[row.key] = value;
  }

  function solo(key: DevPreviewKey) {
    const only = activeHud === 1 && devPreview.toggles[key];
    setAll(false);
    if (!only) devPreview.toggles[key] = true;
  }

  async function launch(id: MinigameId) {
    if (inBrowser) {
      onBrowserLaunch(id);
      return;
    }
    await fetchNui("devLaunch", { id, opts: { difficulty: 3 } }, { data: true });
  }

  async function close() {
    if (!inBrowser) {
      await fetchNui("closeDevTools", {}, { data: true });
    }
    onClose();
  }
</script>

{#if mounted}
  <div class="devtools">
    <div class="devtools__card">
      <div class="devtools__header">
        <span class="devtools__title">Dev</span>
        <button type="button" class="devtools__close" onclick={() => void close()}>
          <X style={iconSize(1.2)} strokeWidth={2} />
        </button>
      </div>

      {#if inBrowser}
        <div class="devmenu__tabs">
          <button
            type="button"
            class="devmenu__tab"
            class:devmenu__tab--active={tab === "minigames"}
            onclick={() => (tab = "minigames")}
          >
            Minigames
          </button>
          <button
            type="button"
            class="devmenu__tab"
            class:devmenu__tab--active={tab === "hud"}
            onclick={() => (tab = "hud")}
          >
            HUD {activeHud > 0 ? `(${activeHud})` : ""}
          </button>
        </div>
      {/if}

      <div class="devtools__scroll">
        {#if tab === "minigames" || !inBrowser}
          {#each SECTIONS as section (section.title)}
            <div class="devtools__section">
              <div class="devtools__section-title">{section.title}</div>
              {#each section.games as game (game.id)}
                <button type="button" class="devtools__item" onclick={() => void launch(game.id)}>
                  {game.name}
                </button>
              {/each}
            </div>
          {/each}
        {:else}
          <div class="devtools__section">
            <div class="devtools__section-title">Overlays</div>
            <div class="devmenu__bulk">
              <button type="button" class="devmenu__bulk-btn" onclick={() => setAll(false)}>
                Hide all
              </button>
              <button type="button" class="devmenu__bulk-btn" onclick={() => setAll(true)}>
                Show all
              </button>
            </div>

            {#each HUD_ROWS as row (row.key)}
              <div class="devmenu__row" class:devmenu__row--on={devPreview.toggles[row.key]}>
                <label class="devmenu__row-label">
                  <input type="checkbox" bind:checked={devPreview.toggles[row.key]} />
                  {row.label}
                </label>
                <button
                  type="button"
                  class="devmenu__solo"
                  title="Show only this"
                  onclick={() => solo(row.key)}
                >
                  solo
                </button>
              </div>
            {/each}
          </div>

          {#if devPreview.toggles.progress}
            <div class="devtools__section">
              <div class="devtools__section-title">Progress fill</div>
              <div class="devmenu__slider">
                <input type="range" min="0" max="100" step="1" bind:value={devPreview.progressValue} />
                <span>{devPreview.progressValue}%</span>
              </div>
            </div>
          {/if}
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .devmenu__tabs {
    display: flex;
    gap: calc(0.35vh / var(--ui-scale, 1));
    flex-shrink: 0;
  }

  .devmenu__tab {
    flex: 1;
    padding: calc(0.45vh / var(--ui-scale, 1)) calc(0.5vh / var(--ui-scale, 1));
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-field);
    color: var(--muted);
    font-family: inherit;
    font-size: calc(1.1vh / var(--ui-scale, 1));
    cursor: pointer;
  }

  .devmenu__tab--active {
    border-color: var(--line-blue);
    background: var(--tint-blue);
    color: var(--blue);
  }

  .devmenu__bulk {
    display: flex;
    gap: calc(0.35vh / var(--ui-scale, 1));
  }

  .devmenu__bulk-btn {
    flex: 1;
    padding: calc(0.4vh / var(--ui-scale, 1)) calc(0.5vh / var(--ui-scale, 1));
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-field);
    color: var(--muted);
    font-family: inherit;
    font-size: calc(1.05vh / var(--ui-scale, 1));
    cursor: pointer;
  }

  .devmenu__bulk-btn:hover {
    color: var(--blue);
    border-color: var(--line-blue);
  }

  .devmenu__row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: calc(0.5vh / var(--ui-scale, 1));
    padding: calc(0.4vh / var(--ui-scale, 1)) calc(0.55vh / var(--ui-scale, 1));
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-field);
  }

  .devmenu__row--on {
    border-color: var(--line-blue);
    background: var(--tint-blue);
  }

  .devmenu__row-label {
    display: flex;
    align-items: center;
    gap: calc(0.5vh / var(--ui-scale, 1));
    color: var(--text);
    font-size: calc(1.15vh / var(--ui-scale, 1));
    cursor: pointer;
    min-width: 0;
  }

  .devmenu__row-label input {
    accent-color: var(--blue);
    cursor: pointer;
  }

  .devmenu__solo {
    flex-shrink: 0;
    padding: calc(0.2vh / var(--ui-scale, 1)) calc(0.4vh / var(--ui-scale, 1));
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--muted);
    font-family: inherit;
    font-size: calc(0.95vh / var(--ui-scale, 1));
    text-transform: uppercase;
    letter-spacing: calc(0.05vh / var(--ui-scale, 1));
    cursor: pointer;
  }

  .devmenu__solo:hover {
    color: var(--blue);
    border-color: var(--line-blue);
  }

  .devmenu__slider {
    display: flex;
    align-items: center;
    gap: calc(0.5vh / var(--ui-scale, 1));
  }

  .devmenu__slider input {
    flex: 1;
    min-width: 0;
    accent-color: var(--blue);
  }

  .devmenu__slider span {
    color: var(--muted);
    font-size: calc(1.05vh / var(--ui-scale, 1));
    font-variant-numeric: tabular-nums;
  }
</style>
