<script lang="ts">
  let { total, done }: { total: number; done: number } = $props();

  const n = $derived(Math.floor(total));
  const filled = $derived(Math.max(0, Math.min(n, Math.floor(done))));
</script>

{#if n > 1}
  <div class="mg__stages" aria-label="{filled} of {n} stages complete">
    {#each { length: n } as _, i}
      <span class={["mg__stage", i < filled ? "mg__stage--done" : ""]}></span>
    {/each}
  </div>
{/if}
