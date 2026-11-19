<script lang="ts">
  import { untrack } from "svelte";
  import Route from "@lucide/svelte/icons/route";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { PathingConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Pathing.css";

  let { config: configProp }: { config: PathingConfig } = $props();

  const config = untrack(() => configProp);

  type Dot = {
    id: number;
    x: number;
    y: number;
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

  function dist(a: { x: number; y: number }, b: { x: number; y: number }) {
    return Math.hypot(a.x - b.x, a.y - b.y);
  }

  function generateDots(count: number, seed: number): Dot[] {
    const rand = mulberry32(seed);
    const dots: Dot[] = [];
    const start = { x: 8, y: 20 };
    let tries = 0;
    while (dots.length < count && tries < 200) {
      tries += 1;
      const x = 16 + rand() * 70;
      const y = 12 + rand() * 76;
      const tooClose =
        Math.hypot(start.x - x, start.y - y) < 16 ||
        dots.some((d) => Math.hypot(d.x - x, d.y - y) < 12);
      if (tooClose) continue;
      dots.push({ id: dots.length, x, y });
    }
    while (dots.length < count) {
      dots.push({
        id: dots.length,
        x: 18 + (dots.length % 4) * 18,
        y: 22 + Math.floor(dots.length / 4) * 22,
      });
    }
    return dots;
  }

  function closestUnconnected(
    from: { x: number; y: number },
    list: Dot[],
    connectedSet: Set<number>
  ): number {
    let bestId = -1;
    let best = Infinity;
    for (const d of list) {
      if (connectedSet.has(d.id)) continue;
      const dd = dist(from, d);
      if (dd < best) {
        best = dd;
        bestId = d.id;
      }
    }
    return bestId;
  }

  const stages = $derived(Math.min(5, Math.max(1, config.stages)));
  const dotCount = $derived(Math.min(12, Math.max(4, config.dots)));
  const duration = $derived(Math.max(5000, config.duration));
  const baseSeed = $derived(config.seed ?? 1);
  const entry = { x: 8, y: 20 };

  let stage = $state(0);
  let dots = $state<Dot[]>([]);
  let path = $state<number[]>([]);
  let cursor = $state<{ x: number; y: number } | null>(null);
  let wrongId = $state<number | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);
  let boardEl: HTMLDivElement | undefined;

  let finishedRef = false;
  let pathRef: number[] = [];
  let dotsRef: Dot[] = [];
  let stageRef = 0;
  let startRef = performance.now();

  const connected = $derived(new Set(path));
  const tip = $derived.by(() => {
    if (path.length === 0) return entry;
    const last = dots.find((d) => d.id === path[path.length - 1]);
    return last ? { x: last.x, y: last.y } : entry;
  });
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const solidPath = $derived.by(() => {
    const pts: { x: number; y: number }[] = [entry];
    for (const id of path) {
      const d = dots.find((p) => p.id === id);
      if (d) pts.push({ x: d.x, y: d.y });
    }
    if (pts.length < 2) return "";
    return pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ");
  });
  const dragPath = $derived(
    !cursor || finished ? "" : `M ${tip.x} ${tip.y} L ${cursor.x} ${cursor.y}`
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    cursor = null;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function startStage(stageIndex: number) {
    const nextDots = generateDots(dotCount, baseSeed + stageIndex * 7919 + 13);
    dots = nextDots;
    dotsRef = nextDots;
    path = [];
    pathRef = [];
    cursor = null;
    wrongId = null;
    stage = stageIndex;
    stageRef = stageIndex;
    startRef = performance.now();
    progress = 100;
  }

  function pointerToPct(clientX: number, clientY: number) {
    const el = boardEl;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return null;
    return {
      x: ((clientX - rect.left) / rect.width) * 100,
      y: ((clientY - rect.top) / rect.height) * 100,
    };
  }

  function onBoardPointerMove(e: PointerEvent) {
    if (finishedRef) return;
    const pct = pointerToPct(e.clientX, e.clientY);
    if (pct) cursor = pct;
  }

  function onBoardPointerLeave() {
    cursor = null;
  }

  function onDotClick(id: number) {
    if (finishedRef) return;
    const list = dotsRef;
    const connectedSet = new Set(pathRef);
    if (connectedSet.has(id)) return;

    const from =
      pathRef.length === 0
        ? entry
        : list.find((d) => d.id === pathRef[pathRef.length - 1])!;

    const expected = closestUnconnected(from, list, connectedSet);
    if (id !== expected) {
      wrongId = id;
      window.setTimeout(() => (wrongId = null), 220);
      void endGame(false);
      return;
    }

    const nextPath = [...pathRef, id];
    pathRef = nextPath;
    path = nextPath;

    if (nextPath.length >= list.length) {
      const nextStage = stageRef + 1;
      if (nextStage >= stages) {
        window.setTimeout(() => void endGame(true), 220);
      } else {
        window.setTimeout(() => startStage(nextStage), 280);
      }
    }
  }

  $effect(() => {
    stages;
    duration;
    dotCount;
    baseSeed;
    finishedRef = false;
    finished = false;
    result = null;
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
        ? "Linked"
        : "Failed"
      : `Stage ${stage + 1}/${stages}`
  );
</script>

<div class="mg">
  <div class="mg__card pathing__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Route class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Pathing</span>
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
      <div class="pathing__body">
        <div
          bind:this={boardEl}
          role="presentation"
          class={["pathing__board", wrongId != null ? "pathing__board--wrong" : ""]}
          onpointermove={onBoardPointerMove}
          onpointerleave={onBoardPointerLeave}
        >
          <div class="pathing__grid"></div>
          <svg
            class="pathing__svg"
            viewBox="0 0 100 100"
            preserveAspectRatio="none"
            aria-hidden="true"
          >
            {#if solidPath}
              <path
                class="pathing__line"
                d={solidPath}
                vector-effect="non-scaling-stroke"
              />
            {/if}
            {#if dragPath}
              <path
                class="pathing__line pathing__line--drag"
                d={dragPath}
                vector-effect="non-scaling-stroke"
              />
            {/if}
          </svg>

          <div
            class={["pathing__start", path.length === 0 ? "pathing__start--active" : ""]}
            style="left: {entry.x}%; top: {entry.y}%"
            aria-label="Start"
          ></div>

          {#each dots as dot (dot.id)}
            {@const done = connected.has(dot.id)}
            {@const isCurrent = path.length > 0 && path[path.length - 1] === dot.id}
            {@const wrong = wrongId === dot.id}
            <button
              type="button"
              aria-label={`Dot ${dot.id}`}
              class={[
                "pathing__dot",
                done ? "pathing__dot--done" : "",
                isCurrent ? "pathing__dot--current" : "",
                wrong ? "pathing__dot--wrong" : "",
              ]}
              style="left: {dot.x}%; top: {dot.y}%"
              disabled={finished || done}
              onclick={() => onDotClick(dot.id)}
            ></button>
          {/each}
        </div>

        <div class="pathing__meta">
          <span>
            Linked <strong>{path.length}/{dots.length}</strong>
          </span>
          <span>Always the <strong>closest</strong></span>
        </div>
      </div>
    </div>

    <div class="mg__footer">Drag from the start - click nearest dots - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
