<script lang="ts">
  import { untrack } from "svelte";
  import Binary from "@lucide/svelte/icons/binary";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { DecryptConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Decrypt.css";

  let { config: configProp }: { config: DecryptConfig } = $props();

  const config = untrack(() => configProp);

  const CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#@%&!";
  const LOG_LINES = 6;

  function randChar() {
    return CHARSET[Math.floor(Math.random() * CHARSET.length)] ?? "x";
  }

  function buildToken(len: number) {
    let out = "";
    for (let i = 0; i < len; i++) out += randChar();
    return out;
  }

  function buildLogLine() {
    return `> ${buildToken(14 + Math.floor(Math.random() * 10))}`;
  }

  const rounds = config.rounds;
  const tokenLength = config.tokenLength;
  const duration = Math.max(5000, config.duration);

  let round = $state(0);
  let token = $state(buildToken(tokenLength));
  let typed = $state("");
  let logLines = $state(Array.from({ length: LOG_LINES }, () => buildLogLine()));
  let progress = $state(100);
  let wrong = $state(false);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let inputEl = $state<HTMLInputElement | undefined>(undefined);

  let finishedRef = false;
  let roundRef = 0;
  let tokenRef = untrack(() => token);
  let typedRef = "";
  let logRef = untrack(() => logLines);
  let startRef = performance.now();

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function nextToken(nextRound: number) {
    const fresh = buildToken(tokenLength);
    tokenRef = fresh;
    token = fresh;
    typedRef = "";
    typed = "";
    roundRef = nextRound;
    round = nextRound;
    inputEl?.focus();
  }

  function submit() {
    if (finishedRef) return;

    if (typedRef !== tokenRef) {
      wrong = true;
      window.setTimeout(() => (wrong = false), 280);
      void endGame(false);
      return;
    }

    const next = roundRef + 1;
    if (next >= rounds) {
      void endGame(true);
      return;
    }

    nextToken(next);
  }

  function onTypedInput(e: Event) {
    typedRef = (e.currentTarget as HTMLInputElement).value;
  }

  // Terminal keeps generating while hacking - input stays player-typed
  $effect(() => {
    const id = window.setInterval(() => {
      if (finishedRef) return;
      const next = [...logRef.slice(1), buildLogLine()];
      logRef = next;
      logLines = next;
    }, 160);
    return () => window.clearInterval(id);
  });

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
    void round;
    inputEl?.focus();
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;

      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }

      if (e.code === "Enter") {
        e.preventDefault();
        submit();
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Binary class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Decrypt</span>
        <span class="mg__subtitle">{Math.min(round + 1, rounds)} / {rounds}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="decrypt__log">
        {#each logLines as line, i (`${i}-${line.slice(0, 6)}`)}
          <div class="decrypt__log-line">{line}</div>
        {/each}
      </div>

      <div class="decrypt__token-block">
        <div class="decrypt__token-label">Decrypt token</div>
        <div class="decrypt__token">{token}</div>
        <!-- svelte-ignore a11y_autofocus -->
        <input
          bind:this={inputEl}
          class={["decrypt__input", wrong ? "decrypt__input--wrong" : ""]}
          bind:value={typed}
          autofocus
          spellcheck={false}
          autocomplete="off"
          disabled={finished}
          placeholder="Type token"
          oninput={onTypedInput}
        />
      </div>
    </div>

    <div class="mg__footer">Type token - Enter - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
