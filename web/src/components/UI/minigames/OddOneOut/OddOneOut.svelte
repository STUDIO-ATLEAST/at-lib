<script lang="ts">
  import { untrack } from "svelte";
  import ScanSearch from "@lucide/svelte/icons/scan-search";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { OddOneOutConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./OddOneOut.css";

  let { config: configProp }: { config: OddOneOutConfig } = $props();

  const config = untrack(() => configProp);

  type DiffKind = "rotation" | "missing" | "color" | "number" | "shape";
  type BaseShape = "hash" | "ring" | "chevron" | "node";

  type Cell = {
    id: number;
    odd: boolean;
    shape: BaseShape;
    rotation: number;
    missing: boolean;
    color: string;
    number: number;
    found: boolean;
  };

  function mulberry32(seed: number) {
    let a = seed >>> 0;
    return () => {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function pick<T>(rand: () => number, list: T[]): T {
    return list[Math.floor(rand() * list.length)]!;
  }

  function rotationDelta(vis: number) {
    return ({ 1: 45, 2: 30, 3: 18, 4: 12, 5: 8 } as Record<number, number>)[vis] ?? 18;
  }

  function colorPair(vis: number, rand: () => number) {
    // Base is the theme blue (#4dabf7); harder levels use ever closer blue shades for the odd one.
    const base = "var(--blue)";
    if (vis <= 2) {
      return { normal: base, odd: pick(rand, ["#69db7c", "#ffd43b", "#ff8787"]) };
    }
    if (vis === 3) {
      return { normal: base, odd: "#a5d8ff" };
    }
    return { normal: base, odd: vis === 4 ? "#74c0fc" : "#339af0" };
  }

  function generateBoard(
    boardSize: number,
    oddsWanted: number,
    vis: number,
    boardSeed: number
  ): Cell[] {
    const rand = mulberry32(boardSeed);
    const cells = boardSize * boardSize;
    const odds = Math.min(oddsWanted, Math.max(1, cells - 2));
    const kind = pick(rand, [
      "rotation",
      "missing",
      "color",
      "number",
      "shape",
    ] as DiffKind[]);
    const baseShape = pick(rand, ["hash", "ring", "chevron", "node"] as BaseShape[]);
    const baseNumber = 1 + Math.floor(rand() * 8);
    const baseRotation = Math.floor(rand() * 4) * 90;
    const colors = colorPair(vis, rand);
    const altShape = pick(
      rand,
      (["hash", "ring", "chevron", "node"] as BaseShape[]).filter((s) => s !== baseShape)
    );

    const oddIndexes = new Set<number>();
    while (oddIndexes.size < odds) {
      oddIndexes.add(Math.floor(rand() * cells));
    }

    const board: Cell[] = [];
    for (let i = 0; i < cells; i++) {
      const odd = oddIndexes.has(i);
      let shape = baseShape;
      let rotation = baseRotation;
      let missing = false;
      let color = colors.normal;
      let number = baseNumber;

      if (odd) {
        if (kind === "rotation") {
          rotation = (baseRotation + rotationDelta(vis)) % 360;
        } else if (kind === "missing") {
          missing = true;
        } else if (kind === "color") {
          color = colors.odd;
        } else if (kind === "number") {
          number = ((baseNumber + (vis <= 2 ? 2 : 1) - 1) % 9) + 1;
        } else {
          shape = altShape;
        }
      }

      board.push({
        id: i,
        odd,
        shape,
        rotation,
        missing,
        color,
        number,
        found: false,
      });
    }
    return board;
  }

  const size = $derived(Math.min(7, Math.max(3, config.size)));
  const oddCount = $derived(Math.min(4, Math.max(1, config.oddCount)));
  const visibility = $derived(Math.min(5, Math.max(1, config.visibility)));
  const animated = $derived(!!config.animated);
  const stages = $derived(Math.min(5, Math.max(1, config.stages)));
  const maxLives = $derived(Math.min(5, Math.max(1, config.lives)));
  const duration = $derived(Math.max(4000, config.duration));
  const baseSeed = $derived(config.seed ?? 1);

  let stage = $state(0);
  let lives = $state(untrack(() => maxLives));
  let cells = $state<Cell[]>([]);
  let wrongId = $state<number | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let livesRef = untrack(() => maxLives);
  let stageRef = 0;
  let cellsRef: Cell[] = [];
  let startRef = performance.now();

  const foundCount = $derived(cells.filter((c) => c.odd && c.found).length);
  const totalOdds = $derived(cells.filter((c) => c.odd).length);
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function startStage(stageIndex: number) {
    const next = generateBoard(
      size,
      oddCount,
      visibility,
      baseSeed + stageIndex * 9973 + 41
    );
    cells = next;
    cellsRef = next;
    wrongId = null;
    stage = stageIndex;
    stageRef = stageIndex;
    startRef = performance.now();
    progress = 100;
  }

  function onCellClick(id: number) {
    if (finishedRef) return;
    const list = cellsRef;
    const cell = list.find((c) => c.id === id);
    if (!cell || cell.found) return;

    if (!cell.odd) {
      wrongId = id;
      window.setTimeout(() => (wrongId = null), 220);
      const nextLives = livesRef - 1;
      livesRef = nextLives;
      lives = nextLives;
      if (nextLives <= 0) void endGame(false);
      return;
    }

    const next = list.map((c) => (c.id === id ? { ...c, found: true } : c));
    cellsRef = next;
    cells = next;

    const remaining = next.filter((c) => c.odd && !c.found).length;
    if (remaining === 0) {
      const nextStage = stageRef + 1;
      if (nextStage >= stages) {
        window.setTimeout(() => void endGame(true), 200);
      } else {
        window.setTimeout(() => startStage(nextStage), 260);
      }
    }
  }

  $effect(() => {
    size;
    oddCount;
    visibility;
    stages;
    duration;
    maxLives;
    animated;
    baseSeed;
    finishedRef = false;
    finished = false;
    result = null;
    lives = maxLives;
    livesRef = maxLives;
    runId = performance.now();
    startStage(0);
  });

  $effect(() => {
    runId;
    stage;
    const dur = duration;
    startRef = performance.now();
    progress = 100;
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const left = Math.max(0, 100 - ((now - startRef) / dur) * 100);
      progress = left;
      if (left <= 0) {
        void endGame(false);
        return;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  const subtitle = $derived(
    result !== null
      ? result
        ? "Matched"
        : "Failed"
      : `Stage ${stage + 1}/${stages}`
  );
</script>

<div class="mg">
  <div class="mg__card ooo__card">
    <div class="mg__header">
      <div class="mg__heading">
        <ScanSearch class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Odd One Out</span>
        <span class="mg__subtitle">{subtitle}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="ooo__body">
        <div
          class="ooo__grid"
          style="grid-template-columns: repeat({size}, minmax(0, 1fr)); grid-template-rows: repeat({size}, minmax(0, 1fr))"
        >
          {#each cells as cell (cell.id)}
            <button
              type="button"
              class={[
                "ooo__cell",
                cell.found ? "ooo__cell--found" : "",
                wrongId === cell.id ? "ooo__cell--wrong" : "",
              ]}
              disabled={finished || cell.found}
              onclick={() => onCellClick(cell.id)}
            >
              <svg
                class={["ooo__symbol", animated ? "ooo__symbol--animate" : ""]}
                viewBox="0 0 36 36"
                aria-hidden="true"
              >
                <g transform="rotate({cell.rotation} 18 18)">
                  {#if cell.shape === "hash"}
                    <line
                      x1="8"
                      y1="14"
                      x2="28"
                      y2="14"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    <line
                      x1="8"
                      y1="22"
                      x2="28"
                      y2="22"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    {#if !cell.missing}
                      <line
                        x1="14"
                        y1="8"
                        x2="14"
                        y2="28"
                        fill="none"
                        stroke={cell.color}
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    {/if}
                    <line
                      x1="22"
                      y1="8"
                      x2="22"
                      y2="28"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  {:else if cell.shape === "ring"}
                    <circle
                      cx="18"
                      cy="18"
                      r="10"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    {#if !cell.missing}
                      <circle
                        cx="18"
                        cy="18"
                        r="4"
                        fill="none"
                        stroke={cell.color}
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    {/if}
                    <line
                      x1="18"
                      y1="6"
                      x2="18"
                      y2="10"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  {:else if cell.shape === "chevron"}
                    <polyline
                      points="10,12 18,8 26,12"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    {#if !cell.missing}
                      <polyline
                        points="10,20 18,16 26,20"
                        fill="none"
                        stroke={cell.color}
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    {/if}
                    <polyline
                      points="10,28 18,24 26,28"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  {:else}
                    <circle
                      cx="18"
                      cy="12"
                      r="3.2"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    <circle
                      cx="10"
                      cy="24"
                      r="3.2"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    <circle
                      cx="26"
                      cy="24"
                      r="3.2"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                    {#if !cell.missing}
                      <line
                        x1="18"
                        y1="15.2"
                        x2="11.8"
                        y2="21.2"
                        fill="none"
                        stroke={cell.color}
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                      <line
                        x1="18"
                        y1="15.2"
                        x2="24.2"
                        y2="21.2"
                        fill="none"
                        stroke={cell.color}
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    {/if}
                    <line
                      x1="12.8"
                      y1="24"
                      x2="23.2"
                      y2="24"
                      fill="none"
                      stroke={cell.color}
                      stroke-width="2.2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  {/if}
                  <text
                    x="30"
                    y="10"
                    fill={cell.color}
                    font-size="7"
                    text-anchor="end"
                  >
                    {cell.number}
                  </text>
                </g>
              </svg>
            </button>
          {/each}
        </div>

        <div class="ooo__meta">
          <span>
            Found <strong>{foundCount}/{totalOdds}</strong>
          </span>
          <span>
            Lives <strong>{lives}</strong>
          </span>
        </div>
      </div>
    </div>

    <div class="mg__footer">Spot the different symbol - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
