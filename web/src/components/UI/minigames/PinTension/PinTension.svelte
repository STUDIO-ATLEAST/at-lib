<script lang="ts">
  import { untrack } from "svelte";
  import KeyRound from "@lucide/svelte/icons/key-round";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type {
    PinTensionConfig,
    PinTensionPin,
  } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./PinTension.css";

  let { config: configProp }: { config: PinTensionConfig } = $props();

  const config = untrack(() => configProp);

  type LivePin = PinTensionPin & {
    height: number;
    set: boolean;
  };

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  function inZone(value: number, center: number, size: number) {
    const half = size / 2;
    return value >= center - half && value <= center + half;
  }

  const fallSpeed = $derived(Math.max(10, config.fallSpeed));
  const maxDurability = $derived(Math.max(1, config.durability));
  // 0 = no overall timer (default): pick durability ends the game
  const duration = $derived((config.duration ?? 0) > 0 ? Math.max(12000, config.duration) : 0);
  const pinDefs = $derived(
    (config.pins?.length ? config.pins : []).map((p) => ({
      target: clamp(p.target, 15, 90),
      zone: clamp(p.zone, 4, 22),
      tension: clamp(p.tension, 15, 90),
      tensionTol: clamp(p.tensionTol, 4, 24),
    }))
  );

  let pins = $state<LivePin[]>([]);
  let active = $state(0);
  let tension = $state(40);
  let durability = $state(1);
  let progress = $state(100);
  let holdMs = $state(0);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);
  let status = $state("Set tension, then lift");

  let finishedRef = false;
  let pinsRef: LivePin[] = [];
  let activeRef = 0;
  let tensionRef = 40;
  let durabilityRef = 1;
  let holdMsRef = 0;
  let keysRef = { up: false, down: false, left: false, right: false };
  let startRef = performance.now();
  let lastRef = performance.now();
  let overstressRef = 0;
  let runIdRef = 0;

  const current = $derived(pins[active]);
  const liftOk = $derived(
    current ? inZone(current.height, current.target, current.zone) : false
  );
  const tensionOk = $derived(
    current ? inZone(tension, current.tension, current.tensionTol) : false
  );
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const setCount = $derived(pins.filter((p) => p.set).length);
  const subtitle = $derived(
    result !== null
      ? result
        ? "Unlocked"
        : "Broken"
      : `${setCount}/${pins.length} pins`
  );
  const tensionClass = $derived(
    !current
      ? ""
      : tensionOk
        ? "pintension__fill--ok"
        : tension > current.tension + current.tensionTol
          ? "pintension__fill--hot"
          : "pintension__fill--cold"
  );
  const holdPct = $derived(
    holdMs > 0 ? ` (${Math.min(100, Math.round((holdMs / 420) * 100))}%)` : ""
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function damage(amount: number, reason: string) {
    if (finishedRef) return;
    const next = Math.max(0, durabilityRef - amount);
    durabilityRef = next;
    durability = next;
    status = reason;
    if (next <= 0) {
      void endGame(false);
    }
  }

  $effect(() => {
    const live = pinDefs.map((p) => ({ ...p, height: 8, set: false }));
    void maxDurability;
    void duration;
    void fallSpeed;
    pins = live;
    pinsRef = live;
    active = 0;
    activeRef = 0;
    tension = 40;
    tensionRef = 40;
    durability = maxDurability;
    durabilityRef = maxDurability;
    holdMs = 0;
    holdMsRef = 0;
    finished = false;
    result = null;
    finishedRef = false;
    overstressRef = 0;
    startRef = performance.now();
    lastRef = performance.now();
    progress = 100;
    status = "Set tension, then lift";
    runIdRef += 1;
    runId = runIdRef;
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }
      if (e.code === "KeyW" || e.code === "ArrowUp") {
        e.preventDefault();
        keysRef.up = true;
      }
      if (e.code === "KeyS" || e.code === "ArrowDown") {
        e.preventDefault();
        keysRef.down = true;
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
      if (e.code === "KeyW" || e.code === "ArrowUp") keysRef.up = false;
      if (e.code === "KeyS" || e.code === "ArrowDown") keysRef.down = false;
      if (e.code === "KeyA" || e.code === "ArrowLeft") keysRef.left = false;
      if (e.code === "KeyD" || e.code === "ArrowRight") keysRef.right = false;
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
    };
  });

  $effect(() => {
    void runId;
    const fall = fallSpeed;
    lastRef = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef) return;
      const dt = Math.min(0.05, (now - lastRef) / 1000);
      lastRef = now;

      const keys = keysRef;
      let t = tensionRef;
      if (keys.left) t -= 55 * dt;
      if (keys.right) t += 55 * dt;
      t = clamp(t, 0, 100);
      tensionRef = t;
      tension = t;

      const idx = activeRef;
      const list = pinsRef.map((p) => ({ ...p }));
      const pin = list[idx];
      if (!pin || pin.set) {
        raf = requestAnimationFrame(tick);
        return;
      }

      const tOk = inZone(t, pin.tension, pin.tensionTol);
      const tooHigh = t > pin.tension + pin.tensionTol;
      const tooLow = t < pin.tension - pin.tensionTol;

      let lift = 0;
      if (keys.up) lift += 48 * dt;
      if (keys.down) lift -= 48 * dt;

      if (tooHigh && (keys.up || keys.down)) {
        overstressRef += dt;
        if (overstressRef >= 0.35) {
          overstressRef = 0;
          pin.height = 8;
          list[idx] = pin;
          pinsRef = list;
          pins = list;
          holdMsRef = 0;
          holdMs = 0;
          damage(1, "Too much tension - pin reset");
        }
      } else {
        overstressRef = Math.max(0, overstressRef - dt * 2);
      }

      if (tooHigh && t > pin.tension + pin.tensionTol + 10) {
        if (Math.random() < dt * 0.15) {
          pin.height = 8;
          list[idx] = pin;
          pinsRef = list;
          pins = list;
          holdMsRef = 0;
          holdMs = 0;
          damage(1, "Lock jammed - pick stressed");
        }
      }

      if (lift !== 0) {
        pin.height = clamp(pin.height + lift, 0, 100);
      } else if (tooLow) {
        pin.height = clamp(pin.height - fall * dt, 0, 100);
        if (pin.height < 12) status = "Too little tension - pin falling";
      } else if (!keys.up && !keys.down && tOk) {
        pin.height = clamp(pin.height - fall * 0.15 * dt, 0, 100);
      }

      const hOk = inZone(pin.height, pin.target, pin.zone);
      if (hOk && tOk) {
        const nextHold = holdMsRef + dt * 1000;
        if (nextHold >= 420) {
          pin.set = true;
          pin.height = pin.target;
          list[idx] = pin;
          pinsRef = list;
          pins = list;
          holdMsRef = 0;
          holdMs = 0;

          const allSet = list.every((p) => p.set);
          if (allSet) {
            status = "Lock open";
            window.setTimeout(() => void endGame(true), 220);
          } else {
            const nextIdx = list.findIndex((p) => !p.set);
            active = nextIdx;
            activeRef = nextIdx;
            status = `Pin ${idx + 1} set`;
          }
        } else {
          holdMsRef = nextHold;
          holdMs = nextHold;
          status = "Holding…";
        }
      } else {
        holdMsRef = 0;
        holdMs = 0;
        if (tOk && !hOk) status = "Lift pin into the zone";
        else if (!tOk && hOk) status = "Adjust tension";
        else if (!tooHigh) status = "Set tension, then lift";
      }

      list[idx] = pin;
      pinsRef = list;
      pins = list;

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    void runId;
    const total = duration;
    startRef = performance.now();
    progress = 100;
    if (total <= 0) return;
    let raf = 0;
    const loop = (now: number) => {
      if (finishedRef) return;
      const left = Math.max(0, 100 - ((now - startRef) / total) * 100);
      progress = left;
      if (left <= 0) {
        void endGame(false);
        return;
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  });
</script>

<div class="mg">
  <div class="mg__card pintension__card">
    <div class="mg__header">
      <div class="mg__heading">
        <KeyRound class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Pin Tension</span>
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
      <div class="pintension__body">
        <div class="pintension__lock">
          {#each pins as pin, i}
            {@const zoneBottom = pin.target - pin.zone / 2}
            {@const showZone = i === active && !pin.set}
            <div
              class={[
                "pintension__chamber",
                i === active ? "pintension__chamber--active" : "",
                pin.set ? "pintension__chamber--set" : "",
              ]}
            >
              {#if showZone}
                <div
                  class="pintension__zone"
                  style="bottom: {zoneBottom}%; height: {pin.zone}%"
                ></div>
              {/if}
              <div
                class="pintension__pin"
                style="height: {Math.max(6, pin.height)}%"
              >
                <div class="pintension__pin-head"></div>
                {#if i === active && !pin.set}
                  <div class="pintension__pick" style="top: 0"></div>
                {/if}
              </div>
              <div class="pintension__index">{i + 1}</div>
            </div>
          {/each}
        </div>

        <div class="pintension__meters">
          <div class="pintension__meter">
            <div class="pintension__meter-label">
              <span>Tension</span>
              <strong>{Math.round(tension)}</strong>
            </div>
            <div class="pintension__track">
              {#if current}
                <div
                  class="pintension__sweet"
                  style="left: {clamp(
                    current.tension - current.tensionTol / 2,
                    0,
                    100
                  )}%; width: {current.tensionTol}%"
                ></div>
              {/if}
              <div
                class="pintension__fill {tensionClass}"
                style="width: {tension}%"
              ></div>
            </div>
          </div>

          <div class="pintension__meter">
            <div class="pintension__meter-label">
              <span>Pin height</span>
              <strong>{current ? Math.round(current.height) : 0}</strong>
            </div>
            <div class="pintension__track">
              {#if current}
                <div
                  class="pintension__sweet"
                  style="left: {clamp(
                    current.target - current.zone / 2,
                    0,
                    100
                  )}%; width: {current.zone}%"
                ></div>
              {/if}
              <div
                class={[
                  "pintension__fill",
                  liftOk && tensionOk ? "pintension__fill--ok" : "",
                ]}
                style="width: {current?.height ?? 0}%"
              ></div>
            </div>
          </div>
        </div>

        <div class="pintension__durability">
          <span>
            Lockpick <strong>{durability}/{maxDurability}</strong>
          </span>
          <div class="pintension__pips" aria-hidden="true">
            {#each { length: maxDurability } as _, i}
              <span
                class={[
                  "pintension__pip",
                  i < durability ? "" : "pintension__pip--lost",
                ]}
              ></span>
            {/each}
          </div>
        </div>

        <div class="pintension__hint">{status}{holdPct}</div>
      </div>
    </div>

    <div class="mg__footer">
      A/D tension - W/S lift - hold in both zones - Esc
    </div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
