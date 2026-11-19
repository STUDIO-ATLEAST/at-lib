<script lang="ts">
  import { untrack } from "svelte";
  import Database from "@lucide/svelte/icons/database";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { DataCrackConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import MinigameStages from "../../../MinigameStages.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./DataCrack.css";

  let { config: configProp }: { config: DataCrackConfig } = $props();

  const config = untrack(() => configProp);

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

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

  const stages = clamp(Math.floor(config.stages || 1), 1, 5);
  const segments = clamp(Math.floor(config.segments || 6), 3, 12);
  const speed = clamp(config.segmentSpeed || 60, 15, 250);
  const gap = clamp(config.gapSize || 22, 10, 40);
  const lineWidth = clamp(config.lineWidth || 34, 4, 80);
  const duration = Math.max(0, config.duration || 0);
  const baseSeed = config.seed ?? Math.floor(Math.random() * 2147483646) + 1;

  // Gap center travels between these bounds (percent of board height from the top).
  const amplitude = 50 - gap / 2 - 6;
  const omega = speed / amplitude;

  type Column = { phase: number; lockedAt: number | null };

  let stage = $state(0);
  let columns = $state<Column[]>([]);
  let active = $state(0);
  let time = $state(0);
  let flash = $state<"ok" | "bad" | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let boardH = $state(0);

  let finishedRef = false;
  let stoppedRef = false;
  let lockRef = false;
  let columnsRef: Column[] = [];
  let activeRef = 0;
  let stageRef = 0;
  let timeRef = 0;
  let stageStartRef = performance.now();

  const lineHalf = $derived(boardH > 0 ? (lineWidth / 2 / boardH) * 100 : 4);
  const lockedCount = $derived(columns.filter((c) => c.lockedAt !== null).length);
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const subtitle = $derived(
    result !== null ? (result ? "Cracked" : "Failed") : `${lockedCount}/${segments}`
  );

  function gapCenter(col: Column, t: number) {
    if (col.lockedAt !== null) return col.lockedAt;
    return 50 + amplitude * Math.sin(omega * t + col.phase);
  }

  function buildColumns(stageIndex: number): Column[] {
    const rand = mulberry32(baseSeed + stageIndex * 7919 + 17);
    const spread = 0.55 + rand() * 0.35;
    const offset = rand() * Math.PI * 2;
    return Array.from({ length: segments }, (_, i) => ({
      phase: offset + i * spread + (rand() - 0.5) * 0.4,
      lockedAt: null,
    }));
  }

  function startStage(stageIndex: number) {
    const next = buildColumns(stageIndex);
    columnsRef = next;
    columns = next;
    activeRef = 0;
    active = 0;
    stageRef = stageIndex;
    stage = stageIndex;
    timeRef = 0;
    time = 0;
    stageStartRef = performance.now();
    progress = 100;
    stoppedRef = false;
    lockRef = false;
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    stoppedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function tryLock() {
    if (finishedRef || stoppedRef || lockRef) return;
    const idx = activeRef;
    const col = columnsRef[idx];
    if (!col) return;

    const center = gapCenter(col, timeRef);
    const tolerance = gap / 2 - lineHalf;

    if (Math.abs(center - 50) > tolerance) {
      flash = "bad";
      stoppedRef = true;
      window.setTimeout(() => void endGame(false), 240);
      return;
    }

    lockRef = true;
    const next = columnsRef.map((c, i) => (i === idx ? { ...c, lockedAt: center } : c));
    columnsRef = next;
    columns = next;
    flash = "ok";

    const nextActive = idx + 1;
    if (nextActive >= segments) {
      stoppedRef = true;
      const nextStage = stageRef + 1;
      window.setTimeout(() => {
        flash = null;
        if (nextStage >= stages) void endGame(true);
        else startStage(nextStage);
      }, 320);
      return;
    }

    activeRef = nextActive;
    active = nextActive;
    window.setTimeout(() => {
      flash = null;
      lockRef = false;
    }, 140);
  }

  $effect(() => {
    startStage(0);
  });

  $effect(() => {
    let last = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      if (!stoppedRef) {
        timeRef += dt;
        time = timeRef;

        if (duration > 0) {
          const left = Math.max(0, 100 - ((now - stageStartRef) / duration) * 100);
          progress = left;
          if (left <= 0) {
            void endGame(false);
            return;
          }
        }
      } else {
        stageStartRef += dt * 1000;
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef || e.repeat) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }
      if (e.code === "KeyE" || e.code === "Space" || e.code === "Enter") {
        e.preventDefault();
        tryLock();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card datacrack__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Database class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Data Crack</span>
        <span class="mg__subtitle">{subtitle}</span>
      </div>
      {#if duration > 0}
        <div class="mg__timer">
          <div class="mg__timer-track">
            <div class="mg__timer-fill" style="width: {progress}%"></div>
          </div>
          <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
        </div>
      {/if}
    </div>

    <div class="mg__body">
      <div class="datacrack__body">
        <MinigameStages total={stages} done={stage} />

        <button
          type="button"
          aria-label="Data crack board"
          class={[
            "datacrack__board",
            flash === "ok" ? "datacrack__board--ok" : "",
            flash === "bad" ? "datacrack__board--bad" : "",
          ]}
          bind:clientHeight={boardH}
          disabled={finished}
          onclick={tryLock}
        >
          <div
            class="datacrack__line"
            style="top: calc(50% - {lineWidth / 2}px); height: {lineWidth}px"
          ></div>

          <div class="datacrack__columns" style="--cols: {segments}">
            {#each columns as col, i}
              {@const c = gapCenter(col, time)}
              {@const top = c - gap / 2}
              {@const bottom = c + gap / 2}
              {@const status =
                col.lockedAt !== null ? "locked" : i === active ? "active" : "idle"}
              <div class={["datacrack__col", `datacrack__col--${status}`]}>
                <div class="datacrack__bar" style="top: 0; height: {top}%"></div>
                <div class="datacrack__bar" style="top: {bottom}%; bottom: 0"></div>
              </div>
            {/each}
          </div>
        </button>
      </div>
    </div>

    <div class="mg__footer">
      <kbd class="mg__key">E</kbd> / <kbd class="mg__key">Space</kbd> / Click on the line - Esc
    </div>

    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
