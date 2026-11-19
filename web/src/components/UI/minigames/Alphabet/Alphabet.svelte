<script lang="ts">
  import { untrack } from "svelte";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { AlphabetConfig } from "../../../../types/minigame";
  import "./Alphabet.css";

  let { config: configProp }: { config: AlphabetConfig } = $props();

  const config = untrack(() => configProp);

  const sequence = $derived(config.sequence.map((l) => l.toUpperCase()));
  const duration = $derived(Math.max(3000, config.duration));

  let done = $state<boolean[]>([]);
  let index = $state(0);
  let progress = $state(100);
  let wrongId = $state<number | null>(null);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let indexRef = 0;
  let finishedRef = false;
  let started = performance.now();

  $effect(() => {
    done = sequence.map(() => false);
    index = 0;
    indexRef = 0;
    progress = 100;
    finished = false;
    finishedRef = false;
    result = null;
    started = performance.now();
  });

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function advance() {
    const current = indexRef;
    done = done.map((v, i) => (i === current ? true : v));
    const nextIndex = current + 1;
    indexRef = nextIndex;
    index = nextIndex;
    if (nextIndex >= sequence.length) void endGame(true);
  }

  function failAt(tileId?: number) {
    if (tileId !== undefined) {
      wrongId = tileId;
      window.setTimeout(() => (wrongId = null), 280);
    }
    void endGame(false);
  }

  function handleKey(letter: string) {
    if (finishedRef) return;
    const expected = sequence[indexRef];
    if (!expected) return;
    if (letter.toUpperCase() !== expected) {
      failAt(indexRef);
      return;
    }
    advance();
  }

  function handleClick(tileId: number) {
    if (finishedRef) return;
    if (tileId !== indexRef) {
      failAt(tileId);
      return;
    }
    advance();
  }

  $effect(() => {
    started = performance.now();
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const left = Math.max(0, 100 - ((now - started) / duration) * 100);
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
        return;
      }
      if (e.repeat) return;
      const letter = e.key.toUpperCase();
      if (!/^[A-Z]$/.test(letter)) return;
      e.preventDefault();
      handleKey(letter);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  const progressLabel = $derived(
    `${Math.min(index + 1, sequence.length)}/${sequence.length}`
  );
</script>

<div class="mgbar">
  <div
    class={[
      "mgbar__box",
      "mgbar__box--auto",
      result === true ? "mgbar__box--ok" : "",
      result === false ? "mgbar__box--fail" : "",
    ]}
  >
    <div class="mgbar__chips">
      {#each sequence as letter, i}
        {@const isDone = done[i]}
        {@const isNext = !isDone && i === index && !finished}
        <button
          type="button"
          disabled={isDone || finished}
          class={[
            "mgbar__chip",
            "alphabet__chip",
            isDone ? "mgbar__chip--done" : "",
            isNext ? "mgbar__chip--current" : "",
            wrongId === i ? "mgbar__chip--wrong" : "",
          ]}
          onclick={() => handleClick(i)}
        >
          {letter}
        </button>
      {/each}
    </div>
    <span class="mgbar__count">
      {result !== null ? (result ? "Success" : "Failed") : progressLabel}
    </span>
    <div class="mgbar__timer">
      <div class="mgbar__timer-fill" style="width: {progress}%"></div>
    </div>
  </div>
</div>
