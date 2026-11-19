<script lang="ts">
  import { untrack } from "svelte";
  import Cable from "@lucide/svelte/icons/cable";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import { uiScale } from "../../../../lib/uiScale";
  import type { WiresConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Wires.css";

  let { config: configProp }: { config: WiresConfig } = $props();

  const config = untrack(() => configProp);

  type WireColor = {
    id: string;
    color: string;
  };

  type DragState = {
    fromId: string;
    x: number;
    y: number;
  };

  const PALETTE: WireColor[] = [
    { id: "red", color: "#ff8787" },
    { id: "blue", color: "#4dabf7" },
    { id: "yellow", color: "#ffd43b" },
    { id: "pink", color: "#f783ac" },
    { id: "orange", color: "#ffa94d" },
  ];

  function shuffle<T>(list: T[]): T[] {
    const arr = [...list];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  function curvePath(x1: number, y1: number, x2: number, y2: number) {
    const mx = (x1 + x2) / 2;
    return `M ${x1} ${y1} C ${mx} ${y1}, ${mx} ${y2}, ${x2} ${y2}`;
  }

  const wireCount = $derived(Math.min(5, Math.max(3, config.wires)));
  const duration = $derived(Math.max(10000, config.duration));

  const layout = $derived.by(() => {
    void config.duration;
    const left = PALETTE.slice(0, wireCount);
    const right = shuffle(left);
    return { left, right };
  });

  let connected = $state<Set<string>>(new Set());
  let drag = $state<DragState | null>(null);
  let hoverTarget = $state<string | null>(null);
  let wrongFlash = $state(false);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let anchors = $state<Record<string, { x: number; y: number }>>({});

  let finishedRef = false;
  let connectedRef = new Set<string>();
  let dragRef: DragState | null = null;
  let boardEl: HTMLDivElement | null = null;
  let nodeEls: Record<string, HTMLButtonElement | null> = {};
  let startRef = performance.now();

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  const doneLines = $derived(
    layout.left
      .filter((w) => connected.has(w.id))
      .map((w) => {
        const a = anchors[`L:${w.id}`];
        const b = anchors[`R:${w.id}`];
        if (!a || !b) return null;
        return { id: w.id, color: w.color, d: curvePath(a.x, a.y, b.x, b.y) };
      })
      .filter((line): line is { id: string; color: string; d: string } => !!line)
  );

  const dragLine = $derived.by(() => {
    if (!drag) return null;
    const a = anchors[`L:${drag.fromId}`];
    if (!a) return null;
    const color = layout.left.find((w) => w.id === drag.fromId)?.color ?? "#f1f3f5";
    return {
      color,
      d: curvePath(a.x, a.y, drag.x, drag.y),
    };
  });

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    drag = null;
    dragRef = null;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function measureAnchors() {
    const board = boardEl;
    if (!board) return;
    const rect = board.getBoundingClientRect();
    const next: Record<string, { x: number; y: number }> = {};

    for (const side of ["L", "R"] as const) {
      for (const wire of side === "L" ? layout.left : layout.right) {
        const key = `${side}:${wire.id}`;
        const el = nodeEls[key];
        if (!el) continue;
        const r = el.getBoundingClientRect();
        next[key] = {
          x: (r.left + r.width / 2 - rect.left) / uiScale,
          y: (r.top + r.height / 2 - rect.top) / uiScale,
        };
      }
    }
    anchors = next;
  }

  function bindWireNode(node: HTMLButtonElement, key: string) {
    nodeEls[key] = node;
    return {
      update(nextKey: string) {
        if (nodeEls[key] === node) nodeEls[key] = null;
        key = nextKey;
        nodeEls[key] = node;
      },
      destroy() {
        if (nodeEls[key] === node) nodeEls[key] = null;
      },
    };
  }

  $effect(() => {
    void layout;
    connected = new Set();
    connectedRef = new Set();
    drag = null;
    dragRef = null;
    hoverTarget = null;
    wrongFlash = false;
    finished = false;
    result = null;
    finishedRef = false;
    startRef = performance.now();
    progress = 100;

    const t = window.setTimeout(measureAnchors, 30);
    window.addEventListener("resize", measureAnchors);
    return () => {
      window.clearTimeout(t);
      window.removeEventListener("resize", measureAnchors);
    };
  });

  $effect(() => {
    void layout;
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

  function boardPoint(clientX: number, clientY: number) {
    const board = boardEl;
    if (!board) return { x: 0, y: 0 };
    const rect = board.getBoundingClientRect();
    return {
      x: (clientX - rect.left) / uiScale,
      y: (clientY - rect.top) / uiScale,
    };
  }

  function onLeftDown(e: PointerEvent, id: string) {
    if (finishedRef || connectedRef.has(id)) return;
    e.preventDefault();
    (e.currentTarget as Element).setPointerCapture?.(e.pointerId);
    const pt = boardPoint(e.clientX, e.clientY);
    const next = { fromId: id, x: pt.x, y: pt.y };
    dragRef = next;
    drag = next;
  }

  function onBoardMove(e: PointerEvent) {
    if (!dragRef || finishedRef) return;
    const pt = boardPoint(e.clientX, e.clientY);
    const next = { ...dragRef, x: pt.x, y: pt.y };
    dragRef = next;
    drag = next;

    const el = document.elementFromPoint(e.clientX, e.clientY);
    const target = el?.closest<HTMLElement>("[data-wire-target]");
    const tid = target?.dataset.wireTarget ?? null;
    hoverTarget = tid && !connectedRef.has(tid) ? tid : null;
  }

  function finishDrag(targetId: string | null) {
    const current = dragRef;
    dragRef = null;
    drag = null;
    hoverTarget = null;
    if (!current || finishedRef) return;

    if (!targetId || connectedRef.has(targetId)) {
      return;
    }

    if (targetId !== current.fromId) {
      wrongFlash = true;
      window.setTimeout(() => (wrongFlash = false), 220);
      return;
    }

    const next = new Set(connectedRef);
    next.add(targetId);
    connectedRef = next;
    connected = next;

    if (next.size >= wireCount) {
      window.setTimeout(() => void endGame(true), 180);
    }
  }

  function onBoardUp(e: PointerEvent) {
    if (!dragRef) return;
    const el = document.elementFromPoint(e.clientX, e.clientY);
    const target = el?.closest<HTMLElement>("[data-wire-target]");
    finishDrag(target?.dataset.wireTarget ?? null);
  }
</script>

<div class="mg">
  <div class="mg__card wires__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Cable class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Wires</span>
        <span class="mg__subtitle">{connected.size} / {wireCount}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div
        bind:this={boardEl}
        role="presentation"
        class={["wires__board", wrongFlash ? "wires__board--wrong" : ""]}
        onpointermove={onBoardMove}
        onpointerup={onBoardUp}
        onpointerleave={() => {
          if (dragRef) finishDrag(null);
        }}
      >
        <svg class="wires__svg" aria-hidden="true">
          {#each doneLines as line (line.id)}
            <path
              class="wires__line wires__line--done"
              d={line.d}
              stroke={line.color}
            />
          {/each}
          {#if dragLine}
            <path
              class="wires__line wires__line--drag"
              d={dragLine.d}
              stroke={dragLine.color}
            />
          {/if}
        </svg>

        <div class="wires__cols">
          <div class="wires__col">
            {#each layout.left as wire (`L:${wire.id}`)}
              {@const done = connected.has(wire.id)}
              {@const active = drag?.fromId === wire.id}
              <button
                type="button"
                use:bindWireNode={`L:${wire.id}`}
                aria-label={`Wire ${wire.id} left`}
                class={[
                  "wires__node",
                  "wires__node--left",
                  done ? "wires__node--done" : "",
                  active ? "wires__node--active" : "",
                ]}
                style="--wire-color: {wire.color}"
                disabled={finished || done}
                onpointerdown={(e) => onLeftDown(e, wire.id)}
              ></button>
            {/each}
          </div>

          <div class="wires__col">
            {#each layout.right as wire (`R:${wire.id}`)}
              {@const done = connected.has(wire.id)}
              {@const hot = hoverTarget === wire.id && !!drag}
              <button
                type="button"
                use:bindWireNode={`R:${wire.id}`}
                data-wire-target={wire.id}
                aria-label={`Wire ${wire.id} right`}
                class={[
                  "wires__node",
                  "wires__node--right",
                  "wires__node--target",
                  done ? "wires__node--done" : "",
                  hot ? "wires__node--hot" : "",
                ]}
                style="--wire-color: {wire.color}"
                disabled={finished || done}
              ></button>
            {/each}
          </div>
        </div>
      </div>
    </div>

    <div class="mg__footer">Match colors - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
