<script lang="ts">
  import { untrack } from "svelte";
  import LayoutGrid from "@lucide/svelte/icons/layout-grid";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { MergeConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Merge.css";

  let { config: configProp }: { config: MergeConfig } = $props();

  const config = untrack(() => configProp);

  type Dir = "up" | "down" | "left" | "right";

  type Tile = {
    id: number;
    value: number;
    row: number;
    col: number;
    /** Applied after the slide finishes (merge result). */
    pendingValue?: number;
    isNew?: boolean;
    isMerged?: boolean;
  };

  const SLIDE_MS = 300;

  let nextTileId = 1;

  function tileClass(value: number): string {
    if (value <= 2) return "merge__tile merge__tile--2";
    if (value <= 4) return "merge__tile merge__tile--4";
    if (value <= 8) return "merge__tile merge__tile--8";
    if (value <= 16) return "merge__tile merge__tile--16";
    if (value <= 32) return "merge__tile merge__tile--32";
    if (value <= 64) return "merge__tile merge__tile--64";
    if (value <= 128) return "merge__tile merge__tile--128";
    if (value <= 256) return "merge__tile merge__tile--256";
    return "merge__tile merge__tile--high";
  }

  function createTile(value: number, row: number, col: number, isNew = false): Tile {
    return { id: nextTileId++, value, row, col, isNew };
  }

  function spawnTile(current: Tile[], boardSize: number): Tile | null {
    const taken = new Set(current.map((t) => `${t.row},${t.col}`));
    const empties: { row: number; col: number }[] = [];
    for (let r = 0; r < boardSize; r++) {
      for (let c = 0; c < boardSize; c++) {
        if (!taken.has(`${r},${c}`)) empties.push({ row: r, col: c });
      }
    }
    if (empties.length === 0) return null;
    const spot = empties[Math.floor(Math.random() * empties.length)];
    return createTile(Math.random() < 0.9 ? 2 : 4, spot.row, spot.col, true);
  }

  function createStartTiles(boardSize: number): Tile[] {
    const start: Tile[] = [];
    const a = spawnTile(start, boardSize);
    if (a) start.push(a);
    const b = spawnTile(start, boardSize);
    if (b) start.push(b);
    return start;
  }

  function canMove(current: Tile[], boardSize: number): boolean {
    if (current.length < boardSize * boardSize) return true;
    const grid = Array.from({ length: boardSize }, () => Array<number>(boardSize).fill(0));
    for (const t of current) grid[t.row][t.col] = t.value;
    for (let r = 0; r < boardSize; r++) {
      for (let c = 0; c < boardSize; c++) {
        const v = grid[r][c];
        if (c + 1 < boardSize && grid[r][c + 1] === v) return true;
        if (r + 1 < boardSize && grid[r + 1][c] === v) return true;
      }
    }
    return false;
  }

  /** Slide + merge one line of tiles; returns updated tiles for that line. */
  function slideLineTiles(
    line: Tile[],
    boardSize: number,
    axis: "row" | "col",
    fixed: number,
    reverse: boolean
  ): { tiles: Tile[]; removed: Tile[]; moved: boolean } {
    const ordered = [...line].sort((a, b) =>
      reverse
        ? axis === "col"
          ? b.col - a.col
          : b.row - a.row
        : axis === "col"
          ? a.col - b.col
          : a.row - b.row
    );

    const out: Tile[] = [];
    const removed: Tile[] = [];
    let cursor = reverse ? boardSize - 1 : 0;
    let moved = false;
    let i = 0;

    while (i < ordered.length) {
      const current = ordered[i];
      const next = ordered[i + 1];

      if (next && current.value === next.value) {
        const destRow = axis === "row" ? fixed : cursor;
        const destCol = axis === "col" ? fixed : cursor;

        if (current.row !== destRow || current.col !== destCol) moved = true;
        if (next.row !== destRow || next.col !== destCol) moved = true;

        // Keep original values while sliding; combine number appears after they meet.
        out.push({
          ...current,
          value: current.value,
          pendingValue: current.value * 2,
          row: destRow,
          col: destCol,
          isNew: false,
          isMerged: false,
        });
        removed.push({
          ...next,
          value: next.value,
          row: destRow,
          col: destCol,
          isNew: false,
          isMerged: false,
        });

        cursor += reverse ? -1 : 1;
        i += 2;
      } else {
        const destRow = axis === "row" ? fixed : cursor;
        const destCol = axis === "col" ? fixed : cursor;
        if (current.row !== destRow || current.col !== destCol) moved = true;
        out.push({
          ...current,
          row: destRow,
          col: destCol,
          isNew: false,
          isMerged: false,
          pendingValue: undefined,
        });
        cursor += reverse ? -1 : 1;
        i += 1;
      }
    }

    return { tiles: out, removed, moved };
  }

  function moveTiles(
    current: Tile[],
    boardSize: number,
    dir: Dir
  ): { tiles: Tile[]; ghosts: Tile[]; moved: boolean } {
    const next: Tile[] = [];
    const nextGhosts: Tile[] = [];
    let moved = false;

    if (dir === "left" || dir === "right") {
      for (let r = 0; r < boardSize; r++) {
        const line = current.filter((t) => t.row === r);
        const res = slideLineTiles(line, boardSize, "row", r, dir === "right");
        if (res.moved) moved = true;
        next.push(...res.tiles);
        nextGhosts.push(...res.removed);
      }
    } else {
      for (let c = 0; c < boardSize; c++) {
        const line = current.filter((t) => t.col === c);
        const res = slideLineTiles(line, boardSize, "col", c, dir === "down");
        if (res.moved) moved = true;
        next.push(...res.tiles);
        nextGhosts.push(...res.removed);
      }
    }

    return { tiles: next, ghosts: nextGhosts, moved };
  }

  const size = $derived(Math.min(5, Math.max(3, config.size || 4)));
  const target = $derived(Math.max(32, config.target));
  const duration = $derived(Math.max(10000, config.duration));

  const startTiles = createStartTiles(Math.min(5, Math.max(3, config.size || 4)));
  let tiles = $state<Tile[]>(startTiles);
  let ghosts = $state<Tile[]>([]);
  let best = $state(Math.max(0, ...startTiles.map((t) => t.value)));
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let tilesRef: Tile[] = startTiles;
  let animatingRef = false;
  let startRef = performance.now();

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  $effect(() => {
    const next = createStartTiles(size);
    void target;
    void config.duration;
    tiles = next;
    tilesRef = next;
    ghosts = [];
    best = Math.max(0, ...next.map((t) => t.value));
    finished = false;
    result = null;
    finishedRef = false;
    animatingRef = false;
    startRef = performance.now();
    progress = 100;
  });

  function applyMove(dir: Dir) {
    if (finishedRef || animatingRef) return;

    const { tiles: slid, ghosts: leaving, moved } = moveTiles(
      tilesRef,
      size,
      dir
    );
    if (!moved) return;

    animatingRef = true;
    tiles = slid;
    ghosts = leaving;
    tilesRef = slid;

    window.setTimeout(() => {
      // Tiles have met - show combined numbers, drop ghosts, spawn in place.
      let settled: Tile[] = slid.map((t) => {
        const merged = t.pendingValue != null;
        return {
          ...t,
          value: t.pendingValue ?? t.value,
          pendingValue: undefined,
          isMerged: merged,
          isNew: false,
        };
      });

      ghosts = [];
      tiles = settled;
      tilesRef = settled;
      best = Math.max(best, ...settled.map((t) => t.value));

      const spawned = spawnTile(settled, size);
      if (spawned) {
        settled = [...settled.map((t) => ({ ...t, isMerged: false })), spawned];
        tiles = settled;
        tilesRef = settled;
      }

      requestAnimationFrame(() => {
        settled = settled.map((t) => ({
          ...t,
          isNew: false,
          isMerged: false,
        }));
        tiles = settled;
        tilesRef = settled;
        animatingRef = false;

        if (settled.some((t) => t.value >= target)) {
          window.setTimeout(() => void endGame(true), 120);
          return;
        }
        if (!canMove(settled, size)) {
          window.setTimeout(() => void endGame(false), 120);
        }
      });
    }, SLIDE_MS);
  }

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;

      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }

      const map: Record<string, Dir> = {
        ArrowUp: "up",
        ArrowDown: "down",
        ArrowLeft: "left",
        ArrowRight: "right",
        KeyW: "up",
        KeyS: "down",
        KeyA: "left",
        KeyD: "right",
      };

      const dir = map[e.code];
      if (!dir) return;
      e.preventDefault();
      applyMove(dir);
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  $effect(() => {
    void size;
    void target;
    void config.duration;
    startRef = performance.now();
    progress = 100;

    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - startRef;
      const left = Math.max(0, 100 - (elapsed / duration) * 100);
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
</script>

<div class="mg">
  <div class="mg__card merge__card">
    <div class="mg__header">
      <div class="mg__heading">
        <LayoutGrid class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Merge</span>
        <span class="mg__subtitle">{best}/{target}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="merge__board" style="--merge-n: {size}">
        <div
          class="merge__slots"
          style="grid-template-columns: repeat({size}, minmax(0, 1fr)); grid-template-rows: repeat({size}, minmax(0, 1fr))"
        >
          {#each { length: size * size } as _}
            <div class="merge__slot"></div>
          {/each}
        </div>

        <div class="merge__layer">
          {#each ghosts as tile (`g-${tile.id}`)}
            <div
              class={[
                tileClass(tile.value),
                "merge__tile--abs",
                tile.isNew ? "merge__tile--static" : "",
                tile.isMerged ? "merge__tile--pop" : "",
                "merge__tile--ghost",
              ]}
              style="transform: translate({tile.col * 100}%, {tile.row * 100}%); transition-duration: {tile.isNew
                ? "0ms"
                : `${SLIDE_MS}ms`}; z-index: 1"
            >
              {tile.value}
            </div>
          {/each}
          {#each tiles as tile (`t-${tile.id}`)}
            <div
              class={[
                tileClass(tile.value),
                "merge__tile--abs",
                tile.isNew ? "merge__tile--static" : "",
                tile.isMerged ? "merge__tile--pop" : "",
              ]}
              style="transform: translate({tile.col * 100}%, {tile.row * 100}%); transition-duration: {tile.isNew
                ? "0ms"
                : `${SLIDE_MS}ms`}; z-index: {tile.isMerged ? 3 : 2}"
            >
              {tile.value}
            </div>
          {/each}
        </div>
      </div>
    </div>

    <div class="mg__footer">WASD / Arrows - reach {target} - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
