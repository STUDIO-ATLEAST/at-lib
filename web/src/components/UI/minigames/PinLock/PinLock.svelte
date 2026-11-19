<script lang="ts">
  import { untrack } from "svelte";
  import LockKeyhole from "@lucide/svelte/icons/lock-keyhole";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { PinLockConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./PinLock.css";

  let { config: configProp }: { config: PinLockConfig } = $props();

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

  const pinCount = clamp(Math.floor(config.numberOfPins || 5), 2, 8);
  const push = clamp(config.pushStrength || 55, 10, 200);
  const gravity = clamp(config.gravity || 140, 20, 600);
  const tolerance = clamp(config.zoneTolerance || 7, 2, 25);
  const instantFail = config.instantFail === true;
  const maxAttempts = clamp(Math.floor(config.maxAttempts || 3), 1, 10);
  const duration = Math.max(0, config.duration || 0);
  const seed = config.seed ?? Math.floor(Math.random() * 2147483646) + 1;

  // Pin block height as % of its channel; `height` below is the travel position 0-100.
  const PIN_H = 14;

  type Pin = { target: number; height: number; velocity: number; set: boolean };

  function buildPins(): Pin[] {
    const rand = mulberry32(seed);
    return Array.from({ length: pinCount }, () => ({
      target: 25 + rand() * 60,
      height: 0,
      velocity: 0,
      set: false,
    }));
  }

  let pins = $state<Pin[]>(buildPins());
  let active = $state(0);
  let attempts = $state(maxAttempts);
  let flash = $state<"ok" | "bad" | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let pinsRef = untrack(() => pins);
  let activeRef = 0;
  let attemptsRef = maxAttempts;
  let startRef = performance.now();

  const setCount = $derived(pins.filter((p) => p.set).length);
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const subtitle = $derived(
    result !== null ? (result ? "Unlocked" : "Failed") : `${setCount}/${pinCount}`
  );

  function inZone(pin: Pin) {
    return Math.abs(pin.height - pin.target) <= tolerance;
  }

  function pinBottom(height: number) {
    return (height / 100) * (100 - PIN_H);
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function commit(next: Pin[]) {
    pinsRef = next;
    pins = next;
  }

  function nudge() {
    if (finishedRef) return;
    const idx = activeRef;
    const next = pinsRef.map((p, i) =>
      i === idx ? { ...p, velocity: Math.min(220, p.velocity + push) } : p
    );
    commit(next);
  }

  function setPin() {
    if (finishedRef) return;
    const idx = activeRef;
    const pin = pinsRef[idx];
    if (!pin) return;

    if (inZone(pin)) {
      const next = pinsRef.map((p, i) => (i === idx ? { ...p, velocity: 0, set: true } : p));
      commit(next);
      flash = "ok";
      window.setTimeout(() => {
        if (flash === "ok") flash = null;
      }, 160);

      const nextIdx = next.findIndex((p) => !p.set);
      if (nextIdx < 0) {
        window.setTimeout(() => void endGame(true), 220);
        return;
      }
      activeRef = nextIdx;
      active = nextIdx;
      return;
    }

    flash = "bad";
    window.setTimeout(() => {
      if (flash === "bad") flash = null;
    }, 200);

    if (instantFail) {
      window.setTimeout(() => void endGame(false), 220);
      return;
    }

    attemptsRef -= 1;
    attempts = attemptsRef;
    commit(pinsRef.map((p, i) => (i === idx ? { ...p, velocity: 0 } : p)));
    if (attemptsRef <= 0) {
      window.setTimeout(() => void endGame(false), 220);
    }
  }

  $effect(() => {
    let last = performance.now();
    startRef = last;
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      const idx = activeRef;
      const pin = pinsRef[idx];
      if (pin && !pin.set) {
        let v = pin.velocity - gravity * dt;
        let h = pin.height + v * dt;
        if (h <= 0) {
          h = 0;
          v = Math.max(0, v);
        } else if (h >= 100) {
          h = 100;
          v = Math.min(0, v);
        }
        commit(pinsRef.map((p, i) => (i === idx ? { ...p, height: h, velocity: v } : p)));
      }

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

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }
      if (e.repeat) return;
      if (e.code === "Space") {
        e.preventDefault();
        nudge();
      } else if (e.code === "KeyE") {
        e.preventDefault();
        setPin();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card pinlock__card">
    <div class="mg__header">
      <div class="mg__heading">
        <LockKeyhole class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Pin Lock</span>
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
      <div class="pinlock__body">
        <div
          class={[
            "pinlock__lock",
            flash === "ok" ? "pinlock__lock--ok" : "",
            flash === "bad" ? "pinlock__lock--bad" : "",
          ]}
        >
          {#each pins as pin, i}
            {@const isActive = i === active && !pin.set}
            {@const lit = pin.set || (isActive && inZone(pin))}
            <div class={["pinlock__channel", isActive ? "pinlock__channel--active" : ""]}>
              <div
                class={[
                  "pinlock__pin",
                  isActive ? "pinlock__pin--active" : "",
                  lit ? "pinlock__pin--lit" : "",
                  pin.set ? "pinlock__pin--set" : "",
                ]}
                style="bottom: {pinBottom(pin.height)}%; height: {PIN_H}%"
              ></div>
            </div>
          {/each}
        </div>

        {#if !instantFail}
          <div class="mg__meta">
            <span class="mg__meta-label">Attempts</span>
            <div class="pinlock__attempts" aria-label="{attempts} attempts left">
              {#each { length: maxAttempts } as _, i}
                <span class={["pinlock__attempt", i < attempts ? "" : "pinlock__attempt--lost"]}
                ></span>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </div>

    <div class="mg__footer">
      <kbd class="mg__key">Space</kbd> Raise the pin - <kbd class="mg__key">E</kbd> Set the pin -
      Esc
    </div>

    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
