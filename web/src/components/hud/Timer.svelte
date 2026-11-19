<script lang="ts">
  import { onMount, untrack } from "svelte";
  import TimerIcon from "@lucide/svelte/icons/timer";
  import { onNui } from "../../lib/nui";
    import { mantineSlide } from "../../lib/transitions";
  import {
    closeTimer,
    devPreview,
    showTimer,
    timer,
    updateTimer,
  } from "../../stores/hud.svelte";
  import type { TimerData } from "../../types/hud";
  import { fetchNui } from "../../utils/fetchNui";
  import { isEnvBrowser } from "../../utils/misc";
  import { vp } from "../../utils/vp";

  const inBrowser = isEnvBrowser();

  let remaining = $state(timer.data?.seconds ?? 0);
  let session = $state(0);

  function formatTime(totalSeconds: number): string {
    const s = Math.max(0, Math.floor(totalSeconds));
    return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}`;
  }

  onMount(() => {
    const offs = [
      onNui<TimerData>("SHOW_TIMER", (data) => {
        showTimer(data);
        remaining = data.seconds;
        session += 1;
      }),
      onNui<Partial<TimerData>>("UPDATE_TIMER", (data) => {
        updateTimer(data);
        if (typeof data.seconds === "number") {
          remaining = data.seconds;
          session += 1;
        }
      }),
      onNui("CLOSE_TIMER", () => {
        closeTimer();
        remaining = 0;
      }),
    ];
    return () => offs.forEach((off) => off());
  });

  const show = $derived(
    timer.visible &&
      !!timer.data &&
      (!inBrowser || devPreview.toggles.timer || devPreview.toggles.timerV2),
  );

  $effect(() => {
    session;
    if (!show) return;

    if (untrack(() => remaining) <= 0) {
      const seconds = timer.data?.seconds ?? 0;
      if (seconds <= 0) return;
      remaining = seconds;
    }

    const id = window.setInterval(() => {
      if (remaining <= 1) {
        remaining = 0;
        if (inBrowser) return;
        void fetchNui("timerComplete", {});
        closeTimer();
        return;
      }
      remaining -= 1;
    }, 1000);

    return () => window.clearInterval(id);
  });

  const bottomCenter = $derived(timer.data?.position === "bottom-center");
  const heist = $derived(
    timer.data?.variant === "heist" || (inBrowser && devPreview.toggles.timerV2),
  );
</script>

{#if show && timer.data}
  {@const data = timer.data}
  {@const low = remaining <= 10}
  {#if heist}
    <!-- compact chip under the top HUD: label + value -->
    <div
      class="timer-anchor"
      style={bottomCenter ? `bottom: ${vp(24)};` : `top: ${vp(128)};`}
    >
      <div
        class="el-panel timer-chip"
        transition:mantineSlide={{ axis: bottomCenter ? "y" : "x", distance: "100%", duration: 220 }}
      >
        <TimerIcon style={`width: ${vp(14)}; height: ${vp(14)};`} color={low ? "#ff8787" : "#4dabf7"} />
        <span class="el-subtitle">{data.header?.trim() || "Time"}</span>
        <span class="el-badge timer-value" class:el-badge--red={low}>{formatTime(remaining)}</span>
      </div>
    </div>
  {:else}
    <div class="timer-anchor" style={bottomCenter ? `bottom: ${vp(24)};` : `top: ${vp(24)};`}>
      <div
        class="el-panel"
        style={`width: min(${vp(340)}, calc(100vw / var(--ui-scale, 1) - ${vp(32)}));`}
        transition:mantineSlide={{ axis: "y", distance: bottomCenter ? "100%" : "-100%", duration: 300 }}
      >
        <div class="el-header timer-header">
          <div class="el-brand"><TimerIcon /></div>
          <div class="el-heading">
            <span class="el-title">{data.header?.trim() || "Timer"}</span>
            {#if data.text?.trim()}
              <span class="el-subtitle">{data.text}</span>
            {/if}
          </div>
          <span class="el-badge timer-value" class:el-badge--red={low}>{formatTime(remaining)}</span>
        </div>
      </div>
    </div>
  {/if}
{/if}

<style>
  .timer-anchor {
    position: fixed;
    left: 50%;
    transform: translateX(-50%);
    pointer-events: none;
    z-index: 99;
  }

  .timer-chip {
    display: flex;
    border-radius: var(--radius);
    align-items: center;
    gap: calc(8 * var(--vp));
    padding: calc(6 * var(--vp)) calc(8 * var(--vp)) calc(6 * var(--vp)) calc(10 * var(--vp));
  }

  .timer-header {
    border-bottom: none;
  }

  .timer-value {
    font-size: calc(15 * var(--vp));
    font-weight: 700;
    letter-spacing: 0.04em;
  }
</style>
