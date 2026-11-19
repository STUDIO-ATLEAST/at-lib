<script lang="ts">
  import { untrack } from "svelte";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { BinaryConfig } from "../../../../types/minigame";
  import "./Binary.css";

  let { config: configProp }: { config: BinaryConfig } = $props();

  const config = untrack(() => configProp);

  type Phase = "preview" | "input";

  function asBits(list: number[] | undefined, len: number): number[] {
    const out: number[] = [];
    for (let i = 0; i < len; i++) {
      out.push(list?.[i] ? 1 : 0);
    }
    return out;
  }

  function reverseBits(bits: number[]) {
    return [...bits].reverse();
  }

  function bitsEqual(a: number[], b: number[]) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) return false;
    }
    return true;
  }

  const length = $derived(
    Math.min(16, Math.max(4, config.sequence?.length || 8))
  );
  const sequence = $derived(asBits(config.sequence, length));
  const rows = $derived.by(() => {
    const source =
      Array.isArray(config.rows) && config.rows.length > 0
        ? config.rows
        : [sequence];
    return source.map((row) => asBits(row, length));
  });
  const correctRow = $derived(
    Math.min(rows.length - 1, Math.max(0, config.correctRow ?? 0))
  );
  const previewMs = $derived(Math.max(800, config.preview));
  const reverse = $derived(!!config.reverse);
  const glitches = $derived(!!config.glitches);
  const duration = $derived(Math.max(10000, config.duration));
  const expected = $derived(reverse ? reverseBits(sequence) : sequence);

  let phase = $state<Phase>("preview");
  let entry = $state<(0 | 1 | null)[]>(Array(8).fill(null));
  let cursor = $state(0);
  let glitchMask = $state<boolean[][]>([]);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let phaseRef: Phase = "preview";
  let entryRef: (0 | 1 | null)[] = Array(8).fill(null);
  let startRef = performance.now();

  const subtitle = $derived(
    result !== null
      ? result
        ? "Accepted"
        : "Rejected"
      : phase === "preview"
        ? "Memorize"
        : reverse
          ? "Enter reversed"
          : "Enter code"
  );
  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function submit() {
    if (finishedRef || phaseRef !== "input") return;
    const current = entryRef;
    if (current.some((bit) => bit === null)) return;
    void endGame(bitsEqual(current as number[], expected));
  }

  function writeBit(value: 0 | 1, at?: number) {
    if (finishedRef || phaseRef !== "input") return;
    const i = at ?? cursor;
    if (i < 0 || i >= entry.length) return;
    const next = [...entry];
    next[i] = value;
    entryRef = next;
    entry = next;
    cursor = Math.min(length - 1, i + 1);
  }

  function backspace() {
    if (finishedRef || phaseRef !== "input") return;
    const next = [...entry];
    const i = next[cursor] !== null ? cursor : Math.max(0, cursor - 1);
    next[i] = null;
    entryRef = next;
    entry = next;
    cursor = i;
  }

  function toggleBit(i: number, bit: 0 | 1 | null) {
    cursor = i;
    const next = bit === 1 ? 0 : 1;
    writeBit(next as 0 | 1, i);
  }

  $effect(() => {
    const len = length;
    void previewMs;
    void duration;
    void reverse;
    void glitches;
    void sequence;
    const mask = rows.map((row) => row.map(() => false));
    phase = "preview";
    phaseRef = "preview";
    const blank = Array(len).fill(null) as (0 | 1 | null)[];
    entry = blank;
    entryRef = blank;
    cursor = 0;
    glitchMask = mask;
    finished = false;
    result = null;
    finishedRef = false;
    startRef = performance.now();
    progress = 100;
    runId = untrack(() => runId) + 1;
  });

  $effect(() => {
    if (phase !== "preview" || !glitches || finished) return;
    void runId;
    const rowList = rows;
    const goodRow = correctRow;
    const id = window.setInterval(() => {
      glitchMask = rowList.map((row, rowIndex) =>
        row.map(() =>
          Math.random() < (rowIndex === goodRow ? 0.08 : 0.22)
        )
      );
    }, 140);
    return () => window.clearInterval(id);
  });

  $effect(() => {
    const total = phase === "preview" ? previewMs : duration;
    void runId;
    void expected;
    const rowList = rows;
    startRef = performance.now();
    progress = 100;

    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - startRef;
      const left = Math.max(0, 100 - (elapsed / total) * 100);
      progress = left;

      if (left <= 0) {
        if (phaseRef === "preview") {
          phase = "input";
          phaseRef = "input";
          glitchMask = rowList.map((row) => row.map(() => false));
          return;
        }
        const current = entryRef;
        const ok =
          current.every((bit) => bit !== null) &&
          bitsEqual(current as number[], expected);
        void endGame(ok);
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
      if (phaseRef !== "input") return;

      if (e.code === "Digit0" || e.code === "Numpad0") {
        e.preventDefault();
        writeBit(0);
        return;
      }
      if (e.code === "Digit1" || e.code === "Numpad1") {
        e.preventDefault();
        writeBit(1);
        return;
      }
      if (e.code === "Backspace") {
        e.preventDefault();
        backspace();
        return;
      }
      if (e.code === "ArrowLeft") {
        e.preventDefault();
        cursor = Math.max(0, cursor - 1);
        return;
      }
      if (e.code === "ArrowRight") {
        e.preventDefault();
        cursor = Math.min(length - 1, cursor + 1);
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
    <kbd class="mgbar__key">01</kbd>
    <div class="mgbar__chips">
      {#if phase === "preview"}
        {#each sequence as bit, i}
          {@const glitch = !!glitchMask[0]?.[i]}
          {@const value = glitch ? 1 - bit : bit}
          <span
            class={[
              "mgbar__chip",
              value === 1 ? "binary__chip--one" : "",
              glitch ? "binary__chip--glitch" : "",
            ]}
          >
            {value}
          </span>
        {/each}
      {:else if result !== null}
        {#each expected as bit}
          <span class={["mgbar__chip", bit === 1 ? "binary__chip--one" : ""]}>{bit}</span>
        {/each}
      {:else}
        {#each entry as bit, i}
          <button
            type="button"
            class={[
              "mgbar__chip",
              "binary__chip--input",
              bit === 1 ? "binary__chip--one" : "",
              i === cursor ? "mgbar__chip--current" : "",
            ]}
            disabled={finished}
            onclick={() => toggleBit(i, bit)}
          >
            {bit === null ? "-" : bit}
          </button>
        {/each}
      {/if}
    </div>
    <span class="mgbar__count binary__label">{subtitle}</span>
    <div class="mgbar__timer">
      <div class="mgbar__timer-fill" style="width: {progress}%"></div>
    </div>
  </div>
</div>
