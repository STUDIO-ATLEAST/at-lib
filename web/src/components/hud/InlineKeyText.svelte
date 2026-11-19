<script lang="ts">
    import InlineMarkdown from "./InlineMarkdown.svelte";
    import { dark, radiusSm, blue } from "../../lib/theme";
    import { vp } from "../../utils/vp";

    let { text }: { text: string } = $props();

    const parts = $derived(text.split(/\[([^\]]+)\]/g));

    function trimPart(value: string, index: number, total: number): string {
        if (index === 0) return value.trimEnd();
        if (index === total - 1) return value.trimStart();
        return value.trim();
    }
</script>

{#each parts as part, index (index)}
    {#if index % 2 === 1}
        <span
            class="key-chip"
            style={`min-width: ${vp(26)}; height: ${vp(26)}; padding: 0 ${vp(6)}; margin-inline: ${vp(3)};
        background-color: ${dark[6]}; border-radius: ${radiusSm};`}
        >
            <span style={`color: ${blue[6]};`}>{part}</span>
        </span>
    {:else if trimPart(part, index, parts.length)}
        <InlineMarkdown text={trimPart(part, index, parts.length)} />
    {/if}
{/each}

<style>
    .key-chip {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        vertical-align: middle;
        border: 1px solid var(--border-strong);
    }

    .key-chip span {
        font-size: 14px;
        font-weight: 700;
        line-height: 1;
    }
</style>
