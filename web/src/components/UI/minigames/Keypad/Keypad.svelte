<script lang="ts">
  import { untrack } from "svelte";
  import Check from "@lucide/svelte/icons/check";
  import Delete from "@lucide/svelte/icons/delete";
  import Keyboard from "@lucide/svelte/icons/keyboard";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { KeypadConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Keypad.css";

  let { config: configProp }: { config: KeypadConfig } = $props();

  const config = untrack(() => configProp);

  type PipKind = "spot" | "digit" | "miss";

  type HistoryRow = {
    guess: number[];
    marks: PipKind[];
  };

  /** Per-position marks: pip i matches guess digit i. */
  function scoreGuess(secret: number[], guess: number[]): { marks: PipKind[]; spot: number } {
    const marks: PipKind[] = Array(secret.length).fill("miss");
    const codeLeft = Array(10).fill(0);

    for (let i = 0; i < secret.length; i++) {
      if (guess[i] === secret[i]) {
        marks[i] = "spot";
      } else {
        codeLeft[secret[i]] += 1;
      }
    }

    for (let i = 0; i < secret.length; i++) {
      if (marks[i] === "spot") continue;
      const d = guess[i];
      if (codeLeft[d] > 0) {
        marks[i] = "digit";
        codeLeft[d] -= 1;
      }
    }

    const spot = marks.filter((m) => m === "spot").length;
    return { marks, spot };
  }

  const length = config.length;
  const maxTries = config.tries;
  const duration = Math.max(5000, config.duration);
  const code = config.code.map((n) => n % 10);
  const padKeys = [1, 2, 3, 4, 5, 6, 7, 8, 9] as const;
  const slots = Array.from({ length }, (_, i) => i);

  let entry = $state<number[]>([]);
  let history = $state<HistoryRow[]>([]);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let startRef = performance.now();
  let entryRef: number[] = [];
  let historyRef: HistoryRow[] = [];

  const tryNum = $derived(Math.min(history.length + 1, maxTries));
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function submit() {
    if (finishedRef) return;
    if (entryRef.length !== length) return;
    if (historyRef.length >= maxTries) return;

    const guess = [...entryRef];
    const { marks, spot } = scoreGuess(code, guess);
    const row = { guess, marks };
    const nextHistory = [...historyRef, row];
    historyRef = nextHistory;
    history = nextHistory;
    entryRef = [];
    entry = [];

    if (spot === length) {
      void endGame(true);
      return;
    }

    if (nextHistory.length >= maxTries) {
      void endGame(false);
    }
  }

  function pushDigit(digit: number) {
    if (finishedRef) return;
    if (entryRef.length >= length) return;
    const next = [...entryRef, digit];
    entryRef = next;
    entry = next;
  }

  function backspace() {
    if (finishedRef) return;
    if (entryRef.length === 0) return;
    const next = entryRef.slice(0, -1);
    entryRef = next;
    entry = next;
  }

  $effect(() => {
    startRef = performance.now();
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
        return;
      }

      if (e.code === "Backspace") {
        e.preventDefault();
        backspace();
        return;
      }

      if (e.code === "Enter") {
        e.preventDefault();
        submit();
        return;
      }

      if (/^[0-9]$/.test(e.key)) {
        e.preventDefault();
        pushDigit(Number(e.key));
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card keypad__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Keyboard class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Keypad</span>
        <span class="mg__subtitle">{tryNum} / {maxTries}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="keypad__layout">
        <div class="keypad__col">
          <div class="keypad__label">Entry</div>
          <div class="keypad__controls">
            <div class="keypad__slots">
              {#each slots as i}
                <div class="keypad__slot">
                  {#if entry[i] !== undefined}
                    {entry[i]}
                  {:else}
                    <span class="keypad__slot-dot"></span>
                  {/if}
                </div>
              {/each}
            </div>

            <div class="keypad__pad">
              {#each padKeys as n}
                <button
                  type="button"
                  class="keypad__btn"
                  disabled={finished}
                  onclick={() => pushDigit(n)}
                >
                  {n}
                </button>
              {/each}
              <button
                type="button"
                class="keypad__btn keypad__btn--action"
                disabled={finished}
                onclick={backspace}
              >
                <Delete style={iconSize(1.3)} strokeWidth={1.75} />
              </button>
              <button
                type="button"
                class="keypad__btn"
                disabled={finished}
                onclick={() => pushDigit(0)}
              >
                0
              </button>
              <button
                type="button"
                class="keypad__btn keypad__btn--action"
                disabled={finished || entry.length !== length}
                onclick={submit}
              >
                <Check style={iconSize(1.3)} strokeWidth={2.25} />
              </button>
            </div>
          </div>
        </div>

        <div class="keypad__divider" aria-hidden="true"></div>

        <div class="keypad__col keypad__col--history">
          <div class="keypad__label">History</div>
          <div class="keypad__history">
            {#if history.length === 0}
              <div class="keypad__empty">No attempts yet</div>
            {/if}
            {#each history as row}
              <div
                class="keypad__row"
                style="grid-template-columns: repeat({row.guess.length}, 1fr)"
              >
                {#each row.guess as d, di}
                  <div class="keypad__cell">
                    <span class="keypad__guess-digit">{d}</span>
                    <span
                      class="keypad__pip keypad__pip--{row.marks[di]}"
                      title={row.marks[di] === "spot"
                        ? "Correct position"
                        : row.marks[di] === "digit"
                          ? "Wrong position"
                          : "Not in code"}
                    ></span>
                  </div>
                {/each}
              </div>
            {/each}
          </div>
        </div>
      </div>
    </div>

    <div class="mg__footer">0-9 - Enter - Backspace - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
