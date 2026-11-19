<script lang="ts">
  import { untrack } from "svelte";
  import ChevronDown from "@lucide/svelte/icons/chevron-down";
  import Mouse from "@lucide/svelte/icons/mouse";
  import ArrowLeft from "@lucide/svelte/icons/arrow-left";
  import ArrowRight from "@lucide/svelte/icons/arrow-right";
  import Lock from "@lucide/svelte/icons/lock";
  import CornerDownLeft from "@lucide/svelte/icons/corner-down-left";
  import { fetchNui } from "../../../../utils/fetchNui";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { SafeCrackConfig, SafeCrackDirection } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./SafeCrack.css";

  let { config: configProp }: { config: SafeCrackConfig } = $props();

  const config = untrack(() => configProp);

  type RotationDir = SafeCrackDirection | "idle";

  const DIAL_MARKS = 100;
  /** Original: 3.6° per number → one dial mark */
  const ROTATION_PER_NUMBER = 1;
  /** Original tap debounce / hold speed */
  const DEBOUNCE_TAP_MS = 100;
  const DEBOUNCE_HOLD_MS = 10;
  const WHEEL_COOLDOWN_MS = 55;
  const WHEEL_ACCUM_THRESHOLD = 48;

  function normalizeNumber(value: number) {
    let n = Math.round(value) % 100;
    if (n < 0) n += 100;
    return n;
  }

  function opposite(dir: SafeCrackDirection): SafeCrackDirection {
    return dir === "clockwise" ? "anticlockwise" : "clockwise";
  }

  async function playSound(sound: "turn" | "pin" | "pinFinal" | "reset") {
    await fetchNui("safeCrackSound", { sound }, { data: true, delay: 0 });
  }

  const dialTicks = Array.from({ length: DIAL_MARKS }, (_, i) => {
    const major = i % 10 === 0;
    const mid = i % 5 === 0;
    return {
      i,
      major,
      mid,
      angle: (i / DIAL_MARKS) * 360,
      len: major ? 10 : mid ? 6.5 : 3.5,
      width: major ? 1.6 : 1,
    };
  });

  const dialLabels = Array.from({ length: 10 }, (_, idx) => {
    const value = idx * 10;
    const angle = (value / DIAL_MARKS) * 360;
    const rad = ((angle - 90) * Math.PI) / 180;
    const r = 34;
    return {
      value,
      x: 100 + Math.cos(rad) * r,
      y: 100 + Math.sin(rad) * r,
    };
  });

  let dialNumber = $state(normalizeNumber(config.dialStart));
  let currentLockNum = $state(0);
  let lockStatus = $state(config.combination.map(() => true));
  let requiredDir = $state<SafeCrackDirection>(config.startDirection);
  let shakeAmt = $state(0);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let tryFlash = $state(false);
  let shakeOffset = $state({ x: 0, y: 0 });

  let dialRef = normalizeNumber(config.dialStart);
  let lockNumRef = 0;
  let lockStatusRef = config.combination.map(() => true);
  let requiredRef: SafeCrackDirection = config.startDirection;
  let currentDirRef: RotationDir = "idle";
  let lastDirRef: RotationDir = "idle";
  let lastInputRef = 0;
  let debounceRef = DEBOUNCE_TAP_MS;
  let finishedRef = false;
  let keysRef = { left: false, right: false, leftWas: false, rightWas: false };
  let wheelLockRef = 0;
  let wheelAccRef = 0;
  let rafRef: number | null = null;

  const total = config.combination.length;
  const maxTries = Math.max(1, config.tries ?? 3);
  const durationMs = Math.max(15000, config.duration ?? total * 25000);
  const lockoutMs = config.wrongLockoutMs ?? 900;
  let triesLeft = $state(maxTries);
  let timeLeft = $state(Math.ceil(durationMs / 1000));
  let lockedOut = $state(false);
  let lockoutUntil = 0;
  const startedAt = performance.now();
  const turnLabel = $derived(`${Math.min(currentLockNum + 1, total)} / ${total}`);
  const shakeStyle = $derived(
    shakeAmt > 0
      ? `--sc-shake-x: calc(${shakeOffset.x}vh / var(--ui-scale, 1)); --sc-shake-y: calc(${shakeOffset.y}vh / var(--ui-scale, 1))`
      : undefined
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  /** GetDialProximityToTargetPin */
  function getDialProximity(current: number, dir: RotationDir, lastDir: RotationDir) {
    const target = config.combination[lockNumRef];
    if (target === undefined) return 100;

    const effective: RotationDir =
      dir !== "idle"
        ? dir
        : lastDir === "clockwise" || lastDir === "anticlockwise"
          ? lastDir
          : "idle";

    // clockwise counts the dial down (the face turns clockwise under the pointer),
    // anticlockwise counts it up: proximity = marks still to go before the pin
    let proximity: number;
    if (effective === "clockwise") {
      proximity = current - target;
    } else if (effective === "anticlockwise") {
      proximity = target - current;
    } else {
      return 100;
    }

    if (proximity < 0) proximity += 100;
    return proximity;
  }

  /** SetDialSpriteShake - strongest exactly on the pin, weaker 1-2 marks before it.
   *  (It used to shake only 1-2 marks early and stop on the pin itself, so players parked on the
   *  strongest shake - one mark short - and every try failed.) */
  function updateShake(current: number, dir: RotationDir, lastDir: RotationDir) {
    const proximity = getDialProximity(current, dir, lastDir);
    const movingCorrect =
      (dir !== "idle" && dir === requiredRef) ||
      (dir === "idle" && lastDir === requiredRef);

    if (!movingCorrect) {
      shakeAmt = 0;
      return;
    }

    if (proximity === 0) shakeAmt = 3;
    else if (proximity === 1) shakeAmt = 1.5;
    else if (proximity === 2) shakeAmt = 0.75;
    else shakeAmt = 0;
  }

  /** ReleaseCurrentPin */
  function releaseCurrentPin() {
    const idx = lockNumRef;
    if (!lockStatusRef[idx]) return;

    const nextLocks = [...lockStatusRef];
    nextLocks[idx] = false;
    lockStatusRef = nextLocks;
    lockStatus = nextLocks;

    const nextLock = idx + 1;
    lockNumRef = nextLock;
    currentLockNum = nextLock;

    const unlocked = nextLocks.every((locked) => !locked);
    void playSound(unlocked ? "pinFinal" : "pin");

    if (unlocked) {
      void endGame(true);
      return;
    }

    const nextDir = opposite(requiredRef);
    requiredRef = nextDir;
    requiredDir = nextDir;
    shakeAmt = 0;
  }

  /** Enter / TRY - attempt to crack the current pin */
  function tryHack() {
    if (finishedRef) return;
    // right after a wrong try the button is jammed: spamming it can't brute force the dial
    if (performance.now() < lockoutUntil) return;

    const current = dialRef;
    const target = config.combination[lockNumRef];
    const correctDir =
      lastDirRef === requiredRef || currentDirRef === requiredRef;

    tryFlash = true;
    window.setTimeout(() => (tryFlash = false), 180);

    if (correctDir && lockStatusRef[lockNumRef] && current === target) {
      releaseCurrentPin();
      return;
    }

    // Wrong try: costs one of the limited tries and jams the button for a moment.
    // Progress is kept; running out of tries fails the safe.
    shakeAmt = 0;
    void playSound("reset");
    triesLeft = Math.max(0, triesLeft - 1);
    if (triesLeft <= 0) {
      void endGame(false);
      return;
    }
    lockoutUntil = performance.now() + lockoutMs;
    lockedOut = true;
    window.setTimeout(() => (lockedOut = false), lockoutMs);
  }

  /** RotateSafeDial - exactly one mark per call */
  function rotateSafeDial(direction: SafeCrackDirection) {
    if (finishedRef) return;

    // Turning the wrong way (e.g. backing up after overshooting) no longer resets the pins you
    // already have: it just doesn't count - the shake only shows while turning the required way
    // and a Try only works if the last turn was the required way.

    // the face is drawn rotate(-n * 3.6): turning it clockwise (D / scroll down) lowers the number
    // under the pointer, so the dial visibly turns the way the "Clockwise" hint says
    const multiplier = direction === "clockwise" ? -ROTATION_PER_NUMBER : ROTATION_PER_NUMBER;
    const next = normalizeNumber(dialRef + multiplier);
    dialRef = next;
    dialNumber = next;

    currentDirRef = direction;
    lastDirRef = direction;
    lastInputRef = performance.now();

    void playSound("turn");
    updateShake(next, direction, direction);
  }

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;

      if (e.code === "Escape" || e.code === "KeyS") {
        e.preventDefault();
        void endGame(false);
        return;
      }

      if (e.code === "Enter" || e.code === "Space" || e.code === "KeyE") {
        e.preventDefault();
        if (!e.repeat) tryHack(); // holding the key must not fire tries
        return;
      }

      if (e.code === "KeyA" || e.code === "ArrowLeft") {
        e.preventDefault();
        keysRef.left = true;
      }
      if (e.code === "KeyD" || e.code === "ArrowRight") {
        e.preventDefault();
        keysRef.right = true;
      }
    };

    const onKeyUp = (e: KeyboardEvent) => {
      if (e.code === "KeyA" || e.code === "ArrowLeft") {
        keysRef.left = false;
        keysRef.leftWas = false;
      }
      if (e.code === "KeyD" || e.code === "ArrowRight") {
        keysRef.right = false;
        keysRef.rightWas = false;
      }

      if (!keysRef.left && !keysRef.right) {
        currentDirRef = "idle";
        updateShake(dialRef, "idle", lastDirRef);
      }
    };

    const onWheel = (e: WheelEvent) => {
      if (finishedRef) return;
      e.preventDefault();

      const now = performance.now();
      const discrete =
        e.deltaMode === WheelEvent.DOM_DELTA_LINE ||
        e.deltaMode === WheelEvent.DOM_DELTA_PAGE ||
        Math.abs(e.deltaY) >= WHEEL_ACCUM_THRESHOLD;

      const step = (sign: number) => {
        if (now - wheelLockRef < WHEEL_COOLDOWN_MS) return;
        wheelLockRef = now;
        wheelAccRef = 0;
        rotateSafeDial(sign > 0 ? "clockwise" : "anticlockwise");
        currentDirRef = "idle";
      };

      if (discrete) {
        step(e.deltaY > 0 ? 1 : -1);
        return;
      }

      wheelAccRef += e.deltaY;
      if (Math.abs(wheelAccRef) < WHEEL_ACCUM_THRESHOLD) return;
      step(wheelAccRef > 0 ? 1 : -1);
    };

    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    window.addEventListener("wheel", onWheel, { passive: false });

    const tick = () => {
      if (!finishedRef) {
        const { left, right } = keysRef;
        const now = performance.now();

        if (left !== right) {
          const isLeft = left;
          const was = isLeft ? keysRef.leftWas : keysRef.rightWas;
          const justPressed = !was;

          if (justPressed) {
            if (isLeft) keysRef.leftWas = true;
            else keysRef.rightWas = true;
            debounceRef = DEBOUNCE_TAP_MS;
            lastInputRef = now;
            rotateSafeDial(isLeft ? "anticlockwise" : "clockwise");
          } else if (now - lastInputRef >= debounceRef) {
            debounceRef = DEBOUNCE_HOLD_MS;
            lastInputRef = now;
            rotateSafeDial(isLeft ? "anticlockwise" : "clockwise");
          }
        }
      }
      rafRef = requestAnimationFrame(tick);
    };
    rafRef = requestAnimationFrame(tick);

    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
      window.removeEventListener("wheel", onWheel);
      if (rafRef) cancelAnimationFrame(rafRef);
    };
  });

  // Whole-safe timer.
  $effect(() => {
    const id = window.setInterval(() => {
      if (finishedRef) return;
      const left = Math.max(0, durationMs - (performance.now() - startedAt));
      timeLeft = Math.ceil(left / 1000);
      if (left <= 0) void endGame(false);
    }, 200);
    return () => window.clearInterval(id);
  });

  // Keep SetDialSpriteShake jitter alive while close to the pin. Runs once for
  // the component's lifetime (reads shakeAmt fresh via closure each tick)
  // instead of a $effect keyed on shakeAmt - that version tore down and
  // recreated its own setTimeout chain on every proximity change, which can
  // happen up to ~100x/sec while holding a rotate key near the target.
  $effect(() => {
    let wasShaking = false;
    const id = window.setInterval(() => {
      if (shakeAmt <= 0) {
        if (wasShaking) {
          shakeOffset = { x: 0, y: 0 };
          wasShaking = false;
        }
        return;
      }
      wasShaking = true;
      const mag = shakeAmt * 0.1;
      shakeOffset = {
        x: (Math.random() - 0.5) * mag,
        y: (Math.random() - 0.5) * mag,
      };
    }, 32);
    return () => window.clearInterval(id);
  });
