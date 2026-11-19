<script lang="ts">
  import { untrack } from "svelte";
  import CircuitBoard from "@lucide/svelte/icons/circuit-board";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { CircuitConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import {
    cloneTiles,
    generateCircuit,
    isSolved,
    openings,
    poweredSet,
    type CircuitTile,
    E,
    N,
    S,
    W,
  } from "./circuitLogic.ts";
  import { iconSize } from "../../../../utils/vp";
  import "./Circuit.css";

  let { config: configProp }: { config: CircuitConfig } = $props();

  const config = untrack(() => configProp);

  const size = $derived(Math.min(6, Math.max(3, config.size)));
  const duration = $derived(Math.max(12000, config.duration));
  const maxRotations = $derived(Math.max(0, config.maxRotations));
  const seed = $derived(config.seed ?? 1);
  const puzzle = $derived(
    generateCircuit({
      size,
      sources: config.sources,
      outputs: config.outputs,
      dangers: config.dangers,
      seed,
    })
  );

  let tiles = $state<CircuitTile[][]>([]);
  let rotationsLeft = $state<number | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let tilesRef: CircuitTile[][] = [];
  let startRef = performance.now();

  const powered = $derived(poweredSet(tiles));
  const solved = $derived(isSolved(tiles));
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const outputsOn = $derived.by(() => {
    let total = 0;
    let on = 0;
    for (let row = 0; row < tiles.length; row++) {
      for (let col = 0; col < tiles[row].length; col++) {
        if (tiles[row][col].kind !== "output") continue;
        total += 1;
        if (powered.has(`${row},${col}`)) on += 1;
      }
    }
    return { on, total };
  });
  const dangerLit = $derived.by(() => {
    for (let row = 0; row < tiles.length; row++) {
      for (let col = 0; col < tiles[row].length; col++) {
        if (tiles[row][col].kind === "danger" && powered.has(`${row},${col}`)) {
          return true;
        }
      }
    }
    return false;
  });
  const subtitle = $derived(
    result !== null
      ? result
        ? "Online"
        : "Fault"
      : dangerLit
        ? "Overload"
        : solved
          ? "Complete"
          : "Route power"
  );

  function pipeArms(tile: CircuitTile): [number, number, number, number][] {
    if (tile.kind === "block") return [];
    const open = openings(tile);
    const cx = 50;
    const cy = 50;
    const arms: [number, number, number, number][] = [];
    if (open & N) arms.push([cx, cy, cx, 8]);
    if (open & E) arms.push([cx, cy, 92, cy]);
    if (open & S) arms.push([cx, cy, cx, 92]);
    if (open & W) arms.push([cx, cy, 8, cy]);
    return arms;
  }

  function trackClass(tile: CircuitTile, on: boolean) {
    const poweredCls = on ? "circuit__track--on" : "";
    if (tile.kind === "danger") {
      return `circuit__track--danger${on ? " circuit__track--on" : ""}`;
    }
    return poweredCls;
  }

  function hubClass(tile: CircuitTile, on: boolean) {
    return [
      "circuit__hub",
      tile.kind === "danger" ? "circuit__hub--danger" : "",
      on ? "circuit__hub--on" : "",
    ]
      .filter(Boolean)
      .join(" ");
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function submit() {
    if (finishedRef) return;
    void endGame(isSolved(tilesRef));
  }

  function rotateAt(row: number, col: number) {
    if (finishedRef) return;
    const tile = tilesRef[row][col];
    if (
      tile.fixed ||
      tile.kind === "block" ||
      tile.kind === "source" ||
      tile.kind === "output"
    ) {
      return;
    }
    if (rotationsLeft !== null && rotationsLeft <= 0) return;

    const next = cloneTiles(tilesRef);
    next[row][col] = { ...next[row][col], rot: (next[row][col].rot + 1) % 4 };
    tilesRef = next;
    tiles = next;
    if (rotationsLeft !== null) {
      rotationsLeft = Math.max(0, rotationsLeft - 1);
    }
  }

  $effect(() => {
    const next = cloneTiles(puzzle.tiles);
    void maxRotations;
    tiles = next;
    tilesRef = next;
    rotationsLeft = maxRotations > 0 ? maxRotations : null;
    finished = false;
    result = null;
    finishedRef = false;
    startRef = performance.now();
    progress = 100;
    runId = untrack(() => runId) + 1;
  });

  $effect(() => {
    void runId;
    const total = duration;
    startRef = performance.now();
    progress = 100;
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - startRef;
      const left = Math.max(0, 100 - (elapsed / total) * 100);
      progress = left;
      if (left <= 0) {
        void endGame(isSolved(tilesRef));
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
        return;
      }
      if (e.code === "Space" || e.code === "Enter" || e.code === "KeyE") {
        e.preventDefault();
        submit();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  $effect(() => {
    if (finished || !solved) return;
    const t = window.setTimeout(() => void endGame(true), 280);
    return () => window.clearTimeout(t);
  });
</script>

<div class="mg">
  <div class="mg__card circuit__card">
    <div class="mg__header">
      <div class="mg__heading">
        <CircuitBoard class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Circuit Flow</span>
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
      <div class="circuit__body">
        <div
          class="circuit__grid"
          style="grid-template-columns: repeat({size}, minmax(0, 1fr)); grid-template-rows: repeat({size}, minmax(0, 1fr))"
        >
          {#each tiles as row, rowIndex}
            {#each row as tile, colIndex (`${rowIndex},${colIndex}`)}
              {@const key = `${rowIndex},${colIndex}`}
              {@const on = powered.has(key)}
              {@const rotatable =
                !tile.fixed &&
                tile.kind !== "block" &&
                tile.kind !== "source" &&
                tile.kind !== "output"}
              <button
                type="button"
                class={[
                  "circuit__cell",
                  tile.kind === "block" ? "circuit__cell--block" : "",
                  tile.kind === "source" ? "circuit__cell--source" : "",
                  tile.kind === "output" ? "circuit__cell--output" : "",
                  tile.kind === "danger" ? "circuit__cell--danger" : "",
                  on ? "circuit__cell--powered" : "",
                ]}
                disabled={finished || !rotatable}
                onclick={() => rotateAt(rowIndex, colIndex)}
              >
                {#if tile.kind !== "block"}
                  <svg class="circuit__svg" viewBox="0 0 100 100" aria-hidden="true">
                    {#each pipeArms(tile) as [x1, y1, x2, y2], armIndex (armIndex)}
                      <line
                        class="circuit__track {trackClass(tile, on)}"
                        {x1}
                        {y1}
                        {x2}
                        {y2}
                      />
                    {/each}
                    <circle class={hubClass(tile, on)} cx={50} cy={50} r={9} />
                  </svg>
                {/if}
                {#if tile.kind === "source"}
                  <span class="circuit__badge circuit__badge--src">PWR</span>
                {/if}
                {#if tile.kind === "output"}
                  <span class="circuit__badge circuit__badge--out">OUT</span>
                {/if}
                {#if tile.kind === "danger"}
                  <span class="circuit__badge circuit__badge--danger">!</span>
                {/if}
              </button>
            {/each}
          {/each}
        </div>

        <div class="circuit__meta">
          <span>
            Outputs <strong>{outputsOn.on}/{outputsOn.total}</strong>
          </span>
          <span>
            {#if rotationsLeft != null}
              Rotations <strong>{rotationsLeft}</strong>
            {:else}
              Rotations <strong>∞</strong>
            {/if}
          </span>
        </div>

        <button
          type="button"
          class={["circuit__submit", solved ? "circuit__submit--ready" : ""]}
          disabled={finished}
          onclick={submit}
        >
          Confirm circuit
        </button>
      </div>
    </div>

    <div class="mg__footer">
      Click tiles to rotate - avoid ! - E / Space - Esc
    </div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
