<script lang="ts">
  import { untrack } from "svelte";
  import Palette from "@lucide/svelte/icons/palette";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { ColorMatchConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./ColorMatch.css";

  let { config: configProp }: { config: ColorMatchConfig } = $props();

  const config = untrack(() => configProp);

  type Phase = "preview" | "match";

  function clampByte(n: number) {
    return Math.min(255, Math.max(0, Math.round(n)));
  }

  function colorDistance(a: number[], b: number[]) {
    const dr = a[0] - b[0];
    const dg = a[1] - b[1];
    const db = a[2] - b[2];
    return Math.sqrt(dr * dr + dg * dg + db * db);
  }

  function rgbCss(rgb: number[]) {
    return `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`;
  }

  const target = $derived([
    clampByte(config.target[0] ?? 128),
    clampByte(config.target[1] ?? 128),
    clampByte(config.target[2] ?? 128),
  ]);
  const previewMs = $derived(Math.max(800, config.preview));
  const tolerance = $derived(Math.max(8, config.tolerance));
  const duration = $derived(Math.max(8000, config.duration));

  let phase = $state<Phase>("preview");
  let r = $state(128);
  let g = $state(128);
  let b = $state(128);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let phaseRef: Phase = "preview";
  let guessRef = [128, 128, 128];
  let startRef = performance.now();

  const sliders = [
    { label: "R", key: "r" },
    { label: "G", key: "g" },
    { label: "B", key: "b" },
  ] as const;

  const guess = $derived([r, g, b]);
  const distance = $derived(colorDistance(guess, target));
  const closeEnough = $derived(distance <= tolerance);
  const secondsLeft = $derived(
    ((progress / 100) * (phase === "preview" ? previewMs : duration)) / 1000
  );
  const revealTarget = $derived(
    phase === "preview" || finished || result !== null
  );
  const subtitle = $derived(
    result !== null
      ? result
        ? "Matched"
        : "Revealed"
      : phase === "preview"
        ? "Memorize"
        : closeEnough
          ? "Close enough"
          : "Match it"
  );
  const footer = $derived(
    phase === "preview"
      ? `Remember the color - Esc`
      : result !== null
        ? `Target revealed - ${result ? "Success" : "Failed"}`
        : `Tune RGB, then E / Space - Esc`
  );

  function channelValue(key: "r" | "g" | "b") {
    if (key === "r") return r;
    if (key === "g") return g;
    return b;
  }

  function setChannel(key: "r" | "g" | "b", value: number) {
    if (key === "r") r = value;
    else if (key === "g") g = value;
    else b = value;
    guessRef = [r, g, b];
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function submit() {
    if (finishedRef || phaseRef !== "match") return;
    const dist = colorDistance(guessRef, target);
    void endGame(dist <= tolerance);
  }

  $effect(() => {
    void target;
    void previewMs;
    void duration;
    void tolerance;
    phase = "preview";
    phaseRef = "preview";
    r = 128;
    g = 128;
    b = 128;
    guessRef = [128, 128, 128];
    finished = false;
    result = null;
    finishedRef = false;
    startRef = performance.now();
    progress = 100;
    runId = untrack(() => runId) + 1;
  });

  $effect(() => {
    const total = phase === "preview" ? previewMs : duration;
    void runId;
    void target;
    void tolerance;
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
          phase = "match";
          phaseRef = "match";
          return;
        }
        void endGame(colorDistance(guessRef, target) <= tolerance);
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
      if (
        phaseRef === "match" &&
        (e.code === "Space" || e.code === "Enter" || e.code === "KeyE")
      ) {
        e.preventDefault();
        submit();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card colormatch__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Palette class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Color Match</span>
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
      <div class="colormatch__body">
        <div class="colormatch__swatches">
          <div class="colormatch__swatch-wrap">
            <span class="colormatch__label">
              {revealTarget && phase !== "preview" ? "Answer" : "Target"}
            </span>
            {#if revealTarget}
              <div
                class={[
                  "colormatch__swatch",
                  "colormatch__swatch--target",
                  result === false ? "colormatch__swatch--reveal" : "",
                ]}
                style="background: {rgbCss(target)}"
              ></div>
            {:else}
              <div class="colormatch__swatch colormatch__swatch--hidden">?</div>
            {/if}
          </div>
          <div class="colormatch__swatch-wrap">
            <span class="colormatch__label">Yours</span>
            <div
              class={[
                "colormatch__swatch",
                phase === "match" && closeEnough
                  ? "colormatch__swatch--close"
                  : "",
              ]}
              style="background: {phase === "preview" ? "#2c2e33" : rgbCss(guess)}"
            ></div>
          </div>
        </div>

        <div class="colormatch__sliders">
          {#each sliders as ch (ch.key)}
            <div class="colormatch__row">
              <span class="colormatch__channel colormatch__channel--{ch.key}">
                {ch.label}
              </span>
              <input
                class="colormatch__slider colormatch__slider--{ch.key}"
                type="range"
                min={0}
                max={255}
                value={channelValue(ch.key)}
                disabled={finished || phase !== "match"}
                oninput={(e) =>
                  setChannel(ch.key, Number(e.currentTarget.value))}
              />
              <span class="colormatch__value">{channelValue(ch.key)}</span>
            </div>
          {/each}
        </div>

        <div class="colormatch__meta">
          <span>
            Diff <strong>{distance.toFixed(0)}</strong>
          </span>
          <span>
            Need ≤ <strong>{tolerance}</strong>
          </span>
        </div>

        <button
          type="button"
          class={[
            "colormatch__submit",
            phase === "match" && closeEnough ? "colormatch__submit--ready" : "",
          ]}
          disabled={finished || phase !== "match"}
          onclick={submit}
        >
          Submit match
        </button>
      </div>
    </div>

    <div class="mg__footer">{footer}</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
