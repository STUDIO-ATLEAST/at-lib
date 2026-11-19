<script lang="ts">
  import { untrack } from "svelte";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { SmashConfig } from "../../../../types/minigame";
  import "./Smash.css";

  let { config: configProp }: { config: SmashConfig } = $props();

  const config = untrack(() => configProp);

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  const key = (config.key || "E").slice(0, 1).toUpperCase();
  const keyCode = `Key${key}`;
  const gain = Math.max(2, config.gain);
  const decay = Math.max(0, config.decay);
  const duration = Math.max(4000, config.duration);
  const startFill = clamp(config.start ?? 6, 0, 40);

  let fill = $state(startFill);
  let timeLeft = $state(100);
  let pulse = $state(false);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let fillRef = startFill;
  let last = performance.now();
  let started = performance.now();
  let pulseTimer = 0;

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function bump() {
    if (finishedRef) return;
    const next = clamp(fillRef + gain, 0, 100);
    fillRef = next;
    fill = next;
    pulse = true;
    window.clearTimeout(pulseTimer);
    pulseTimer = window.setTimeout(() => (pulse = false), 80);
    if (next >= 100) {
      window.setTimeout(() => void endGame(true), 120);
    }
  }

  $effect(() => {
    last = performance.now();
    started = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      if (decay > 0 && fillRef < 100) {
        const next = clamp(fillRef - decay * dt, 0, 100);
        fillRef = next;
        fill = next;
      }

      timeLeft = Math.max(0, 100 - ((now - started) / duration) * 100);

      if (now - started >= duration) {
        void endGame(false);
        return;
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(pulseTimer);
    };
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
        bump();
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
      result === true ? "mgbar__box--ok" : "",
      result === false ? "mgbar__box--fail" : "",
    ]}
  >
    <kbd class={["mgbar__key", pulse ? "smash__key--pulse" : ""]}>{key}</kbd>
    <button
      type="button"
      class="mgbar__track"
      disabled={finished}
      onclick={bump}
      aria-label="Mash {key}"
    >
      <div class="mgbar__rail smash__rail">
        <div class="smash__fill" style="width: {fill}%"></div>
      </div>
    </button>
    <span class="mgbar__count">
      {result !== null ? (result ? "Success" : "Failed") : `${Math.floor(fill)}%`}
    </span>
    <div class="mgbar__timer">
      <div class="mgbar__timer-fill" style="width: {timeLeft}%"></div>
    </div>
  </div>
</div>
