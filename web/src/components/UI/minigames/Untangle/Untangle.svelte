<script lang="ts">
  import { untrack } from "svelte";
  import GitBranch from "@lucide/svelte/icons/git-branch";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { UntangleConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Untangle.css";

  let { config: configProp }: { config: UntangleConfig } = $props();

  const config = untrack(() => configProp);

  type Point = { x: number; y: number };
  type Edge = [number, number];

  const BOARD = 100;
  const PAD = 10;
  const NODE_R = 3.2;

  function shuffle<T>(list: T[]): T[] {
    const arr = [...list];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  function buildEdges(n: number): Edge[] {
    const edges: Edge[] = [];
    const add = (a: number, b: number) => {
      const lo = Math.min(a, b);
      const hi = Math.max(a, b);
      if (!edges.some(([x, y]) => x === lo && y === hi)) {
        edges.push([lo, hi]);
      }
    };

    // Convex cycle - planar when vertices sit in order 0..n-1.
    for (let i = 0; i < n; i++) {
      add(i, (i + 1) % n);
    }

    // Fan triangulation from vertex 0. Maximal outerplanar, so always drawable
    // with no crossings. (All i→i+2 chords made 5 dots = K5, which is impossible.)
    for (let i = 2; i <= n - 2; i++) {
      add(0, i);
    }

    return edges;
  }

  function circleLayout(n: number): Point[] {
    const cx = BOARD / 2;
    const cy = BOARD / 2;
    const r = BOARD / 2 - PAD - NODE_R;
    return Array.from({ length: n }, (_, i) => {
      const a = (Math.PI * 2 * i) / n - Math.PI / 2;
      return { x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r };
    });
  }

  function scrambleLayout(n: number): Point[] {
    // Start from a solvable circle, then permute into random board positions.
    const solved = circleLayout(n);
    const slots = shuffle(
      Array.from({ length: n }, () => {
        const x = PAD + NODE_R + Math.random() * (BOARD - 2 * (PAD + NODE_R));
        const y = PAD + NODE_R + Math.random() * (BOARD - 2 * (PAD + NODE_R));
        return { x, y };
      })
    );

    // Keep a little separation so nodes don't stack.
    for (let pass = 0; pass < 8; pass++) {
      for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
          const dx = slots[j].x - slots[i].x;
          const dy = slots[j].y - slots[i].y;
          const dist = Math.hypot(dx, dy) || 0.01;
          const min = NODE_R * 3.2;
          if (dist < min) {
            const push = ((min - dist) / 2) * (1 / dist);
            slots[i].x = clamp(slots[i].x - dx * push);
            slots[i].y = clamp(slots[i].y - dy * push);
            slots[j].x = clamp(slots[j].x + dx * push);
            slots[j].y = clamp(slots[j].y + dy * push);
          }
        }
      }
    }

    // Ensure we actually start tangled; if not, fall back to inverted circle order.
    void solved;
    return slots;
  }

  function clamp(v: number): number {
    return Math.min(BOARD - PAD - NODE_R, Math.max(PAD + NODE_R, v));
  }

  function orient(a: Point, b: Point, c: Point): number {
    return (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
  }

  function onSegment(a: Point, b: Point, c: Point): boolean {
    return (
      Math.min(a.x, b.x) - 1e-6 <= c.x &&
      c.x <= Math.max(a.x, b.x) + 1e-6 &&
      Math.min(a.y, b.y) - 1e-6 <= c.y &&
      c.y <= Math.max(a.y, b.y) + 1e-6
    );
  }

  function segmentsIntersect(p1: Point, q1: Point, p2: Point, q2: Point): boolean {
    const o1 = orient(p1, q1, p2);
    const o2 = orient(p1, q1, q2);
    const o3 = orient(p2, q2, p1);
    const o4 = orient(p2, q2, q1);

    if (o1 === 0 && onSegment(p1, q1, p2)) return true;
    if (o2 === 0 && onSegment(p1, q1, q2)) return true;
    if (o3 === 0 && onSegment(p2, q2, p1)) return true;
    if (o4 === 0 && onSegment(p2, q2, q1)) return true;

    return o1 * o2 < 0 && o3 * o4 < 0;
  }

  function shareVertex(a: Edge, b: Edge): boolean {
    return a[0] === b[0] || a[0] === b[1] || a[1] === b[0] || a[1] === b[1];
  }

  function countCrossings(pts: Point[], edgeList: Edge[]): number {
    let count = 0;
    for (let i = 0; i < edgeList.length; i++) {
      for (let j = i + 1; j < edgeList.length; j++) {
        const e1 = edgeList[i];
        const e2 = edgeList[j];
        if (shareVertex(e1, e2)) continue;
        if (
          segmentsIntersect(pts[e1[0]], pts[e1[1]], pts[e2[0]], pts[e2[1]])
        ) {
          count += 1;
        }
      }
    }
    return count;
  }

  function ensureTangled(n: number, edgeList: Edge[]): Point[] {
    const solved = circleLayout(n);
    if (countCrossings(solved, edgeList) !== 0) {
      console.warn("[at-lib] graph is not planar in convex order");
    }

    for (let attempt = 0; attempt < 24; attempt++) {
      const pts = scrambleLayout(n);
      if (countCrossings(pts, edgeList) > 0) return pts;
    }

    // Guaranteed tangle: same convex slots, shuffled node order.
    const circle = circleLayout(n);
    const order = shuffle(Array.from({ length: n }, (_, i) => i));
    return order.map((i) => ({ ...circle[i] }));
  }

  const dots = $derived(Math.min(12, Math.max(4, config.dots)));
  const duration = $derived(Math.max(30000, config.duration));
  const edges = $derived(buildEdges(dots));
  const initialPoints = $derived.by(() => {
    void config.duration;
    return ensureTangled(dots, edges);
  });

  const startPoints = untrack(() => initialPoints);
  let points = $state<Point[]>(startPoints);
  let dragging = $state<number | null>(null);
  let crossings = $state(countCrossings(startPoints, untrack(() => edges)));
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let pointsRef: Point[] = startPoints;
  let boardEl: SVGSVGElement | null = null;
  let startRef = performance.now();
  let wonRef = false;

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function recompute(next: Point[]) {
    const c = countCrossings(next, edges);
    crossings = c;
    if (c === 0 && !wonRef) {
      wonRef = true;
      window.setTimeout(() => void endGame(true), 160);
    }
  }

  $effect(() => {
    const next = initialPoints;
    points = next;
    pointsRef = next;
    dragging = null;
    finished = false;
    result = null;
    finishedRef = false;
    wonRef = false;
    recompute(next);
  });

  function clientToBoard(clientX: number, clientY: number): Point | null {
    const el = boardEl;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return null;
    return {
      x: ((clientX - rect.left) / rect.width) * BOARD,
      y: ((clientY - rect.top) / rect.height) * BOARD,
    };
  }

  function onPointerDown(index: number, e: PointerEvent) {
    if (finishedRef) return;
    e.preventDefault();
    (e.currentTarget as Element).setPointerCapture?.(e.pointerId);
    dragging = index;
  }

  function onPointerMove(e: PointerEvent) {
    if (dragging === null || finishedRef) return;
    const p = clientToBoard(e.clientX, e.clientY);
    if (!p) return;

    const dragIndex = dragging;
    const next = pointsRef.map((pt, i) =>
      i === dragIndex ? { x: clamp(p.x), y: clamp(p.y) } : pt
    );
    pointsRef = next;
    points = next;
    recompute(next);
  }

  function onPointerUp() {
    dragging = null;
  }

  $effect(() => {
    void initialPoints;
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

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card untangle__card">
    <div class="mg__header">
      <div class="mg__heading">
        <GitBranch class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Untangle</span>
        <span class="mg__subtitle">
          {crossings === 0 ? "Clear" : `${crossings} cross`}
        </span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="untangle__board-wrap">
        <svg
          bind:this={boardEl}
          role="presentation"
          class="untangle__board"
          viewBox="0 0 {BOARD} {BOARD}"
          onpointermove={onPointerMove}
          onpointerup={onPointerUp}
          onpointerleave={onPointerUp}
        >
          <defs>
            <pattern
              id="untangle-grid"
              width="8"
              height="8"
              patternUnits="userSpaceOnUse"
            >
              <path
                d="M 8 0 L 0 0 0 8"
                fill="none"
                stroke="#1f2023"
                stroke-width="0.35"
              />
            </pattern>
          </defs>
          <rect
            width={BOARD}
            height={BOARD}
            fill="url(#untangle-grid)"
            rx="2"
          />

          {#each edges as [a, b] (`${a}-${b}`)}
            {@const crossed =
              crossings > 0 &&
              edges.some((other) => {
                if (shareVertex([a, b], other)) return false;
                return segmentsIntersect(
                  points[a],
                  points[b],
                  points[other[0]],
                  points[other[1]]
                );
              })}
            <line
              x1={points[a].x}
              y1={points[a].y}
              x2={points[b].x}
              y2={points[b].y}
              class={crossed
                ? "untangle__wire untangle__wire--cross"
                : "untangle__wire"}
            />
          {/each}

          {#each points as p, i}
            <circle
              role="presentation"
              cx={p.x}
              cy={p.y}
              r={NODE_R}
              class={[
                "untangle__node",
                dragging === i ? "untangle__node--active" : "",
                crossings === 0 ? "untangle__node--clear" : "",
              ]}
              onpointerdown={(e) => onPointerDown(i, e)}
              style="pointer-events: {finished ? "none" : "auto"}"
            />
          {/each}
        </svg>
      </div>
    </div>

    <div class="mg__footer">Drag dots - no crossing wires - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
