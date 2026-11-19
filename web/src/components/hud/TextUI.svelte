<script lang="ts">
  import { onMount } from "svelte";
  import { onNui } from "../../lib/nui";
    import { mantineSlide } from "../../lib/transitions";
  import { closeTextUI, devPreview, setTextUI, textUI } from "../../stores/hud.svelte";
  import type { TextUIData, TextUIPosition } from "../../types/hud";
  import { isEnvBrowser } from "../../utils/misc";
  import { vp } from "../../utils/vp";
  import InlineKeyText from "./InlineKeyText.svelte";
  import InlineMarkdown from "./InlineMarkdown.svelte";

  const inBrowser = isEnvBrowser();

  onMount(() => {
    const offs = [
      onNui<TextUIData>("SHOW_TEXTUI", (data) => setTextUI(data)),
      onNui("HIDE_TEXTUI", () => closeTextUI()),
    ];
    return () => offs.forEach((off) => off());
  });

  const prompts = $derived.by<TextUIData[]>(() => {
    if (!inBrowser) return textUI.data ? [textUI.data] : [];

    const list: TextUIData[] = [];
    if (devPreview.toggles.textui && textUI.data) list.push(textUI.data);
    if (devPreview.toggles.textuiPlain) list.push({ label: "Vehicle is parked" });
    return list;
  });

  const show = $derived(
    prompts.length > 0 && (inBrowser || textUI.visible),
  );

  // the mission card owns the right side: side prompts always sit on the left
  // (top / bottom prompts keep their spot)
  const position = $derived<TextUIPosition>(
    prompts[0]?.position === "top-center" || prompts[0]?.position === "bottom-center"
      ? prompts[0].position
      : "left-center",
  );
  const horizontal = $derived(position === "right-center" || position === "left-center");

  const anchorStyle = $derived.by(() => {
    switch (position) {
      case "left-center":
        return `left: ${vp(20)}; top: 50%; transform: translateY(-50%);`;
      case "top-center":
        return `top: ${vp(20)}; left: 50%; transform: translateX(-50%);`;
      case "bottom-center":
        return `bottom: ${vp(90)}; left: 50%; transform: translateX(-50%);`;
      default:
        return `right: ${vp(20)}; top: 50%; transform: translateY(-50%);`;
    }
  });

  const slideDistance = $derived(
    position === "left-center" || position === "top-center" ? `(-1 * ${vp(24)})` : vp(24),
  );

  function lines(prompt: TextUIData): string[] {
    if (prompt.key) return [];
    return prompt.label.split(/\s*\n\s*/).filter(Boolean);
  }
</script>

{#if show}
  <div class="textui-anchor" style={anchorStyle}>
    <div
      class="textui-stack"
      class:textui-stack--start={position === "left-center"}
      class:textui-stack--center={!horizontal}
      style={`gap: ${vp(8)};`}
      transition:mantineSlide={{ axis: horizontal ? "x" : "y", distance: slideDistance, duration: 250 }}
    >
      {#each prompts as prompt, index (`${prompt.key ?? "plain"}-${index}`)}
        {@const rows = lines(prompt)}
        <div
          class="el-panel textui-panel"

          class:textui-panel--plain={!prompt.key}
        >
          <div
            class="textui-row"
            style={`gap: ${vp(12)}; padding: ${vp(10)} ${vp(12)};`}
          >
            {#if prompt.key}
              <span class="el-num textui-key" style={`min-width: ${vp(30)}; height: ${vp(30)};`}>{prompt.key}</span>
            {/if}

            <div
              class="textui-label"
              class:textui-label--multiline={rows.length > 1}
              style={`gap: ${vp(6)};`}
            >
              {#if prompt.key}
                <InlineMarkdown text={prompt.label} />
              {:else if rows.length > 1}
                {#each rows as line, lineIndex (lineIndex)}
                  <div class="textui-line"><InlineKeyText text={line} /></div>
                {/each}
              {:else}
                <InlineKeyText text={prompt.label} />
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>
  </div>
{/if}

<style>
  .textui-anchor {
    position: fixed;
    pointer-events: none;
    z-index: 90;
  }

  .textui-stack {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }

  .textui-stack--start {
    align-items: flex-start;
  }

  .textui-stack--center {
    align-items: center;
  }

  .textui-panel {
    overflow: hidden;
  }

  .textui-row {
    display: flex;
    align-items: center;
  }

  .textui-key {
    border-radius: var(--radius-sm);
    font-size: calc(14 * var(--vp));
  }

  .textui-label {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    font-size: calc(15 * var(--vp));
    line-height: 1;
    color: var(--white);
  }

  .textui-label--multiline {
    flex-direction: column;
    align-items: flex-start;
    flex-wrap: nowrap;
  }

  .textui-line {
    display: flex;
    align-items: center;
  }
</style>
