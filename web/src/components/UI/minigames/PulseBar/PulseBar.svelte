<script lang="ts">
  import { untrack } from "svelte";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { PulseBarConfig } from "../../../../types/minigame";
  import "../minigame-shell.scss";

  let { config: configProp }: { config: PulseBarConfig } = $props();

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

  const speed = clamp(config.segmentSpeed || 45, 10, 200);
  const zoneSize = clamp(config.targetZoneSize || 12, 4, 30);
  const count = clamp(Math.floor(config.numberOfSegments || 4), 1, 15);
  const seed = config.seed ?? Math.floor(Math.random() * 2147483646) + 1;

  const segW = 1.6;
  const zoneEnd = 96;
  const zoneStart = zoneEnd - zoneSize;

  type Segment = { x: number; hit: boolean };

  function buildSegments(): Segment[] {
    const rand = mulberry32(seed);
    // Spacing always exceeds the zone so two segments can never share it.
    const minGap = Math.max(zoneSize + segW + 6, 16);
    const maxGap = minGap + 22;
    const list: Segment[] = [];
    let x = -segW - 4;
    for (let i = 0; i < count; i++) {
      list.push({ x, hit: false });
      x -= minGap + rand() * (maxGap - minGap);
    }
    return list;
  }

  let segments = $state<Segment[]>(buildSegments());
  let flash = $state<"ok" | "bad" | null>(null);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let stoppedRef = false;
  let segmentsRef = untrack(() => segments);

  const hits = $derived(segments.filter((s) => s.hit).length);
  const subtitle = $derived(
    result !== null ? (result ? "Success" : "Failed") : `${hits}/${count}`
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    stoppedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function fail() {
    flash = "bad";
    stoppedRef = true;
    window.setTimeout(() => void endGame(false), 240);
  }

  function press() {
    if (finishedRef || stoppedRef) return;
    const idx = segmentsRef.findIndex(
      (s) => !s.hit && s.x + segW >= zoneStart && s.x <= zoneEnd
    );
    if (idx < 0) {
      fail();
      return;
    }

    const next = segmentsRef.map((s, i) => (i === idx ? { ...s, hit: true } : s));
    segmentsRef = next;
    segments = next;
    flash = "ok";

    if (next.every((s) => s.hit)) {
      stoppedRef = true;
      window.setTimeout(() => void endGame(true), 220);
      return;
    }
    window.setTimeout(() => {
      if (flash === "ok") flash = null;
    }, 140);
  }

  $effect(() => {
    let last = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef || stoppedRef) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      const next = segmentsRef.map((s) => ({ ...s, x: s.x + speed * dt }));
      segmentsRef = next;
      segments = next;

      if (next.some((s) => !s.hit && s.x > zoneEnd)) {
        fail();
        return;
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
      if (e.code === "KeyE" || e.code === "Space") {
        e.preventDefault();
        press();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mgbar">
  <div
    class={[
      "mgbar__box",
      result === true || flash === "ok" ? "mgbar__box--ok" : "",
      result === false || flash === "bad" ? "mgbar__box--fail" : "",
    ]}
  >
    <kbd class="mgbar__key">E</kbd>
    <button
      type="button"
      aria-label="Pulse bar"
      class="mgbar__track"
      disabled={finished}
      onclick={press}
    >
      <div class="mgbar__rail"></div>
      <div class="mgbar__zone" style="left: {zoneStart}%; width: {zoneSize}%"></div>
      {#each segments as seg}
        {#if !seg.hit && seg.x > -segW && seg.x < 100}
          <div class="mgbar__pill" style="left: {seg.x}%; width: {segW}%"></div>
        {/if}
      {/each}
    </button>
    <span class="mgbar__count">{subtitle}</span>
  </div>
</div>
