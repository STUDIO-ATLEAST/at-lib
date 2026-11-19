<script lang="ts">
  import { untrack } from "svelte";
  import Layers from "@lucide/svelte/icons/layers";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { StackerConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import MinigameStages from "../../../MinigameStages.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Stacker.css";

  let { config: configProp }: { config: StackerConfig } = $props();

  const config = untrack(() => configProp);

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  const stages = clamp(Math.floor(config.stages || 1), 1, 5);
  const rowsToGoal = clamp(Math.floor(config.rowsToGoal || 6), 2, 14);
  const startWidth = clamp(config.startWidthPercent || 40, 10, 90);
  const baseSpeed = clamp(config.segmentSpeed || 60, 15, 250);
  const speedUp = config.speedUpEachRow === true;
  const duration = Math.max(0, config.duration || 0);

  // Top 12% of the board is headroom above the goal line.
  const rowH = 88 / (rowsToGoal + 1);
  const goalTop = 100 - (rowsToGoal + 1) * rowH;

  type Block = { x: number; w: number };

  let stage = $state(0);
  let placed = $state<Block[]>([]);
  let moving = $state<Block>({ x: 0, w: startWidth });
  let chip = $state<Block | null>(null);
  let flash = $state<"ok" | "bad" | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let stoppedRef = false;
  let placedRef: Block[] = [];
  let movingRef: Block = { x: 0, w: startWidth };
  let dirRef = 1;
  let speedRef = baseSpeed;
  let stageRef = 0;
  let stageStartRef = performance.now();

  const rowsPlaced = $derived(Math.max(0, placed.length - 1));
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const subtitle = $derived(
    result !== null ? (result ? "Stacked" : "Failed") : `${rowsPlaced}/${rowsToGoal}`
  );

  function rowBottom(index: number) {
    return index * rowH;
  }

  function startStage(stageIndex: number) {
    const base = { x: (100 - startWidth) / 2, w: startWidth };
    placedRef = [base];
    placed = placedRef;
    const startLeft = stageIndex % 2 === 0;
    movingRef = { x: startLeft ? 0 : 100 - startWidth, w: startWidth };
    moving = movingRef;
    dirRef = startLeft ? 1 : -1;
    speedRef = baseSpeed;
    chip = null;
    stageRef = stageIndex;
    stage = stageIndex;
    stageStartRef = performance.now();
    progress = 100;
    stoppedRef = false;
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    stoppedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function drop() {
    if (finishedRef || stoppedRef) return;
    const top = placedRef[placedRef.length - 1];
    const m = movingRef;
    const left = Math.max(m.x, top.x);
    const right = Math.min(m.x + m.w, top.x + top.w);
    const overlap = right - left;

    if (overlap <= 0.5) {
      flash = "bad";
      stoppedRef = true;
      window.setTimeout(() => void endGame(false), 260);
      return;
    }

    const kept = { x: left, w: overlap };
    const trimmed =
      m.x < top.x
        ? { x: m.x, w: top.x - m.x }
        : m.x + m.w > top.x + top.w
          ? { x: top.x + top.w, w: m.x + m.w - (top.x + top.w) }
          : null;

    placedRef = [...placedRef, kept];
    placed = placedRef;
    chip = trimmed && trimmed.w > 0.3 ? trimmed : null;
    flash = "ok";
    window.setTimeout(() => {
      flash = null;
      chip = null;
    }, 260);

    if (placedRef.length - 1 >= rowsToGoal) {
      stoppedRef = true;
      const nextStage = stageRef + 1;
      window.setTimeout(() => {
        if (nextStage >= stages) void endGame(true);
        else startStage(nextStage);
      }, 380);
      return;
    }

    if (speedUp) speedRef = Math.min(250, speedRef * 1.1);
    const startLeft = placedRef.length % 2 === 0;
    movingRef = { x: startLeft ? 0 : 100 - kept.w, w: kept.w };
    moving = movingRef;
    dirRef = startLeft ? 1 : -1;
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

      if (stoppedRef) {
        stageStartRef += dt * 1000;
      } else {
        const m = movingRef;
        let x = m.x + dirRef * speedRef * dt;
        if (x + m.w >= 100) {
          x = 100 - m.w;
          dirRef = -1;
        } else if (x <= 0) {
          x = 0;
          dirRef = 1;
        }
        movingRef = { x, w: m.w };
        moving = movingRef;

        if (duration > 0) {
          const left = Math.max(0, 100 - ((now - stageStartRef) / duration) * 100);
          progress = left;
          if (left <= 0) {
            void endGame(false);
            return;
          }
        }
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
      if (e.code === "Space" || e.code === "Enter" || e.code === "KeyE") {
        e.preventDefault();
        drop();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card stacker__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Layers class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Stacker</span>
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
      <div class="stacker__body">
        <MinigameStages total={stages} done={stage} />

        <button
          type="button"
          aria-label="Stacker board"
          class={[
            "stacker__board",
            flash === "ok" ? "stacker__board--ok" : "",
            flash === "bad" ? "stacker__board--bad" : "",
          ]}
          disabled={finished}
          onclick={drop}
        >
          <div class="stacker__goal" style="top: {goalTop}%"></div>

          {#each placed as block, i}
            <div
              class={["stacker__block", i === 0 ? "stacker__block--base" : ""]}
              style="left: {block.x}%; width: {block.w}%; bottom: {rowBottom(i)}%; height: {rowH}%"
            ></div>
          {/each}

          {#if chip}
            <div
              class="stacker__block stacker__block--chip"
              style="left: {chip.x}%; width: {chip.w}%; bottom: {rowBottom(placed.length - 1)}%; height: {rowH}%"
            ></div>
          {/if}

          {#if !finished && placed.length - 1 < rowsToGoal}
            <div
              class="stacker__block stacker__block--moving"
              style="left: {moving.x}%; width: {moving.w}%; bottom: {rowBottom(placed.length)}%; height: {rowH}%"
            ></div>
          {/if}
        </button>
      </div>
    </div>

    <div class="mg__footer">
      <kbd class="mg__key">Space</kbd> / <kbd class="mg__key">Enter</kbd> / Click to drop - Esc
    </div>

    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
