<script lang="ts">
  import { untrack } from "svelte";
  import ArrowDown from "@lucide/svelte/icons/arrow-down";
  import ArrowLeft from "@lucide/svelte/icons/arrow-left";
  import ArrowRight from "@lucide/svelte/icons/arrow-right";
  import ArrowUp from "@lucide/svelte/icons/arrow-up";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { ArrowsConfig } from "../../../../types/minigame";
  import "../minigame-shell.scss";

  let { config: configProp }: { config: ArrowsConfig } = $props();

  const config = untrack(() => configProp);

  type Dir = "up" | "down" | "left" | "right";

  const DIRS: Dir[] = ["up", "down", "left", "right"];

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

  function normalizeDir(raw: string): Dir {
    const v = raw.toLowerCase();
    if (v === "w" || v === "up") return "up";
    if (v === "s" || v === "down") return "down";
    if (v === "a" || v === "left") return "left";
    if (v === "d" || v === "right") return "right";
    return "up";
  }

  function buildSequence(len: number, seed: number): Dir[] {
    const rand = mulberry32(seed);
    return Array.from({ length: len }, () => DIRS[Math.floor(rand() * DIRS.length)]!);
  }

  function codeToDir(code: string): Dir | null {
    if (code === "ArrowUp" || code === "KeyW") return "up";
    if (code === "ArrowDown" || code === "KeyS") return "down";
    if (code === "ArrowLeft" || code === "KeyA") return "left";
    if (code === "ArrowRight" || code === "KeyD") return "right";
    return null;
  }

  const length = $derived(
    Math.min(16, Math.max(3, config.length || config.sequence.length))
  );
  const stages = $derived(Math.min(5, Math.max(1, config.stages ?? 1)));
  const duration = $derived(Math.max(3000, config.duration));
  const baseSeed = $derived(config.seed ?? 1);

  let stage = $state(0);
  let cleared = $state(0);
  let sequence = $state<Dir[]>([]);
  let index = $state(0);
  let wrongId = $state<number | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let indexRef = 0;
  let stageRef = 0;
  let seqRef: Dir[] = [];
  let finishedRef = false;
  let startRef = performance.now();

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function startStage(stageIndex: number) {
    const next =
      stageIndex === 0 && config.sequence?.length
        ? config.sequence.map(normalizeDir).slice(0, length)
        : buildSequence(length, baseSeed + stageIndex * 1337 + 9);
    sequence = next;
    seqRef = next;
    index = 0;
    indexRef = 0;
    wrongId = null;
    stage = stageIndex;
    stageRef = stageIndex;
    startRef = performance.now();
    progress = 100;
  }

  function onDir(dir: Dir) {
    if (finishedRef) return;
    const i = indexRef;
    const expected = seqRef[i];
    if (!expected) return;

    if (dir !== expected) {
      wrongId = i;
      window.setTimeout(() => (wrongId = null), 220);
      void endGame(false);
      return;
    }

    const next = i + 1;
    indexRef = next;
    index = next;

    if (next >= seqRef.length) {
      const nextCleared = stageRef + 1;
      cleared = nextCleared;
      const nextStage = stageRef + 1;
      if (nextStage >= stages) {
        void endGame(true);
      } else {
        window.setTimeout(() => startStage(nextStage), 180);
      }
    }
  }

  $effect(() => {
    length;
    stages;
    duration;
    baseSeed;
    config.sequence;
    finishedRef = false;
    finished = false;
    result = null;
    cleared = 0;
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
        return;
      }
      const dir = codeToDir(e.code);
      if (!dir) return;
      e.preventDefault();
      onDir(dir);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  const subtitle = $derived(
    result !== null
      ? result
        ? "Cleared"
        : "Failed"
      : stages > 1
        ? `Stage ${stage + 1}/${stages}`
        : `${Math.min(index + 1, sequence.length)}/${sequence.length}`
  );
</script>

<div class="mgbar">
  <div
    class={[
      "mgbar__box",
      "mgbar__box--auto",
      result === true ? "mgbar__box--ok" : "",
      result === false ? "mgbar__box--fail" : "",
    ]}
  >
    <div class="mgbar__chips">
      {#each sequence as dir, i}
        {@const current = i === index && !finished}
        {@const done = i < index}
        {@const wrong = wrongId === i}
        <div
          class={[
            "mgbar__chip",
            current ? "mgbar__chip--current" : "",
            done ? "mgbar__chip--done" : "",
            wrong ? "mgbar__chip--wrong" : "",
          ]}
          aria-current={current ? "step" : undefined}
        >
          {#if dir === "up"}
            <ArrowUp strokeWidth={2.4} />
          {:else if dir === "down"}
            <ArrowDown strokeWidth={2.4} />
          {:else if dir === "left"}
            <ArrowLeft strokeWidth={2.4} />
          {:else}
            <ArrowRight strokeWidth={2.4} />
          {/if}
        </div>
      {/each}
    </div>
    <span class="mgbar__count">{subtitle}</span>
    <div class="mgbar__timer">
      <div class="mgbar__timer-fill" style="width: {progress}%"></div>
    </div>
  </div>
</div>
