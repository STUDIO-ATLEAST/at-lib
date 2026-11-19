<script lang="ts">
  import { untrack } from "svelte";
  import KeyRound from "@lucide/svelte/icons/key-round";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { CircleLockConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./CircleLock.css";

  let { config: configProp }: { config: CircleLockConfig } = $props();

  const config = untrack(() => configProp);

  const SIZE = 100;
  const CX = 50;
  const CY = 50;
  const R = 38;
  const NEEDLE_SPAN = 10; // degrees

  function degToRad(d: number) {
    return ((d - 90) * Math.PI) / 180;
  }

  function polar(deg: number, radius = R) {
    const a = degToRad(deg);
    return { x: CX + Math.cos(a) * radius, y: CY + Math.sin(a) * radius };
  }

  function describeArc(startDeg: number, span: number, radius = R): string {
    const end = startDeg + span;
    const s = polar(startDeg, radius);
    const e = polar(end, radius);
    const large = span > 180 ? 1 : 0;
    return `M ${s.x} ${s.y} A ${radius} ${radius} 0 ${large} 1 ${e.x} ${e.y}`;
  }

  function normalize(deg: number) {
    let d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }

  function overlaps(n: number, zoneStartDeg: number, zSize: number, needleSpan: number) {
    const n0 = normalize(n);
    const n1 = normalize(n + needleSpan);
    const z0 = normalize(zoneStartDeg);
    const z1 = normalize(zoneStartDeg + zSize);

    const inRange = (a: number, b: number, x: number) => {
      if (a <= b) return x >= a && x <= b;
      return x >= a || x <= b;
    };

    // Any overlap between needle span and zone span
    const samples = 8;
    for (let i = 0; i <= samples; i++) {
      const t = n0 + ((n1 - n0 + (n1 < n0 ? 360 : 0)) * i) / samples;
      if (inRange(z0, z1, normalize(t))) return true;
    }
    for (let i = 0; i <= samples; i++) {
      const t = z0 + ((z1 - z0 + (z1 < z0 ? 360 : 0)) * i) / samples;
      if (inRange(n0, n1, normalize(t))) return true;
    }
    return false;
  }

  function randomZone(zSize: number, avoid?: number) {
    for (let i = 0; i < 12; i++) {
      const start = Math.random() * 360;
      if (avoid == null) return start;
      const dist = Math.min(
        Math.abs(normalize(start) - normalize(avoid)),
        360 - Math.abs(normalize(start) - normalize(avoid))
      );
      if (dist > zSize + 40) return start;
    }
    return Math.random() * 360;
  }

  const stagesTotal = $derived(Math.max(1, config.stages));
  const zoneSize = $derived(Math.max(12, config.zoneSize));
  const speed = $derived(Math.max(60, config.speed));
  const maxLives = $derived(Math.max(1, config.lives));
  // 0 = no overall timer (default): lives end the game
  const duration = $derived((config.duration ?? 0) > 0 ? Math.max(8000, config.duration) : 0);

  const startZone = randomZone(Math.max(12, config.zoneSize));
  let stagesLeft = $state(Math.max(1, config.stages));
  let livesLeft = $state(Math.max(1, config.lives));
  let zoneStart = $state(startZone);
  let needle = $state(0);
  let flash = $state<"hit" | "miss" | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let stoppedRef = false;
  let needleRef = 0;
  let zoneRef = startZone;
  let stagesRef = Math.max(1, config.stages);
  let livesRef = Math.max(1, config.lives);
  let dirRef = 1;
  let startRef = performance.now();
  let lastRef = performance.now();
  let lockInputRef = false;

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const ringPath = describeArc(0, 359.9);
  const zonePath = $derived(describeArc(zoneStart, zoneSize));
  const needlePath = $derived(describeArc(needle, NEEDLE_SPAN));

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  $effect(() => {
    stagesLeft = stagesTotal;
    livesLeft = maxLives;
    stagesRef = stagesTotal;
    livesRef = maxLives;
    const z = randomZone(zoneSize);
    zoneStart = z;
    zoneRef = z;
    needle = 0;
    needleRef = 0;
    dirRef = 1;
    flash = null;
    finished = false;
    result = null;
    finishedRef = false;
    stoppedRef = false;
    lockInputRef = false;
    startRef = performance.now();
    lastRef = performance.now();
    progress = 100;
    void speed;
    void duration;
    void config.duration;
  });

  $effect(() => {
    void speed;
    void duration;
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef || stoppedRef) return;
      const dt = Math.min(0.05, (now - lastRef) / 1000);
      lastRef = now;

      needleRef = normalize(needleRef + dirRef * speed * dt);
      needle = needleRef;

      if (duration > 0) {
        const left = Math.max(0, 100 - ((now - startRef) / duration) * 100);
        progress = left;
        if (left <= 0) {
          void endGame(false);
          return;
        }
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  function tryLock() {
    if (finishedRef || lockInputRef) return;
    lockInputRef = true;

    const hit = overlaps(needleRef, zoneRef, zoneSize, NEEDLE_SPAN);

    if (hit) {
      const left = stagesRef - 1;
      stagesRef = left;
      stagesLeft = left;

      // Final pick only - flash zone green, then succeed.
      if (left <= 0) {
        flash = "hit";
        stoppedRef = true;
        window.setTimeout(() => void endGame(true), 280);
        return;
      }

      // Mid picks: no green flash, just jump to the next zone.
      flash = null;
      const nextZone = randomZone(zoneSize, zoneRef);
      zoneRef = nextZone;
      zoneStart = nextZone;
      if (Math.random() < 0.55) dirRef *= -1;
      lockInputRef = false;
      return;
    }

    // Miss - zone turns red briefly.
    flash = "miss";
    const lives = livesRef - 1;
    livesRef = lives;
    livesLeft = lives;

    if (lives <= 0) {
      stoppedRef = true;
      window.setTimeout(() => void endGame(false), 280);
      return;
    }

    window.setTimeout(() => {
      flash = null;
      lockInputRef = false;
    }, 280);
  }

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }
      if (e.code === "Space" || e.code === "KeyE") {
        e.preventDefault();
        e.stopPropagation();
        tryLock();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card circlelock__card">
    <div class="mg__header">
      <div class="mg__heading">
        <KeyRound class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Lockpick</span>
        <span class="mg__subtitle">{stagesLeft} left</span>
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
      <div
        class={[
          "circlelock__stage",
          flash === "hit" ? "circlelock__stage--hit" : "",
          flash === "miss" ? "circlelock__stage--miss" : "",
        ]}
        role="img"
        aria-label="Lockpick circle - press E or Space when the needle hits the zone"
      >
        <svg class="circlelock__svg" viewBox="0 0 {SIZE} {SIZE}">
          <circle class="circlelock__core" cx={CX} cy={CY} r="22" />
          <path class="circlelock__track" d={ringPath} fill="none" />
          <path class="circlelock__zone" d={zonePath} fill="none" />
          <path class="circlelock__needle" d={needlePath} fill="none" />
          <text
            class="circlelock__count"
            x={CX}
            y={CY}
            text-anchor="middle"
            dominant-baseline="central"
          >
            {stagesLeft}
          </text>
        </svg>
      </div>

      {#if maxLives > 1}
        <div class="circlelock__lives" aria-label="{livesLeft} lives">
          {#each { length: maxLives } as _, i}
            <span
              class={`circlelock__life${i < livesLeft ? "" : " circlelock__life--lost"}`}
            ></span>
          {/each}
        </div>
      {/if}
    </div>

    <div class="mg__footer">
      Press E or Space when the needle hits the zone - Esc to cancel
    </div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
