<script lang="ts">
  import { untrack } from "svelte";
  import Lock from "@lucide/svelte/icons/lock";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { LockpickConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Lockpick.css";

  let { config: configProp }: { config: LockpickConfig } = $props();

  const config = untrack(() => configProp);

  type Phase = "sequence" | "spin";

  type ActiveNode = {
    n: number;
    x: number;
    y: number;
    born: number;
  };

  const UNLOCK_ANGLE = 180;

  function normalize(deg: number) {
    let d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }

  function angleDiff(a: number, b: number) {
    const d = Math.abs(normalize(a) - normalize(b));
    return Math.min(d, 360 - d);
  }

  function randomPos(prev?: { x: number; y: number } | null) {
    // Keep clear of the center square lock.
    for (let i = 0; i < 40; i++) {
      const x = 12 + Math.random() * 76;
      const y = 12 + Math.random() * 76;
      const nearCenter = x > 34 && x < 66 && y > 34 && y < 66;
      const nearPrev = prev != null && Math.hypot(x - prev.x, y - prev.y) < 18;
      if (!nearCenter && !nearPrev) return { x, y };
    }
    return { x: 18, y: 22 };
  }

  const nodeCount = $derived(Math.min(8, Math.max(3, config.nodes)));
  const tolerance = $derived(Math.max(4, config.spinTolerance));
  const nodeLifetime = $derived(Math.max(600, config.nodeLifetime ?? 1600));
  const duration = $derived(Math.max(10000, config.duration));

  let phase = $state<Phase>("sequence");
  let nextNeeded = $state(1);
  let activeNode = $state<ActiveNode | null>(null);
  let nodeProgress = $state(0);
  // Bumped every time a new node spawns - the node-timeout effect below depends on this
  // plain primitive instead of the reactive `phase`/`activeNode`/`finished` state it used to
  // read directly, which made it re-run on every one of their writes (including its own
  // tick() writing state that could feed back in) - the actual effect_update_depth_exceeded
  // loop players were hitting.
  let nodeVersion = $state(0);
  let wrongFlash = $state(false);
  let angle = $state(0);
  let dragging = $state(false);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let phaseRef: Phase = "sequence";
  let angleRef = 0;
  let dragRef = false;
  let lastPointerRef: { x: number; y: number } | null = null;
  let boardEl: HTMLDivElement | null = null;
  let startRef = performance.now();
  let activeRef: ActiveNode | null = null;
  let nextNeededRef = 1;

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const aligned = $derived(angleDiff(angle, UNLOCK_ANGLE) <= tolerance);
  const subtitle = $derived(
    phase === "sequence" ? `Hit ${nextNeeded}` : aligned ? "Unlocked" : "Turn 180°"
  );
  const footer = $derived(
    phase === "sequence"
      ? `Tap numbers before they fade - Esc`
      : `Drag to 180°, then E / Space - Esc`
  );

  function spawnNode(n: number, prevPos?: { x: number; y: number } | null) {
    const pos = randomPos(prevPos);
    const node: ActiveNode = {
      n,
      x: pos.x,
      y: pos.y,
      born: performance.now(),
    };
    activeRef = node;
    nextNeededRef = n;
    nextNeeded = n;
    activeNode = node;
    nodeProgress = 0;
    nodeVersion = untrack(() => nodeVersion) + 1;
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    activeNode = null;
    activeRef = null;
    await finishMinigame(success, (ok) => (result = ok));
  }

  $effect(() => {
    void nodeCount;
    void nodeLifetime;
    void duration;
    phase = "sequence";
    phaseRef = "sequence";
    nextNeededRef = 1;
    nextNeeded = 1;
    wrongFlash = false;
    angle = 0;
    angleRef = 0;
    dragging = false;
    dragRef = false;
    finished = false;
    result = null;
    finishedRef = false;
    startRef = performance.now();
    progress = 100;
    spawnNode(1, null);
  });

  $effect(() => {
    void nodeVersion;
    if (phaseRef !== "sequence" || !activeRef || finishedRef) return;

    const lifetime = nodeLifetime;
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef || phaseRef !== "sequence") return;
      const node = activeRef;
      if (!node) return;

      const t = Math.min(1, (now - node.born) / lifetime);
      nodeProgress = t;
      if (t >= 1) {
        void endGame(false);
        return;
      }
      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  function onNodeClick() {
    if (finishedRef || phaseRef !== "sequence") return;
    const node = activeRef;
    if (!node) return;

    const n = node.n;
    if (n !== nextNeededRef) {
      wrongFlash = true;
      window.setTimeout(() => (wrongFlash = false), 220);
      void endGame(false);
      return;
    }

    if (n >= nodeCount) {
      activeNode = null;
      activeRef = null;
      phase = "spin";
      phaseRef = "spin";
      return;
    }

    spawnNode(n + 1, node);
  }

  function onDialPointerDown(e: PointerEvent) {
    if (finishedRef || phaseRef !== "spin") return;
    e.preventDefault();
    (e.currentTarget as Element).setPointerCapture?.(e.pointerId);
    dragRef = true;
    dragging = true;
    lastPointerRef = { x: e.clientX, y: e.clientY };
  }

  function onDialPointerMove(e: PointerEvent) {
    if (!dragRef || finishedRef) return;
    const prev = lastPointerRef;
    if (!prev) return;

    const el = boardEl;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;

    const a0 = Math.atan2(prev.y - cy, prev.x - cx);
    const a1 = Math.atan2(e.clientY - cy, e.clientX - cx);
    let delta = ((a1 - a0) * 180) / Math.PI;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    const next = normalize(angleRef + delta);
    angleRef = next;
    angle = next;
    lastPointerRef = { x: e.clientX, y: e.clientY };
  }

  function onDialPointerUp() {
    dragRef = false;
    dragging = false;
    lastPointerRef = null;
  }

  function tryUnlock() {
    if (finishedRef || phaseRef !== "spin") return;
    if (angleDiff(angleRef, UNLOCK_ANGLE) <= tolerance) {
      void endGame(true);
    } else {
      wrongFlash = true;
      window.setTimeout(() => (wrongFlash = false), 220);
    }
  }

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }
      if (
        phaseRef === "spin" &&
        (e.code === "Space" || e.code === "Enter" || e.code === "KeyE")
      ) {
        e.preventDefault();
        tryUnlock();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  $effect(() => {
    void nodeCount;
    void nodeLifetime;
    void duration;
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
  <div class="mg__card lockpick__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Lock class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Lockpick</span>
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
      <div
        bind:this={boardEl}
        class={["lockpick__board", wrongFlash ? "lockpick__board--wrong" : ""]}
      >
        <div
          role="presentation"
          class={[
            "lockpick__hub",
            phase === "spin" ? "lockpick__hub--active" : "",
            aligned ? "lockpick__hub--aligned" : "",
            dragging ? "lockpick__hub--drag" : "",
          ]}
          style="transform: translate(-50%, -50%) rotate({phase === "spin"
            ? angle
            : 0}deg)"
          onpointerdown={phase === "spin" ? onDialPointerDown : undefined}
          onpointermove={phase === "spin" ? onDialPointerMove : undefined}
          onpointerup={phase === "spin" ? onDialPointerUp : undefined}
          onpointerleave={phase === "spin" ? onDialPointerUp : undefined}
          ondblclick={phase === "spin" ? tryUnlock : undefined}
        >
          <Lock style={iconSize(2.6)} strokeWidth={1.75} class="lockpick__lock" />
          <span class="lockpick__progress">
            {phase === "sequence"
              ? `${Math.max(0, (activeNode?.n ?? 1) - 1)} / ${nodeCount}`
              : "180°"}
          </span>
          {#if phase === "spin"}
            <span class="lockpick__notch" aria-hidden="true"></span>
          {/if}
        </div>

        {#if phase === "sequence" && activeNode && !finished}
          <button
            type="button"
            class={[
              "lockpick__node",
              wrongFlash ? "lockpick__node--wrong" : "",
            ]}
            style="left: {activeNode.x}%; top: {activeNode.y}%; --lp-progress: {nodeProgress}; --lp-opacity: {Math.max(
              0.15,
              1 - nodeProgress * 0.85
            )}; --lp-scale: {1.25 - nodeProgress * 0.25}"
            onclick={onNodeClick}
          >
            {activeNode.n}
          </button>
        {/if}
      </div>
    </div>

    <div class="mg__footer">{footer}</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