</script>

<div class="mg">
  <div class="mg__card mg__card--narrow">
    <div class="mg__header">
      <div class="mg__heading">
        <Lock class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Safe Crack</span>
        <span class="mg__subtitle">{turnLabel}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {(timeLeft / (durationMs / 1000)) * 100}%"></div>
        </div>
        <span class="mg__timer-text">{timeLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="mg__meta">
        <span class="mg__meta-label">Tries</span>
        <span class="safecrack__tries">
          {#each Array.from({ length: maxTries }) as _, i}
            <span class={["safecrack__try-pip", i >= triesLeft ? "safecrack__try-pip--used" : ""]}></span>
          {/each}
        </span>
        <span class="mg__meta-label">Pins</span>
        <span class="safecrack__steps">
          {#each lockStatus as locked, i}
            <span
              class={[
                "safecrack__step",
                !locked ? "safecrack__step--done" : "",
                locked && i === currentLockNum ? "safecrack__step--current" : "",
              ]}
            ></span>
          {/each}
        </span>
        <span class="mg__meta-value">
          <Mouse style={iconSize(1.25)} strokeWidth={1.75} />
          {#if requiredDir === "clockwise"}
            <ArrowRight style={iconSize(1.25)} strokeWidth={2.25} />
          {:else}
            <ArrowLeft style={iconSize(1.25)} strokeWidth={2.25} />
          {/if}
          {requiredDir === "clockwise" ? "Clockwise" : "Anticlockwise"}
        </span>
      </div>

      <div class="safecrack__stage">
        <div
          class={["safecrack__dial-wrap", shakeAmt > 0 ? "safecrack__dial-wrap--shake" : ""]}
          style={shakeStyle}
        >
          <div class="safecrack__pointer">
            <ChevronDown style={iconSize(2.2)} strokeWidth={3} />
          </div>
          <div class="safecrack__dial">
            <svg class="safecrack__dial-svg" viewBox="0 0 200 200">
              <g transform="rotate({-dialNumber * 3.6} 100 100)">
                <circle cx="100" cy="100" r="96" fill="none" stroke="#2c2e33" stroke-width="1.5" />
                {#each dialTicks as t}
                  <line
                    x1="100"
                    y1="12"
                    x2="100"
                    y2={12 + t.len}
                    stroke={t.major ? "#c1c2c5" : "#5c5f66"}
                    stroke-width={t.width}
                    transform="rotate({t.angle} 100 100)"
                    stroke-linecap="round"
                  />
                {/each}
                {#each dialLabels as l}
                  <text
                    x={l.x}
                    y={l.y}
                    fill="#c1c2c5"
                    font-size="9"
                    text-anchor="middle"
                    dominant-baseline="middle"
                  >
                    {l.value}
                  </text>
                {/each}
                <circle cx="100" cy="100" r="22" fill="#141517" stroke="#2c2e33" stroke-width="2" />
                <circle cx="100" cy="100" r="4" fill="#909296" />
              </g>
            </svg>
          </div>
        </div>

        <button
          type="button"
          class={["safecrack__try", tryFlash ? "safecrack__try--flash" : ""]}
          disabled={finished || lockedOut}
          onclick={tryHack}
        >
          <CornerDownLeft style={iconSize(1.4)} strokeWidth={2} />
          {lockedOut ? "Jammed..." : "Try hack"}
        </button>
      </div>
    </div>

    <div class="mg__footer">A / D - Scroll - Enter - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
