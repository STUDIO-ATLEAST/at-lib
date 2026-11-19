<script lang="ts">
  import { untrack } from "svelte";
  import Scan from "@lucide/svelte/icons/scan";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { LaserGridConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./LaserGrid.css";

  let { config: configProp }: { config: LaserGridConfig } = $props();

  const config = untrack(() => configProp);

  // A gate is a vertical laser fence with a gap that slides up and down.
  type Gate = {
    id: number;
    x: number;
    gapSize: number;
    amp: number;
    omega: number;
    phase: number;
    gapStart: number;
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

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  const GATE_X_MIN = 26;
  const GATE_X_MAX = 80;

  // Evenly spaced lanes, so gates never overlap and there is always room to wait
  // between two of them. `spd` is the peak gap speed in % of the arena per second.
  function buildGates(count: number, spd: number, rand: () => number): Gate[] {
    const step = (GATE_X_MAX - GATE_X_MIN) / count;
    const gates: Gate[] = [];
    for (let i = 0; i < count; i++) {
      const gapSize = 24 + rand() * 6;
      const amp = (100 - gapSize) / 2 - 5;
      const peak = spd * (0.85 + rand() * 0.3);
      const phase = rand() * Math.PI * 2;
      gates.push({
        id: i,
        x: GATE_X_MIN + step * (i + 0.5),
        gapSize,
        amp,
        omega: peak / amp,
        phase,
        gapStart: 50 + amp * Math.sin(phase) - gapSize / 2,
      });
    }
    return gates;
  }

  function hitsGate(x: number, y: number, r: number, gate: Gate) {
    const thickness = 1.1;
    if (Math.abs(x - gate.x) > r + thickness * 0.5) return false;
    return !(y > gate.gapStart && y < gate.gapStart + gate.gapSize);
  }
  const SAFE_ZONE = { x: 2, y: 36, w: 16, h: 28 };

  function inSafeZone(x: number, y: number) {
    return (
      x >= SAFE_ZONE.x &&
      x <= SAFE_ZONE.x + SAFE_ZONE.w &&
      y >= SAFE_ZONE.y &&
      y <= SAFE_ZONE.y + SAFE_ZONE.h
    );
  }

  const laserCount = $derived(Math.min(10, Math.max(2, config.laserCount)));
  const laserSpeed = $derived(Math.max(8, config.laserSpeed));
  const sections = $derived(Math.min(4, Math.max(1, config.sections)));
  const maxDetection = $derived(Math.max(1, config.detectionHits));
  const fog = $derived(!!config.fog);
  const cameraSway = $derived(!!config.cameraSway);
  const duration = $derived(Math.max(12000, config.duration));
  const seed = $derived(config.seed ?? 1);

  const layout = $derived(buildGates(laserCount, laserSpeed, mulberry32(seed)));

  const spawn = { x: SAFE_ZONE.x + SAFE_ZONE.w / 2, y: SAFE_ZONE.y + SAFE_ZONE.h / 2 };
  const exit = { x: 88, y: 40, w: 10, h: 20 };

  let player = $state(spawn);
  let lasers = $state<Gate[]>([]);
  let section = $state(0);
  let detection = $state(0);
  let progress = $state(100);
  let hitFlash = $state(false);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let sway = $state({ x: 0, y: 0 });
  let runId = $state(0);

  let finishedRef = false;
  let playerRef = spawn;
  let lasersRef: Gate[] = [];
  let keysRef = { up: false, down: false, left: false, right: false };
  let invulnRef = 0;
  let detectionRef = 0;
  let sectionRef = 0;
  let startRef = performance.now();
  let penaltyRef = 0;
  let lastRef = performance.now();
  let spawnRef = spawn;

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function resetToSpawn() {
    const s = spawnRef;
    playerRef = { ...s };
    player = { ...s };
  }

  function onLaserHit() {
    if (finishedRef || invulnRef > 0) return;
    invulnRef = 0.85;
    hitFlash = true;
    window.setTimeout(() => (hitFlash = false), 220);

    penaltyRef += 2500;
    const nextDet = detectionRef + 1;
    detectionRef = nextDet;
    detection = nextDet;
    resetToSpawn();

    if (nextDet >= maxDetection) {
      void endGame(false);
    }
  }

  $effect(() => {
    duration;
    maxDetection;
    const nextLayout = layout;
    lasers = nextLayout;
    lasersRef = nextLayout;
    spawnRef = spawn;
    player = { ...spawn };
    playerRef = { ...spawn };
    section = 0;
    sectionRef = 0;
    detection = 0;
    detectionRef = 0;
    hitFlash = false;
    finished = false;
    result = null;
    finishedRef = false;
    invulnRef = 0;
    penaltyRef = 0;
    startRef = performance.now();
    lastRef = performance.now();
    progress = 100;
    runId = performance.now();
  });

  $effect(() => {
    const down = (e: KeyboardEvent) => {
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
    const up = (e: KeyboardEvent) => {
      if (e.code === "KeyW" || e.code === "ArrowUp") keysRef.up = false;
      if (e.code === "KeyS" || e.code === "ArrowDown") keysRef.down = false;
      if (e.code === "KeyA" || e.code === "ArrowLeft") keysRef.left = false;
      if (e.code === "KeyD" || e.code === "ArrowRight") keysRef.right = false;
    };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
    };
  });

  $effect(() => {
    runId;
    const swayOn = cameraSway;
    const count = laserCount;
    const spd = laserSpeed;
    const totalSections = sections;
    const layoutSeed = seed;
    lastRef = performance.now();
    let raf = 0;
    const moveSpeed = 46;
    const pr = 1.4;

    const tick = (now: number) => {
      if (finishedRef) return;
      const dt = Math.min(0.05, (now - lastRef) / 1000);
      lastRef = now;
      invulnRef = Math.max(0, invulnRef - dt);

      if (swayOn) {
        const t = now / 1000;
        sway = {
          x: Math.sin(t * 1.3) * 1.2,
          y: Math.cos(t * 1.1) * 1.2,
        };
      }

      const nextLasers = lasersRef.map((g) => {
        const phase = g.phase + g.omega * dt;
        return { ...g, phase, gapStart: 50 + g.amp * Math.sin(phase) - g.gapSize / 2 };
      });
      lasersRef = nextLasers;
      lasers = nextLasers;

      const keys = keysRef;
      let { x, y } = playerRef;
      if (keys.up) y -= moveSpeed * dt;
      if (keys.down) y += moveSpeed * dt;
      if (keys.left) x -= moveSpeed * dt;
      if (keys.right) x += moveSpeed * dt;
      x = clamp(x, 3, 97);
      y = clamp(y, 3, 97);

      playerRef = { x, y };
      player = { x, y };

      const safe = inSafeZone(x, y);
      if (!safe && invulnRef <= 0) {
        for (const gate of nextLasers) {
          if (hitsGate(x, y, pr, gate)) {
            onLaserHit();
            break;
          }
        }
      }

      if (x > exit.x && x < exit.x + exit.w && y > exit.y && y < exit.y + exit.h) {
        const nextSection = sectionRef + 1;
        if (nextSection >= totalSections) {
          void endGame(true);
        } else {
          sectionRef = nextSection;
          section = nextSection;
          const rand = mulberry32(layoutSeed + nextSection * 1337);
          const fresh = buildGates(count, spd * (1 + nextSection * 0.1), rand);
          lasersRef = fresh;
          lasers = fresh;
          resetToSpawn();
          invulnRef = 0.5;
        }
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    runId;
    const dur = duration;
    startRef = performance.now();
    penaltyRef = 0;
    progress = 100;
    let raf = 0;
    const loop = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - startRef + penaltyRef;
      const left = Math.max(0, 100 - (elapsed / dur) * 100);
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

  const inExit = $derived(
    player.x > exit.x &&
      player.x < exit.x + exit.w &&
      player.y > exit.y &&
      player.y < exit.y + exit.h
  );
  const playerSafe = $derived(inSafeZone(player.x, player.y));
  const subtitle = $derived(
    result !== null
      ? result
        ? "Clear"
        : "Alarm"
      : playerSafe
        ? "Safe booth"
        : `Sector ${section + 1}/${sections}`
  );
</script>

<div class="mg">
  <div class="mg__card lasergrid__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Scan class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Laser Grid</span>
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
      <div class="lasergrid__body">
        <div
          class={["lasergrid__arena", hitFlash ? "lasergrid__arena--hit" : ""]}
          style={cameraSway ? `transform: translate(${sway.x}%, ${sway.y}%)` : undefined}
        >
          <div class="lasergrid__grid"></div>

          <div
            class="lasergrid__safe"
            style="left: {SAFE_ZONE.x}%; top: {SAFE_ZONE.y}%; width: {SAFE_ZONE.w}%; height: {SAFE_ZONE.h}%"
          >
            <span class="lasergrid__safe-label">SAFE</span>
          </div>

          <div
            class="lasergrid__exit"
            style="left: {exit.x}%; top: {exit.y}%; width: {exit.w}%; height: {exit.h}%"
          >
            <span class="lasergrid__exit-label">EXIT</span>
          </div>

          {#each lasers as g (g.id)}
            <div
              class="lasergrid__laser lasergrid__laser--v"
              style="left: {g.x}%; top: 0; height: {g.gapStart}%"
            ></div>
            <div
              class="lasergrid__laser lasergrid__laser--v"
              style="left: {g.x}%; top: {g.gapStart + g.gapSize}%; height: {100 - (g.gapStart + g.gapSize)}%"
            ></div>
          {/each}

          <div
            class={["lasergrid__player", inExit || playerSafe ? "lasergrid__player--safe" : ""]}
            style="left: {player.x}%; top: {player.y}%"
          ></div>

          {#if fog}
            <div
              class="lasergrid__fog"
              style="--fog-x: {player.x}%; --fog-y: {player.y}%"
            ></div>
          {/if}
        </div>

        <div class="lasergrid__meta">
          <span>
            Detection <strong>{detection}/{maxDetection}</strong>
          </span>
          <div class="lasergrid__detect" aria-hidden="true">
            {#each { length: maxDetection } as _, i}
              <span class={["lasergrid__pip", i < detection ? "lasergrid__pip--on" : ""]}></span>
            {/each}
          </div>
        </div>
      </div>
    </div>

    <div class="mg__footer">WASD - slip through the gaps to EXIT - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
