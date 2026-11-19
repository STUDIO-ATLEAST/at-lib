<script lang="ts">
  import { untrack } from "svelte";
  import AudioWaveform from "@lucide/svelte/icons/audio-waveform";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { SignalTuneConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./SignalTune.css";

  let { config: configProp }: { config: SignalTuneConfig } = $props();

  const config = untrack(() => configProp);

  const VIEW_W = 400;
  const VIEW_H = 160;
  const SAMPLES = 120;
  const gridMarks = [0.25, 0.5, 0.75];

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  function phaseDiff(a: number, b: number) {
    const d = Math.abs(((a - b) % 360) + 360) % 360;
    return Math.min(d, 360 - d);
  }

  function wavePath(frequency: number, amplitude: number, phaseDeg: number) {
    const mid = VIEW_H / 2;
    const ampPx = (clamp(amplitude, 0, 100) / 100) * (VIEW_H * 0.38);
    const phaseRad = (phaseDeg * Math.PI) / 180;
    let d = "";
    for (let i = 0; i <= SAMPLES; i++) {
      const t = i / SAMPLES;
      const x = t * VIEW_W;
      const y = mid - Math.sin(t * frequency * Math.PI * 2 + phaseRad) * ampPx;
      d +=
        i === 0
          ? `M ${x.toFixed(2)} ${y.toFixed(2)}`
          : ` L ${x.toFixed(2)} ${y.toFixed(2)}`;
    }
    return d;
  }

  const targetFreq = $derived(clamp(config.frequency, 1, 8));
  const targetAmp = $derived(clamp(config.amplitude, 10, 100));
  const targetPhase = $derived(((config.phase % 360) + 360) % 360);
  const freqTol = $derived(Math.max(0.08, config.freqTolerance));
  const ampTol = $derived(Math.max(2, config.ampTolerance));
  const phaseTol = $derived(Math.max(3, config.phaseTolerance));
  const duration = $derived(Math.max(10000, config.duration));

  let freq = $state(4);
  let amp = $state(50);
  let phase = $state(0);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let guessRef = { freq: 4, amp: 50, phase: 0 };
  let startRef = performance.now();

  const freqOk = $derived(Math.abs(freq - targetFreq) <= freqTol);
  const ampOk = $derived(Math.abs(amp - targetAmp) <= ampTol);
  const phaseOk = $derived(phaseDiff(phase, targetPhase) <= phaseTol);
  const locked = $derived(freqOk && ampOk && phaseOk);
  const targetPath = $derived(wavePath(targetFreq, targetAmp, targetPhase));
  const yoursPath = $derived(wavePath(freq, amp, phase));
  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const subtitle = $derived(
    result !== null
      ? result
        ? "Tuned"
        : "Failed"
      : locked
        ? "Locked in"
        : "Tune signal"
  );

  function isMatch(f: number, a: number, p: number) {
    return (
      Math.abs(f - targetFreq) <= freqTol &&
      Math.abs(a - targetAmp) <= ampTol &&
      phaseDiff(p, targetPhase) <= phaseTol
    );
  }

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function submit() {
    if (finishedRef) return;
    const g = guessRef;
    void endGame(isMatch(g.freq, g.amp, g.phase));
  }

  function setFreq(value: number) {
    freq = value;
    guessRef = { freq, amp, phase };
  }

  function setAmp(value: number) {
    amp = value;
    guessRef = { freq, amp, phase };
  }

  function setPhase(value: number) {
    phase = value;
    guessRef = { freq, amp, phase };
  }

  $effect(() => {
    void targetFreq;
    void targetAmp;
    void targetPhase;
    void duration;
    freq = 4;
    amp = 50;
    phase = 0;
    guessRef = { freq: 4, amp: 50, phase: 0 };
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
        const g = guessRef;
        void endGame(isMatch(g.freq, g.amp, g.phase));
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
</script>

<div class="mg">
  <div class="mg__card signaltune__card">
    <div class="mg__header">
      <div class="mg__heading">
        <AudioWaveform class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Signal Tune</span>
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
      <div class="signaltune__body">
        <div class={["signaltune__scope", locked ? "signaltune__scope--locked" : ""]}>
          <svg
            class="signaltune__svg"
            viewBox="0 0 {VIEW_W} {VIEW_H}"
            preserveAspectRatio="none"
            aria-hidden="true"
          >
            {#each gridMarks as t (t)}
              <line
                class="signaltune__grid"
                x1={0}
                y1={VIEW_H * t}
                x2={VIEW_W}
                y2={VIEW_H * t}
              />
            {/each}
            {#each gridMarks as t (`v-${t}`)}
              <line
                class="signaltune__grid"
                x1={VIEW_W * t}
                y1={0}
                x2={VIEW_W * t}
                y2={VIEW_H}
              />
            {/each}
            <line
              class="signaltune__axis"
              x1={0}
              y1={VIEW_H / 2}
              x2={VIEW_W}
              y2={VIEW_H / 2}
            />
            <path
              class="signaltune__wave signaltune__wave--target"
              d={targetPath}
            />
            <path
              class="signaltune__wave signaltune__wave--yours"
              d={yoursPath}
            />
          </svg>
          <div class="signaltune__legend">
            <span>
              <i class="signaltune__dot signaltune__dot--target"></i>
              Target
            </span>
            <span>
              <i class="signaltune__dot signaltune__dot--yours"></i>
              Yours
            </span>
          </div>
        </div>

        <div class="signaltune__sliders">
          <div class="signaltune__row">
            <span class="signaltune__label">Frequency</span>
            <input
              class="signaltune__slider"
              type="range"
              min={1}
              max={8}
              step={0.05}
              value={freq}
              disabled={finished}
              oninput={(e) => setFreq(Number(e.currentTarget.value))}
            />
            <span class="signaltune__value">{freq.toFixed(2)}</span>
          </div>
          <div class="signaltune__row">
            <span class="signaltune__label">Amplitude</span>
            <input
              class="signaltune__slider"
              type="range"
              min={10}
              max={100}
              step={1}
              value={amp}
              disabled={finished}
              oninput={(e) => setAmp(Number(e.currentTarget.value))}
            />
            <span class="signaltune__value">{Math.round(amp)}</span>
          </div>
          <div class="signaltune__row">
            <span class="signaltune__label">Phase</span>
            <input
              class="signaltune__slider"
              type="range"
              min={0}
              max={359}
              step={1}
              value={phase}
              disabled={finished}
              oninput={(e) => setPhase(Number(e.currentTarget.value))}
            />
            <span class="signaltune__value">{Math.round(phase)}°</span>
          </div>
        </div>

        <div class="signaltune__meta">
          <div class="signaltune__checks" aria-label="Match status">
            <span
              class={["signaltune__check", freqOk ? "signaltune__check--ok" : ""]}
              title="Frequency"
            ></span>
            <span
              class={["signaltune__check", ampOk ? "signaltune__check--ok" : ""]}
              title="Amplitude"
            ></span>
            <span
              class={["signaltune__check", phaseOk ? "signaltune__check--ok" : ""]}
              title="Phase"
            ></span>
          </div>
          <span>
            Align all three - <strong>{locked ? "Ready" : "Tuning"}</strong>
          </span>
        </div>

        <button
          type="button"
          class={["signaltune__submit", locked ? "signaltune__submit--ready" : ""]}
          disabled={finished}
          onclick={submit}
        >
          Lock signal
        </button>
      </div>
    </div>

    <div class="mg__footer">Match the dashed wave - E / Space - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
