<script lang="ts">
  import { icon } from "../../lib/icons";
  import { square } from "../../utils/vp";
  import type { MissionGauge } from "../../types/hud";

  const MAX_SEGMENTS = 16;

  let { gauge }: { gauge: MissionGauge } = $props();

  const Icon = $derived(icon(gauge.icon));
  const max = $derived(Math.max(0, gauge.max ?? 0));
  const value = $derived(Math.max(0, Math.min(gauge.value ?? 0, max)));
  const ratio = $derived(max > 0 ? value / max : 0);
  const segmented = $derived(gauge.kind === "segments" && max > 0 && max <= MAX_SEGMENTS);
  const slots = $derived(Array.from({ length: segmented ? max : 0 }, (_, index) => index));
  const readout = $derived(gauge.text ?? `${Math.floor(value)} / ${Math.floor(max)}`);
</script>

<div class="gauge tone-{gauge.tone ?? 'normal'}">
  <div class="head">
    <span class="icon"><Icon size={13} style={square(13)} strokeWidth={2.2} /></span>
    <span class="label">{gauge.label ?? ""}</span>
    <span class="readout">{readout}</span>
  </div>
  {#if segmented}
    <div class="segments">
      {#each slots as index (index)}
        <span class="segment" class:filled={index < value}></span>
      {/each}
    </div>
  {:else}
    <div class="track"><div class="fill" style:width="{ratio * 100}%"></div></div>
  {/if}
</div>

<style>
  .gauge {
    --tone: var(--blue);
    --tone-text: var(--text);
    display: flex;
    flex-direction: column;
    gap: calc(6 * var(--vp));
  }

  .tone-ok {
    --tone: var(--green);
    --tone-text: var(--green);
  }

  .tone-warn {
    --tone: var(--orange);
    --tone-text: var(--orange);
  }

  .tone-danger {
    --tone: var(--red);
    --tone-text: var(--red);
  }

  .head {
    display: flex;
    align-items: center;
    gap: calc(7 * var(--vp));
    min-width: 0;
    font-size: calc(12 * var(--vp));
  }

  .icon {
    display: flex;
    flex-shrink: 0;
    color: var(--muted);
    transition: color 150ms ease;
  }

  .tone-warn .icon,
  .tone-danger .icon,
  .tone-ok .icon {
    color: var(--tone);
  }

  .label {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    color: var(--text);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .readout {
    flex-shrink: 0;
    color: var(--tone-text);
    font-variant-numeric: tabular-nums;
    transition: color 150ms ease;
  }

  .track {
    height: calc(4 * var(--vp));
    overflow: hidden;
    background: var(--bg-sidebar);
    border-radius: 999px;
  }

  .fill {
    height: 100%;
    background: var(--tone);
    border-radius: 999px;
    transition:
      width 400ms cubic-bezier(0.22, 1, 0.36, 1),
      background 150ms ease;
  }

  .segments {
    display: flex;
    gap: calc(3 * var(--vp));
  }

  .segment {
    flex: 1;
    height: calc(4 * var(--vp));
    background: var(--bg-sidebar);
    border-radius: calc(2 * var(--vp));
    transition: background 150ms ease;
  }

  .segment.filled {
    background: var(--tone);
  }
</style>
