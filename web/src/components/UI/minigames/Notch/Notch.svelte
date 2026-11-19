<script lang="ts">
  import { untrack } from "svelte";
  import Crosshair from "@lucide/svelte/icons/crosshair";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { NotchConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Notch.css";

  let { config: configProp }: { config: NotchConfig } = $props();

  const config = untrack(() => configProp);

  function normalizeAngle(deg: number) {
    let a = deg % 360;
    if (a < 0) a += 360;
    return a;
  }

  function angleDelta(a: number, b: number) {
    let d = Math.abs(normalizeAngle(a) - normalizeAngle(b)) % 360;
    if (d > 180) d = 360 - d;
    return d;
  }

  function polar(cx: number, cy: number, r: number, deg: number) {
    const rad = ((deg - 90) * Math.PI) / 180;
    return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
  }

  const angles = (config.angles?.length ? config.angles : [0, 120, 240]).map(
    normalizeAngle
  );
  const speed = Math.max(40, config.speed);
  const tolerance = Math.max(4, config.tolerance);
  const duration = Math.max(5000, config.duration);
  const key = (config.key || "E").slice(0, 1).toUpperCase();
  const keyCode = `Key${key}`;

  let angle = $state(0);
  let hit = $state<boolean[]>(angles.map(() => false));
  let flash = $state<"ok" | "bad" | null>(null);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let stoppedRef = false;
  let angleRef = 0;
  let hitRef = untrack(() => hit);
  let last = performance.now();
  let started = performance.now();
  let lockRef = false;

  $effect(() => {
    hitRef = hit;
  });

  const size = 220;
  const cx = size / 2;
  const cy = size / 2;
  const radius = 88;
  const tip = $derived(polar(cx, cy, radius, angle));
  const hitCount = $derived(hit.filter(Boolean).length);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function nearestPending(needle: number) {
    let best = -1;
    let bestDist = Infinity;
    for (let i = 0; i < angles.length; i++) {
      if (hitRef[i]) continue;
      const d = angleDelta(needle, angles[i]);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return { index: best, dist: bestDist };
  }

  function tryPress() {
    if (finishedRef || lockRef) return;
    lockRef = true;

    const { index, dist } = nearestPending(angleRef);
    if (index >= 0 && dist <= tolerance) {
      const next = [...hitRef];
      next[index] = true;
      hitRef = next;
      hit = next;
      flash = "ok";

      const done = next.every(Boolean);
      if (done) stoppedRef = true;
      window.setTimeout(() => {
        flash = null;
        lockRef = false;
        if (done) void endGame(true);
      }, 160);
      return;
    }

    flash = "bad";
    stoppedRef = true;
    window.setTimeout(() => void endGame(false), 220);
  }

  $effect(() => {
    last = performance.now();
    started = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef || stoppedRef) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      const nextAngle = normalizeAngle(angleRef + speed * dt);
      angleRef = nextAngle;
      angle = nextAngle;

      if (now - started >= duration) {
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
      if (e.repeat) return;

      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }

      if (e.code === keyCode || e.key.toUpperCase() === key) {
        e.preventDefault();
        tryPress();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card notch__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Crosshair class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Notch</span>
        <span class="mg__subtitle">{hitCount} / {angles.length}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="notch__panel">
        <svg
          class={[
            "notch__dial",
            flash === "ok" ? "notch__dial--ok" : "",
            flash === "bad" ? "notch__dial--bad" : "",
          ]}
          viewBox="0 0 {size} {size}"
          width="100%"
          height="100%"
          preserveAspectRatio="xMidYMid meet"
          onclick={tryPress}
          onkeydown={(event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              tryPress();
            }
          }}
          role="button"
          tabindex="0"
          aria-label="Notch dial"
        >
          <circle class="notch__ring" {cx} {cy} r={radius} fill="none" />
          <circle class="notch__hub" {cx} {cy} r="4.5" />

          {#each angles as a, i}
            {@const p = polar(cx, cy, radius, a)}
            {@const done = hit[i]}
            {@const active = !done && angleDelta(angle, a) <= tolerance}
            <circle
              class={[
                "notch__dot",
                done ? "notch__dot--done" : "",
                active ? "notch__dot--active" : "",
              ]}
              cx={p.x}
              cy={p.y}
              r={done ? 5 : 6.5}
            />
          {/each}

          <line class="notch__needle" x1={cx} y1={cy} x2={tip.x} y2={tip.y} />
          <circle class="notch__tip" cx={tip.x} cy={tip.y} r="5.5" />
        </svg>
      </div>
    </div>

    <div class="mg__footer">
      Press <kbd class="mg__key">{key}</kbd> at each notch - Esc
    </div>

    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
