<script lang="ts">
  import { onMount } from "svelte";
  import { fade } from "svelte/transition";
  import Gauge from "@lucide/svelte/icons/gauge";
  import { onNui } from "../../lib/nui";
  import { closeProgress, devPreview, progress, showProgress, updateProgress } from "../../stores/hud.svelte";
  import type { ProgressData } from "../../types/hud";
  import { isEnvBrowser } from "../../utils/misc";
  import { vp } from "../../utils/vp";

  const inBrowser = isEnvBrowser();

  onMount(() => {
    const offs = [
      onNui<ProgressData>("SHOW_PROGRESS", (data) => showProgress(data)),
      onNui<Partial<ProgressData>>("UPDATE_PROGRESS", (data) => updateProgress(data)),
      onNui("CLOSE_PROGRESS", () => closeProgress()),
    ];
    return () => offs.forEach((off) => off());
  });

  const mounted = $derived(
    inBrowser ? devPreview.toggles.progress : progress.visible && !!progress.data,
  );

  const fill = $derived.by(() => {
    if (!inBrowser) return progress.data?.progress ?? 0;
    if (progress.visible && progress.data) return progress.data.progress;
    return devPreview.progressValue;
  });

  const clamped = $derived(Math.max(0, Math.min(100, fill)));
  // calm -> busy -> critical (e.g. a disturbance / heat meter)
  const tone = $derived(clamped < 40 ? "green" : clamped < 70 ? "yellow" : "red");

  const headerText = $derived(progress.data?.header?.trim() || (inBrowser ? "Disturbance" : "Progress"));
  // scripts often pass the percentage as the label - that is already shown on the right
  const rawLabel = $derived(progress.data?.label?.trim() || "");
  const labelText = $derived(/^\d+(\.\d+)?\s*%$/.test(rawLabel) ? "" : rawLabel);
</script>

{#if mounted}
  <div
    class="pm-anchor"
    style={`top: ${vp(24)}; width: min(${vp(380)}, calc(100vw / var(--ui-scale, 1) - ${vp(32)}));`}
    transition:fade={{ duration: 180 }}
  >
    <div class="el-panel">
      <div class="el-header">
        <div class="el-brand"><Gauge /></div>
        <div class="el-heading">
          <span class="el-title">{headerText}</span>
          <span class="el-subtitle">{labelText || "Progress"}</span>
        </div>
        <span class="el-badge el-badge--{tone}">{Math.round(clamped)}%</span>
      </div>
      <div class="pm-plate" style={`padding: ${vp(10)} ${vp(12)} ${vp(12)};`}>
        <div class="pm-track" style={`height: ${vp(8)};`}>
          <div class="pm-fill" style={`width: ${clamped}%; background-color: var(--${tone});`}></div>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .pm-anchor {
    position: fixed;
    left: 50%;
    transform: translateX(-50%);
    pointer-events: none;
    z-index: 98;
    user-select: none;
  }

  .pm-plate {
    display: block;
  }

  .pm-track {
    overflow: hidden;
    border-radius: calc(2 * var(--vp));
    background: var(--bg-sidebar);
    border: 1px solid var(--border);
  }

  .pm-fill {
    height: 100%;
    border-radius: calc(2 * var(--vp));
    transition: width 300ms ease, background-color 200ms ease;
  }
</style>
