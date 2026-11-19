<script lang="ts">
  import { untrack } from "svelte";
  import ListOrdered from "@lucide/svelte/icons/list-ordered";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { SequenceConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Sequence.css";

  let { config: configProp }: { config: SequenceConfig } = $props();

  const config = untrack(() => configProp);

  const LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ";

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

  function pickLetter(rand: () => number, letters: string) {
    return letters[Math.floor(rand() * letters.length)]!;
  }

  function makeTarget(rand: () => number, length: number, letters: string) {
    const seq: string[] = [];
    for (let i = 0; i < length; i++) seq.push(pickLetter(rand, letters));
    return seq;
  }

  function buildGrid(size: number, seq: string[], gridSeed: number, letters: string): string[] {
    const rand = mulberry32(gridSeed);
    const cells = size * size;
    const next: string[] = Array.from({ length: cells }, () => pickLetter(rand, letters));

    const maxCol = size - seq.length;
    const row = Math.floor(rand() * size);
    const col = Math.floor(rand() * (maxCol + 1));
    const start = row * size + col;
    for (let i = 0; i < seq.length; i++) {
      next[start + i] = seq[i]!;
    }
    return next;
  }

  const stages = $derived(Math.min(5, Math.max(1, config.stages)));
  const gridSize = $derived(Math.min(12, Math.max(5, config.gridSize)));
  const seqLen = $derived(Math.min(gridSize, Math.min(6, Math.max(2, config.sequenceLength))));
  const duration = $derived(Math.max(5000, config.duration));
  const penalty = $derived(Math.max(0, config.penalty));
  const scrambleCount = $derived(Math.max(0, config.scrambleCount));
  const instantFail = $derived(!!config.instantFail);
  const baseSeed = $derived(config.seed ?? 1);
  const alphabet = $derived(LETTERS.slice(0, gridSize <= 6 ? 8 : gridSize <= 8 ? 12 : 16));

  let stage = $state(0);
  let target = $state<string[]>([]);
  let grid = $state<string[]>([]);
  let cursor = $state({ row: 0, col: 0 });
  let flash = $state<"ok" | "bad" | null>(null);
  let scrambling = $state(false);
  let scramblesDone = $state(0);
  let timeLeftMs = $state(untrack(() => duration));
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let stageRef = 0;
  let cursorRef = { row: 0, col: 0 };
  let gridRef: string[] = [];
  let targetRef: string[] = [];
  let timeLeftRef = untrack(() => duration);
  let lastTickRef = performance.now();
  let scrambleTimersRef: number[] = [];
  let flashRef: "ok" | "bad" | null = null;

  const progress = $derived(Math.max(0, Math.min(100, (timeLeftMs / duration) * 100)));
  const secondsLeft = $derived(timeLeftMs / 1000);
  const selectedIds = $derived.by(() => {
    const ids: number[] = [];
    for (let i = 0; i < seqLen; i++) {
      ids.push(cursor.row * gridSize + cursor.col + i);
    }
    return ids;
  });

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    scrambleTimersRef.forEach((t) => window.clearTimeout(t));
    scrambleTimersRef = [];
    await finishMinigame(success, (ok) => (result = ok));
  }

  function clearScrambleTimers() {
    scrambleTimersRef.forEach((t) => window.clearTimeout(t));
    scrambleTimersRef = [];
  }

  function scheduleScrambles(stageSeed: number) {
    clearScrambleTimers();
    scramblesDone = 0;
    if (scrambleCount <= 0) return;

    for (let i = 0; i < scrambleCount; i++) {
      const at = ((i + 1) / (scrambleCount + 1)) * duration;
      const t = window.setTimeout(() => {
        if (finishedRef) return;
        scrambling = true;
        const next = buildGrid(gridSize, targetRef, stageSeed + 500 + i * 17, alphabet);
        gridRef = next;
        grid = next;
        scramblesDone = i + 1;
        window.setTimeout(() => (scrambling = false), 280);
      }, at);
      scrambleTimersRef.push(t);
    }
  }

  function startStage(stageIndex: number) {
    const stageSeed = baseSeed + stageIndex * 7919;
    const rand = mulberry32(stageSeed);
    const nextTarget = makeTarget(rand, seqLen, alphabet);
    const nextGrid = buildGrid(gridSize, nextTarget, stageSeed + 3, alphabet);
    targetRef = nextTarget;
    gridRef = nextGrid;
    target = nextTarget;
    grid = nextGrid;
    cursor = { row: 0, col: 0 };
    cursorRef = { row: 0, col: 0 };
    flash = null;
    flashRef = null;
    scrambling = false;
    stage = stageIndex;
    stageRef = stageIndex;
    timeLeftMs = duration;
    timeLeftRef = duration;
    lastTickRef = performance.now();
    scheduleScrambles(stageSeed);
  }

  function trySelect() {
    if (finishedRef || flashRef) return;
    const { row, col } = cursorRef;
    const g = gridRef;
    const t = targetRef;
    let match = true;
    for (let i = 0; i < seqLen; i++) {
      if (g[row * gridSize + col + i] !== t[i]) {
        match = false;
        break;
      }
    }

    if (match) {
      flash = "ok";
      flashRef = "ok";
      window.setTimeout(() => {
        flash = null;
        flashRef = null;
        const nextStage = stageRef + 1;
        if (nextStage >= stages) {
          void endGame(true);
        } else {
          startStage(nextStage);
        }
      }, 220);
      return;
    }

    flash = "bad";
    flashRef = "bad";
    window.setTimeout(() => {
      flash = null;
      flashRef = null;
    }, 220);

    if (instantFail) {
      window.setTimeout(() => void endGame(false), 220);
      return;
    }

    if (penalty > 0) {
      const next = Math.max(0, timeLeftRef - penalty);
      timeLeftRef = next;
      timeLeftMs = next;
      if (next <= 0) void endGame(false);
    }
  }

  $effect(() => {
    stages;
    duration;
    alphabet;
    baseSeed;
    gridSize;
    seqLen;
    scrambleCount;
    finishedRef = false;
    finished = false;
    result = null;
    runId = performance.now();
    startStage(0);
    return () => clearScrambleTimers();
  });

  $effect(() => {
    runId;
    stage;
    lastTickRef = performance.now();
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const dt = now - lastTickRef;
      lastTickRef = now;
      const next = Math.max(0, timeLeftRef - dt);
      timeLeftRef = next;
      timeLeftMs = next;
      if (next <= 0) {
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
        return;
      }

      if (e.code === "Enter" || e.code === "NumpadEnter" || e.code === "Space") {
        e.preventDefault();
        trySelect();
        return;
      }

      const maxRow = gridSize - 1;
      const maxCol = gridSize - seqLen;
      let { row, col } = cursorRef;
      let moved = false;

      if (e.code === "ArrowUp" || e.code === "KeyW") {
        row = Math.max(0, row - 1);
        moved = true;
      } else if (e.code === "ArrowDown" || e.code === "KeyS") {
        row = Math.min(maxRow, row + 1);
        moved = true;
      } else if (e.code === "ArrowLeft" || e.code === "KeyA") {
        col = Math.max(0, col - 1);
        moved = true;
      } else if (e.code === "ArrowRight" || e.code === "KeyD") {
        col = Math.min(maxCol, col + 1);
        moved = true;
      }

      if (moved) {
        e.preventDefault();
        const next = { row, col };
        cursorRef = next;
        cursor = next;
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  const subtitle = $derived(
    result !== null
      ? result
        ? "Found"
        : "Failed"
      : `Stage ${stage + 1}/${stages}`
  );
</script>

<div class="mg">
  <div class="mg__card seq__card">
    <div class="mg__header">
      <div class="mg__heading">
        <ListOrdered class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Sequence</span>
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
      <div class="seq__body">
        <div class="seq__target">
          <div class="seq__target-label">Find this sequence</div>
          <div class="seq__target-row">
            {#each target as ch}
              <span class="seq__chip">{ch}</span>
            {/each}
          </div>
        </div>

        <div
          class={["seq__board", scrambling ? "seq__board--scramble" : ""]}
          style="grid-template-columns: repeat({gridSize}, minmax(0, 1fr)); grid-template-rows: repeat({gridSize}, minmax(0, 1fr))"
        >
          {#each grid as ch, i}
            {@const selected = selectedIds.includes(i)}
            <div
              class={[
                "seq__cell",
                selected ? "seq__cell--sel" : "",
                selected && flash === "ok" ? "seq__cell--flash-ok" : "",
                selected && flash === "bad" ? "seq__cell--flash-bad" : "",
              ]}
            >
              {ch}
            </div>
          {/each}
        </div>

        <div class="seq__meta">
          <span>
            Window <strong>{seqLen}</strong>
          </span>
          <span>
            Scrambles <strong>{scramblesDone}/{scrambleCount}</strong>
          </span>
        </div>
      </div>
    </div>

    <div class="mg__footer">WASD / arrows move - Enter select - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
