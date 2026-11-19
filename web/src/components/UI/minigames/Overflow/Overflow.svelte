<script lang="ts">
  import { untrack } from "svelte";
  import Droplets from "@lucide/svelte/icons/droplets";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { OverflowConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Overflow.css";

  let { config: configProp }: { config: OverflowConfig } = $props();

  const config = untrack(() => configProp);

  type Dir = "N" | "E" | "S" | "W";
  type PipeType = "I" | "L";

  type Cell = {
    type: PipeType;
    rot: number; // 0-3
  };

  const OPP: Record<Dir, Dir> = { N: "S", E: "W", S: "N", W: "E" };
  const DELTA: Record<Dir, [number, number]> = {
    N: [-1, 0],
    E: [0, 1],
    S: [1, 0],
    W: [0, -1],
  };

  function dirsFor(type: PipeType, rot: number): Dir[] {
    const r = ((rot % 4) + 4) % 4;
    if (type === "I") return r % 2 === 0 ? ["N", "S"] : ["E", "W"];
    const corners: Dir[][] = [
      ["N", "E"],
      ["E", "S"],
      ["S", "W"],
      ["W", "N"],
    ];
    return corners[r];
  }

  function pipeMatching(a: Dir, b: Dir): Cell {
    const pair = new Set([a, b]);
    if ((pair.has("N") && pair.has("S")) || (pair.has("E") && pair.has("W"))) {
      return { type: "I", rot: pair.has("N") ? 0 : 1 };
    }

    const corners: [Dir, Dir, number][] = [
      ["N", "E", 0],
      ["E", "S", 1],
      ["S", "W", 2],
      ["W", "N", 3],
    ];
    for (const [d1, d2, rot] of corners) {
      if (pair.has(d1) && pair.has(d2)) return { type: "L", rot };
    }
    return { type: "L", rot: 0 };
  }

  function randInt(n: number) {
    return Math.floor(Math.random() * n);
  }

  function generateBoard(boardSize: number): Cell[][] {
    const mid = Math.floor(boardSize / 2);
    const start = { r: mid, c: 0 };
    const end = { r: mid, c: boardSize - 1 };

    // Build a simple path left → right with occasional vertical jogs
    const path: { r: number; c: number }[] = [{ ...start }];
    let r = start.r;
    let c = start.c;

    while (c < end.c || r !== end.r) {
      const options: { r: number; c: number }[] = [];
      if (c < end.c) options.push({ r, c: c + 1 });
      if (r > 0 && c < end.c) options.push({ r: r - 1, c });
      if (r < boardSize - 1 && c < end.c) options.push({ r: r + 1, c });
      if (c === end.c) {
        if (r < end.r) options.push({ r: r + 1, c });
        if (r > end.r) options.push({ r: r - 1, c });
      }

      // Prefer moving right
      const pick =
        options.find((o) => o.c > c && Math.random() < 0.7) ??
        options[randInt(options.length)];

      // Avoid revisiting
      if (path.some((p) => p.r === pick.r && p.c === pick.c)) {
        if (c < end.c) {
          c += 1;
          path.push({ r, c });
        } else if (r !== end.r) {
          r += r < end.r ? 1 : -1;
          path.push({ r, c });
        } else break;
        continue;
      }

      r = pick.r;
      c = pick.c;
      path.push({ r, c });
      if (path.length > boardSize * boardSize) break;
    }

    if (path[path.length - 1].r !== end.r || path[path.length - 1].c !== end.c) {
      path.push({ ...end });
    }

    const nextBoard: Cell[][] = Array.from({ length: boardSize }, () =>
      Array.from({ length: boardSize }, () => ({
        type: Math.random() < 0.45 ? ("I" as const) : ("L" as const),
        rot: randInt(4),
      }))
    );

    for (let i = 0; i < path.length; i++) {
      const cur = path[i];
      const prev = path[i - 1];
      const next = path[i + 1];
      const needed: Dir[] = [];

      if (prev) {
        if (prev.r < cur.r) needed.push("N");
        if (prev.r > cur.r) needed.push("S");
        if (prev.c < cur.c) needed.push("W");
        if (prev.c > cur.c) needed.push("E");
      } else {
        needed.push("W"); // source enters from left
      }

      if (next) {
        if (next.r < cur.r) needed.push("N");
        if (next.r > cur.r) needed.push("S");
        if (next.c < cur.c) needed.push("W");
        if (next.c > cur.c) needed.push("E");
      } else {
        needed.push("E"); // drain exits right
      }

      const unique = [...new Set(needed)];
      if (unique.length === 1) {
        // dead-end shouldn't happen; force straight through
        nextBoard[cur.r][cur.c] = pipeMatching(unique[0], OPP[unique[0]]);
      } else {
        nextBoard[cur.r][cur.c] = pipeMatching(unique[0], unique[1]);
      }
    }

    // Scramble rotations so player must solve
    for (let rr = 0; rr < boardSize; rr++) {
      for (let cc = 0; cc < boardSize; cc++) {
        nextBoard[rr][cc] = {
          ...nextBoard[rr][cc],
          rot: (nextBoard[rr][cc].rot + randInt(4)) % 4,
        };
      }
    }

    return nextBoard;
  }

  function hasConnection(cell: Cell, dir: Dir) {
    return dirsFor(cell.type, cell.rot).includes(dir);
  }

  function findFlow(cells: Cell[][], boardSize: number): Set<string> {
    const mid = Math.floor(boardSize / 2);
    const startKey = `${mid},0`;
    const visited = new Set<string>();
    const queue = [{ r: mid, c: 0 }];

    // Source must open west (toward port) and have some east/north/south connection
    if (!hasConnection(cells[mid][0], "W")) {
      return visited;
    }

    visited.add(startKey);

    while (queue.length) {
      const { r, c } = queue.shift()!;
      const cell = cells[r][c];
      for (const dir of dirsFor(cell.type, cell.rot)) {
        const [dr, dc] = DELTA[dir];
        const nr = r + dr;
        const nc = c + dc;
        if (nr < 0 || nc < 0 || nr >= boardSize || nc >= boardSize) continue;
        const key = `${nr},${nc}`;
        if (visited.has(key)) continue;
        if (!hasConnection(cells[nr][nc], OPP[dir])) continue;
        visited.add(key);
        queue.push({ r: nr, c: nc });
      }
    }

    return visited;
  }

  function isSolved(cells: Cell[][], boardSize: number) {
    const mid = Math.floor(boardSize / 2);
    const nextFlow = findFlow(cells, boardSize);
    if (!nextFlow.has(`${mid},${boardSize - 1}`)) return false;
    // Drain cell must open east to the port
    return hasConnection(cells[mid][boardSize - 1], "E");
  }

  const size = 5; // fixed 5x5 - source/drain on middle row
  const duration = Math.max(8000, config.duration);

  let board = $state<Cell[][]>(generateBoard(size));
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let boardRef = untrack(() => board);
  let startRef = performance.now();

  const flow = $derived(findFlow(board, size));
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function rotateCell(r: number, c: number) {
    if (finishedRef) return;

    const next = board.map((row) => row.map((cell) => ({ ...cell })));
    next[r][c] = { ...next[r][c], rot: (next[r][c].rot + 1) % 4 };
    boardRef = next;
    board = next;

    if (isSolved(next, size)) {
      window.setTimeout(() => void endGame(true), 180);
    }
  }

  $effect(() => {
    startRef = performance.now();
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
</script>

<div class="mg">
  <div class="mg__card overflow__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Droplets class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Overflow</span>
        <span class="mg__subtitle">Source to drain</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="overflow__board-wrap">
        <span class="overflow__port" title="Source"></span>
        <div
          class="overflow__grid"
          style="grid-template-columns: repeat({size}, minmax(0, 1fr)); grid-template-rows: repeat({size}, minmax(0, 1fr))"
        >
          {#each board as row, r}
            {#each row as cell, c}
              {@const flowing = flow.has(`${r},${c}`)}
              <button
                type="button"
                class={["overflow__cell", flowing ? "overflow__cell--flow" : ""]}
                disabled={finished}
                onclick={() => rotateCell(r, c)}
              >
                {#if cell.type === "I"}
                  <svg class="overflow__pipe" viewBox="0 0 40 40">
                    <g transform="rotate({cell.rot * 90} 20 20)">
                      <line class="overflow__pipe-line" x1="20" y1="4" x2="20" y2="36" />
                      <circle class="overflow__pipe-node" cx="20" cy="4" r="2.4" />
                      <circle class="overflow__pipe-node" cx="20" cy="36" r="2.4" />
                    </g>
                  </svg>
                {:else}
                  <svg class="overflow__pipe" viewBox="0 0 40 40">
                    <g transform="rotate({cell.rot * 90} 20 20)">
                      <path class="overflow__pipe-line" d="M20 4 L20 20 L36 20" />
                      <circle class="overflow__pipe-node" cx="20" cy="4" r="2.4" />
                      <circle class="overflow__pipe-node" cx="36" cy="20" r="2.4" />
                      <circle class="overflow__pipe-node" cx="20" cy="20" r="2.2" />
                    </g>
                  </svg>
                {/if}
              </button>
            {/each}
          {/each}
        </div>
        <span class="overflow__port" title="Drain"></span>
      </div>
    </div>

    <div class="mg__footer">Click to rotate - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
