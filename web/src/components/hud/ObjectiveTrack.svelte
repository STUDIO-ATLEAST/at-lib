<script lang="ts">
  // Shared progress row for the mission UIs, same family as the rm-hud objective card:
  // 17px #373a40 track, #228be6 fill (green when done), centered count tag, percent under the right end.
  let {
    value,
    max,
    label,
    percent = true,
  }: { value: number; max: number; label?: string; percent?: boolean } = $props();

  const ratio = $derived(max > 0 ? Math.max(0, Math.min(1, value / max)) : 0);
  const done = $derived(max > 0 && value >= max);
</script>

<div class="ot">
  <div class="ot-track">
    <div class="ot-fill" class:ot-fill--done={done} style:width="{ratio * 100}%"></div>
    <span class="ot-count">{label ?? `${value}/${max}`}</span>
  </div>
  {#if percent}
    <span class="ot-percent">{Math.round(ratio * 100)}%</span>
  {/if}
</div>

<style>
  .ot {
    display: flex;
    flex-direction: column;
    gap: calc(4 * var(--vp));
  }

  .ot-track {
    position: relative;
    height: calc(17 * var(--vp));
    overflow: hidden;
    border-radius: 2px;
    background: #373a40;
  }

  .ot-fill {
    height: 100%;
    background: #228be6;
    transition:
      width 300ms ease-out,
      background 150ms ease;
  }

  .ot-fill--done {
    background: #2f9e44;
  }

  .ot-count {
    position: absolute;
    top: 50%;
    left: 50%;
    padding: 0 calc(7 * var(--vp));
    border-radius: 2px;
    background: #101113;
    border: 1px solid var(--border-strong);
    color: var(--white);
    font-size: calc(10.5 * var(--vp));
    font-variant-numeric: tabular-nums;
    line-height: calc(13 * var(--vp));
    white-space: nowrap;
    transform: translate(-50%, -50%);
  }

  .ot-percent {
    align-self: flex-end;
    color: var(--muted);
    font-size: calc(10.5 * var(--vp));
    font-variant-numeric: tabular-nums;
  }
</style>
