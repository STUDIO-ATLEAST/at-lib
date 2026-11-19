<script lang="ts">
  import { untrack } from "svelte";
  import DrillIcon from "@lucide/svelte/icons/drill";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { DrillConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Drill.css";

  let { config: configProp }: { config: DrillConfig } = $props();

  const config = untrack(() => configProp);

  type DrillColor = "red" | "white" | "blue" | "green";

  type Wave = {
    lanes: DrillColor[];
    target: DrillColor;
  };

  const COLORS: DrillColor[] = ["red", "white", "blue", "green"];
  const COLOR_HEX: Record<DrillColor, string> = {
    red: "#ff8787",
    white: "#f1f3f5",
    blue: "#4dabf7",
    green: "#69db7c",
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

  function shuffleColors(rand: () => number): DrillColor[] {
    const arr = [...COLORS];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      const tmp = arr[i]!;
      arr[i] = arr[j]!;
      arr[j] = tmp;
    }
    return arr;
  }

  function pad2(n: number) {
    return String(n).padStart(2, "0");
  }

  function makeWave(rand: () => number): Wave {
    const lanes = shuffleColors(rand);
    return { lanes, target: lanes[Math.floor(rand() * 4)]! };
  }

  const hitsRequired = $derived(Math.min(20, Math.max(3, config.hitsRequired || 9)));
  const fallMs = $derived(Math.max(900, config.fallMs || 2400));
  // 0 = no overall timer (default): every bar already has its own fall time
  const duration = $derived((config.duration ?? 0) > 0 ? Math.max(8000, config.duration) : 0);
  const baseSeed = $derived(config.seed ?? 1);

  let rand = mulberry32(untrack(() => baseSeed));
  let hits = $state(0);
  let lane = $state(1);
  let wave = $state<Wave>(makeWave(rand));
  let barY = $state(0);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let flash = $state<"ok" | "bad" | null>(null);
  let runId = $state(0);

  let laneRef = untrack(() => lane);
  let waveRef = untrack(() => wave);
  let hitsRef = 0;
  let finishedRef = false;
  let judgingRef = false;
  let started = performance.now();
  let waveStarted = performance.now();

  $effect(() => {
    laneRef = lane;
  });

  $effect(() => {
    waveRef = wave;
  });

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const bitColor = $derived(COLOR_HEX[wave.target]);
  const subtitle = $derived(
    result !== null
      ? result
        ? "Cleared"
        : "Failed"
      : `${pad2(hits)} / ${pad2(hitsRequired)}`
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function nextWave() {
    const next = makeWave(rand);
    waveRef = next;
    wave = next;
    barY = 0;
    waveStarted = performance.now();
    judgingRef = false;
  }

  $effect(() => {
    const seed = baseSeed;
    void fallMs;
    void hitsRequired;
    void duration;

    untrack(() => {
      finishedRef = false;
      judgingRef = false;
      hitsRef = 0;
      hits = 0;
      finished = false;
      result = null;
      flash = null;
      lane = 1;
      laneRef = 1;
      rand = mulberry32(seed);
      started = performance.now();
      progress = 100;
      nextWave();
      runId = untrack(() => runId) + 1;
    });
  });

  $effect(() => {
    const dur = duration;
    void runId;
    started = performance.now();
    progress = 100;
    if (dur <= 0) return;
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const left = Math.max(0, 100 - ((now - started) / dur) * 100);
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
    const fall = fallMs;
    const need = hitsRequired;
    void runId;
    const currentWave = wave;
    waveStarted = performance.now();
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const t = Math.min(1, (now - waveStarted) / fall);
      barY = t * 100;
      if (t >= 1 && !judgingRef) {
        judgingRef = true;
        const under = currentWave.lanes[laneRef];
        if (under === currentWave.target) {
          const nextHits = hitsRef + 1;
          hitsRef = nextHits;
          hits = nextHits;
          flash = "ok";
          window.setTimeout(() => (flash = null), 180);
          if (nextHits >= need) {
            void endGame(true);
            return;
          }
          window.setTimeout(() => nextWave(), 120);
        } else {
          flash = "bad";
          void endGame(false);
          return;
        }
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
      if (e.code === "ArrowLeft" || e.code === "KeyA") {
        e.preventDefault();
        const next = Math.max(0, laneRef - 1);
        laneRef = next;
        lane = next;
        return;
      }
      if (e.code === "ArrowRight" || e.code === "KeyD") {
        e.preventDefault();
        const next = Math.min(3, laneRef + 1);
        laneRef = next;
        lane = next;
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card drill__card">
    <div class="mg__header">
      <div class="mg__heading">
        <DrillIcon class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Drill</span>
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
      <div class="drill__body">
        <div
          class={[
            "drill__board",
            flash === "ok" ? "drill__board--ok" : "",
            flash === "bad" ? "drill__board--bad" : "",
          ]}
        >
          <div class="drill__lanes">
            {#each wave.lanes as _, i}
              <div
                class={["drill__lane", i === lane ? "drill__lane--active" : ""]}
              >
                {#if i === lane}
                  <div class="drill__bit" style="--bit-color: {bitColor}"></div>
                {/if}
              </div>
            {/each}
          </div>

          <div class="drill__bar-track" aria-hidden="true">
            <div class="drill__bar" style="top: {barY}%">
              {#each wave.lanes as c}
                <div
                  class="drill__segment"
                  style="background: {COLOR_HEX[c]}"
                ></div>
              {/each}
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="mg__footer">Arrow keys or A/D - match bit color - Esc</div>

    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
