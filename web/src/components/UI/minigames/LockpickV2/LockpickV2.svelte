<script lang="ts">
  import { untrack } from "svelte";
  import Lock from "@lucide/svelte/icons/lock";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { LockpickV2Config } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./LockpickV2.css";

  let { config: configProp }: { config: LockpickV2Config } = $props();

  const config = untrack(() => configProp);

  const SIZE = 100;
  const CX = 50;
  const CY = 50;
  const R = 40;
  const PROGRESS_C = 2 * Math.PI * 30;
  const GAP_DEG = 3; // visual gap between segments

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

  type SegmentKind = "green" | "red" | "empty";

  /** Place greens so no two share an edge on the ring - neighbors stay red.
   *  Empties only fill leftover red slots that aren't forced separators. */
  function assignSegments(
    total: number,
    greens: number,
    emptiesWanted: number
  ): SegmentKind[] {
    const maxGreen = Math.max(1, Math.floor(total / 2));
    const greensWanted = Math.min(Math.max(1, greens), maxGreen);

    const kinds: SegmentKind[] = new Array(total).fill("red");
    const order = Array.from({ length: total }, (_, i) => i);
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }

    const placed: number[] = [];
    for (const idx of order) {
      if (placed.length >= greensWanted) break;
      const ok = placed.every((g) => {
        const d = Math.abs(g - idx);
        return d !== 1 && d !== total - 1;
      });
      if (!ok) continue;
      placed.push(idx);
      kinds[idx] = "green";
    }

    // Force red between greens (circular).
    const lockedRed = new Set<number>();
    for (const g of placed) {
      lockedRed.add((g - 1 + total) % total);
      lockedRed.add((g + 1) % total);
    }
    for (const idx of lockedRed) {
      if (kinds[idx] !== "green") kinds[idx] = "red";
    }

    const fillable = order.filter(
      (i) => kinds[i] === "red" && !lockedRed.has(i)
    );
    const empties = Math.min(Math.max(0, emptiesWanted), fillable.length);
    for (let i = 0; i < empties; i++) kinds[fillable[i]] = "empty";

    return kinds;
  }

  const segments = $derived(Math.max(4, config.segments));
  // Ring can't fit more greens than floor(n/2) without two greens sharing an edge.
  const greenCount = $derived(
    Math.max(1, Math.min(Math.floor(segments / 2), config.greenCount))
  );
  const emptyCount = $derived(
    Math.max(0, Math.min(segments - greenCount * 2, config.emptyCount))
  );
  const speed = $derived(Math.max(40, config.speed));
  const maxLives = $derived(Math.max(1, config.lives));
  // 0 = no overall timer (default): lives end the game
  const duration = $derived((config.duration ?? 0) > 0 ? Math.max(6000, config.duration) : 0);
  const segmentSpan = $derived(360 / segments);

  const startSegments = Math.max(4, config.segments);
  const startGreen = Math.max(
    1,
    Math.min(Math.floor(startSegments / 2), config.greenCount)
  );
  const startEmpty = Math.max(
    0,
    Math.min(startSegments - startGreen * 2, config.emptyCount)
  );
  let segmentKinds = $state<SegmentKind[]>(
    assignSegments(startSegments, startGreen, startEmpty)
  );
  let hitSegments = $state<Set<number>>(new Set());
  let livesLeft = $state(Math.max(1, config.lives));
  let needle = $state(0);
  let flash = $state<"hit" | "miss" | "repeat" | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let stoppedRef = false;
  let needleRef = 0;
  let hitRef = new Set<number>();
  let livesRef = Math.max(1, config.lives);
  let startRef = performance.now();
  let lastRef = performance.now();
  let lockInputRef = false;

  const fillPct = $derived(Math.round((hitSegments.size / greenCount) * 100));
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const segmentArcs = $derived(
    Array.from({ length: segments }, (_, i) => {
      const start = i * segmentSpan + GAP_DEG / 2;
      const span = segmentSpan - GAP_DEG;
      const kind = segmentKinds[i];
      const isHit = hitSegments.has(i);
      return {
        i,
        path: describeArc(start, Math.max(1, span)),
        kind: kind === "green" ? (isHit ? "done" : "green") : kind,
      } as const;
    })
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  $effect(() => {
    segmentKinds = assignSegments(segments, greenCount, emptyCount);
    hitSegments = new Set();
    hitRef = new Set();
    livesLeft = maxLives;
    livesRef = maxLives;
    needle = 0;
    needleRef = 0;
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
  });

  $effect(() => {
    void duration;
    void speed;
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef || stoppedRef) return;
      const dt = Math.min(0.05, (now - lastRef) / 1000);
      lastRef = now;

      needleRef = normalize(needleRef + speed * dt);
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

    const idx = Math.floor(normalize(needleRef) / segmentSpan) % segments;
    const kind = segmentKinds[idx];
    const already = hitRef.has(idx);

    if (kind === "green" && !already) {
      const next = new Set(hitRef);
      next.add(idx);
      hitRef = next;
      hitSegments = next;
      flash = "hit";

      if (next.size >= greenCount) {
        stoppedRef = true;
        window.setTimeout(() => void endGame(true), 260);
        return;
      }

      window.setTimeout(() => {
        flash = null;
        lockInputRef = false;
      }, 200);
      return;
    }

    if (kind === "green" && already) {
      // Already filled - neutral, no penalty, just a soft acknowledgement.
      flash = "repeat";
      window.setTimeout(() => {
        flash = null;
        lockInputRef = false;
      }, 180);
      return;
    }

    if (kind === "empty") {
      // Neutral filler - no penalty, no progress, just a quick unlock of input.
      window.setTimeout(() => {
        lockInputRef = false;
      }, 120);
      return;
    }

    // Red segment.
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
  <div class="mg__card lockpickv2__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Lock class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Lockpick</span>
        <span class="mg__subtitle">{hitSegments.size}/{greenCount}</span>
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
          "lockpickv2__stage",
          flash === "miss" ? "lockpickv2__stage--miss" : "",
          flash === "hit" ? "lockpickv2__stage--hit" : "",
          flash === "repeat" ? "lockpickv2__stage--repeat" : "",
        ]}
        role="img"
        aria-label="Lockpick - press E or Space when the needle crosses a green segment"
      >
        <svg class="lockpickv2__svg" viewBox="0 0 {SIZE} {SIZE}">
          <circle class="lockpickv2__track" cx={CX} cy={CY} r={R} fill="none" />

          {#each segmentArcs as seg (seg.i)}
            <path
              class={`lockpickv2__segment lockpickv2__segment--${seg.kind}`}
              d={seg.path}
              fill="none"
            />
          {/each}

          <circle class="lockpickv2__core" cx={CX} cy={CY} r="26" />
          <circle class="lockpickv2__core-ring" cx={CX} cy={CY} r="26" fill="none" />
          <circle
            class="lockpickv2__progress-track"
            cx={CX}
            cy={CY}
            r="30"
            fill="none"
          />
          <circle
            class="lockpickv2__progress"
            cx={CX}
            cy={CY}
            r="30"
            fill="none"
            stroke-dasharray="{(fillPct / 100) * PROGRESS_C} {PROGRESS_C}"
            transform="rotate(-90 {CX} {CY})"
          />

          <g class="lockpickv2__needle" transform="rotate({needle} {CX} {CY})">
            <path
              class="lockpickv2__needle-body"
              d="M {CX} {CY - 45} L {CX - 1.6} {CY - 22} L {CX + 1.6} {CY - 22} Z"
            />
            <circle class="lockpickv2__needle-tip" cx={CX} cy={CY - 45} r="2.4" />
          </g>

          <foreignObject x={CX - 15} y={CY - 15} width="30" height="30">
            <div class="lockpickv2__lock-wrap">
              <Lock
                class="lockpickv2__lock-icon lockpickv2__lock-icon--base"
                size={22}
                strokeWidth={1.8}
              />
              <div
                class="lockpickv2__lock-fill"
                style="clip-path: inset({100 - fillPct}% 0 0 0)"
              >
                <Lock
                  class="lockpickv2__lock-icon lockpickv2__lock-icon--fill"
                  size={22}
                  strokeWidth={1.8}
                />
              </div>
            </div>
          </foreignObject>
        </svg>
      </div>

      {#if maxLives > 1}
        <div class="lockpickv2__lives" aria-label="{livesLeft} lives">
          {#each { length: maxLives } as _, i}
            <span
              class={`lockpickv2__life${i < livesLeft ? "" : " lockpickv2__life--lost"}`}
            ></span>
          {/each}
        </div>
      {/if}
    </div>

    <div class="mg__footer">
      Press E or Space on green - avoid red - Esc to cancel
    </div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
