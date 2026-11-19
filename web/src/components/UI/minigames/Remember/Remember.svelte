<script lang="ts">
  import { untrack } from "svelte";
  import Flame from "@lucide/svelte/icons/flame";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { RememberConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Remember.css";

  let { config: configProp }: { config: RememberConfig } = $props();

  const config = untrack(() => configProp);

  type Phase = "preview" | "input";

  function cellKey(i: number) {
    return String(i);
  }

  function pickTargets(cellTotal: number, count: number): Set<string> {
    const indices = Array.from({ length: cellTotal }, (_, i) => i);
    for (let i = indices.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [indices[i], indices[j]] = [indices[j], indices[i]];
    }
    return new Set(indices.slice(0, count).map(cellKey));
  }

  const size = 5;
  const total = size * size;
  const targetCount = Math.min(total - 1, Math.max(3, config.targets));
  const maxLives = Math.max(1, config.lives);
  const previewMs = Math.max(1200, config.preview);
  const duration = Math.max(5000, config.duration);
  const cells = Array.from({ length: total }, (_, i) => i);
  const lifeSlots = Array.from({ length: maxLives }, (_, i) => i);

  // regenerate only when this game instance mounts / config changes
  const targets = pickTargets(total, targetCount);

  let phase = $state<Phase>("preview");
  let selected = $state<Set<string>>(new Set());
  let livesLeft = $state(maxLives);
  let wrongId = $state<string | null>(null);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let phaseRef: Phase = "preview";
  let selectedRef = untrack(() => selected);
  let livesRef = maxLives;
  let phaseStartRef = performance.now();

  const secondsLeft = $derived(
    ((progress / 100) * (phase === "preview" ? previewMs : duration)) / 1000
  );
  const subtitle = $derived(phase === "preview" ? "Memorize" : "Recall");
  const footer = $derived(
    phase === "preview" ? "Watch the pattern - Esc" : "Click the same cells - Esc"
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function onCellClick(index: number) {
    if (finishedRef || phaseRef !== "input") return;

    const key = cellKey(index);
    if (selectedRef.has(key)) return;

    if (targets.has(key)) {
      const next = new Set(selectedRef);
      next.add(key);
      selectedRef = next;
      selected = next;

      if (next.size >= targets.size) {
        window.setTimeout(() => void endGame(true), 160);
      }
      return;
    }

    wrongId = key;
    window.setTimeout(() => (wrongId = null), 280);

    const left = livesRef - 1;
    livesRef = left;
    livesLeft = left;
    if (left <= 0) {
      void endGame(false);
    }
  }

  // Preview → input transition
  $effect(() => {
    phaseRef = "preview";
    phase = "preview";
    phaseStartRef = performance.now();
    progress = 100;

    const id = window.setTimeout(() => {
      if (finishedRef) return;
      phaseRef = "input";
      phase = "input";
      selected = new Set();
      selectedRef = new Set();
      phaseStartRef = performance.now();
      progress = 100;
    }, previewMs);

    return () => window.clearTimeout(id);
  });

  // Timer for current phase
  $effect(() => {
    const currentPhase = phase;
    let raf = 0;
    const span = currentPhase === "preview" ? previewMs : duration;

    const tick = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - phaseStartRef;
      const left = Math.max(0, 100 - (elapsed / span) * 100);
      progress = left;

      if (left <= 0) {
        if (currentPhase === "preview") {
          // handoff handled by timeout; keep bar at 0 briefly
          return;
        }
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
  <div class="mg__card remember__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Flame class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Remember</span>
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
      <div
        class="remember__grid"
        style="grid-template-columns: repeat({size}, minmax(0, 1fr)); grid-template-rows: repeat({size}, minmax(0, 1fr))"
      >
        {#each cells as i}
          {@const key = cellKey(i)}
          {@const showTarget = phase === "preview" && targets.has(key)}
          {@const isPicked = selected.has(key)}
          {@const isWrong = wrongId === key}
          <button
            type="button"
            aria-label={`Cell ${key}`}
            class={[
              "remember__cell",
              showTarget || isPicked ? "remember__cell--lit" : "",
              isWrong ? "remember__cell--wrong" : "",
            ]}
            disabled={finished || phase !== "input"}
            onclick={() => onCellClick(i)}
          ></button>
        {/each}
      </div>

      {#if maxLives > 1}
        <div class="remember__lives" aria-label="{livesLeft} lives">
          {#each lifeSlots as i}
            <span class={["remember__life", i < livesLeft ? "" : "remember__life--lost"]}></span>
          {/each}
        </div>
      {/if}
    </div>

    <div class="mg__footer">{footer}</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
