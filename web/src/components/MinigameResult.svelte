<script lang="ts">
  import Check from "@lucide/svelte/icons/check";
  import X from "@lucide/svelte/icons/x";
  import { iconSize } from "../utils/vp";

  let { success }: { success: boolean } = $props();
</script>

<div
  class={["mg__result", success ? "mg__result--ok" : "mg__result--fail"]}
  role="status"
  aria-live="polite"
>
  <div class="mg__result-icon" aria-hidden="true">
    {#if success}
      <Check style={iconSize(3)} strokeWidth={2.5} />
    {:else}
      <X style={iconSize(3)} strokeWidth={2.5} />
    {/if}
  </div>
  <div class="mg__result-title">{success ? "Successful" : "Failed"}</div>
</div>
