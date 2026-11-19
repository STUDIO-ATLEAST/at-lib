<script lang="ts">
  import { onMount } from "svelte";
  import MessageCircle from "@lucide/svelte/icons/message-circle";
  import { onNui } from "../../lib/nui";
    import { mantineSlide } from "../../lib/transitions";
  import { closeDialogue, devPreview, dialogue, setDialogue } from "../../stores/hud.svelte";
  import type { DialogueData } from "../../types/hud";
  import { fetchNui } from "../../utils/fetchNui";
  import { isEnvBrowser } from "../../utils/misc";
  import { vp } from "../../utils/vp";

  const inBrowser = isEnvBrowser();

  let hovered = $state<string | null>(null);
  // number inputs bind a number (or null when empty) in Svelte 5, text inputs a string:
  // always read it through `typed` so .trim() never runs on a number
  let inputValue = $state<string | number | null>("");
  const typed = $derived(inputValue === null || inputValue === undefined ? "" : String(inputValue).trim());

  onMount(() => {
    const offs = [
      onNui<DialogueData>("OPEN_DIALOGUE", (data) => {
        setDialogue(data);
        inputValue = "";
      }),
      onNui("CLOSE_DIALOGUE", () => closeDialogue()),
    ];
    return () => offs.forEach((off) => off());
  });

  const show = $derived(
    dialogue.visible && !!dialogue.data && (!inBrowser || devPreview.toggles.dialogue),
  );

  // Esc / Backspace leave any dialogue (answer = nil, same as closing it) - Backspace only when
  // not typing in the input, so it still deletes characters there.
  function onKey(event: KeyboardEvent) {
    if (!show) return;
    const typing = (event.target as HTMLElement | null)?.tagName === "INPUT";
    if (event.key === "Escape" || (event.key === "Backspace" && !typing)) {
      event.preventDefault();
      fetchNui("dialogueResponse", {});
      closeDialogue();
    }
  }

  onMount(() => {
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  function pickOption(id: string) {
    fetchNui("dialogueResponse", { id });
    closeDialogue();
  }

  function submitInput() {
    if (!typed) return;
    fetchNui("dialogueResponse", { value: typed });
    closeDialogue();
  }
</script>

{#if show && dialogue.data}
  {@const data = dialogue.data}
  <div class="dialogue-anchor" style={`bottom: ${vp(40)};`}>
    <div
      class="el-panel dialogue-panel"
      style={`width: min(${vp(560)}, calc(100vw / var(--ui-scale, 1) - ${vp(32)}));`}
      transition:mantineSlide={{ axis: "y", duration: 300 }}
    >
      <div class="el-header">
        <div class="el-brand"><MessageCircle /></div>
        <div class="el-heading">
          <span class="el-title">{data.name}</span>
          <span class="el-subtitle">Conversation</span>
        </div>
      </div>

      <div class="el-body">
        <p class="dialogue-text">{data.text}</p>

        {#if data.input}
          <div class="dialogue-input-row">
            <!-- svelte-ignore a11y_autofocus -->
            <input
              autofocus
              class="dialogue-input"
              type={data.input.type === "number" ? "number" : "text"}
              placeholder={data.input.placeholder || "Type here"}
              min={data.input.min}
              max={data.input.max}
              bind:value={inputValue}
              onkeydown={(event) => {
                if (event.key === "Enter") submitInput();
              }}
            />
            <button type="button" class="dialogue-submit" disabled={!typed} onclick={submitInput}>
              {data.input.submitLabel || "Submit"}
            </button>
          </div>
        {/if}

        {#each data.options as option, index (option.id)}
          <div
            role="button"
            tabindex="0"
            class="el-tile dialogue-option"
            class:el-tile--active={hovered === option.id}
            onmouseenter={() => (hovered = option.id)}
            onmouseleave={() => (hovered = null)}
            onclick={() => pickOption(option.id)}
            onkeydown={(event) => {
              if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                pickOption(option.id);
              }
            }}
          >
            <span class="el-num">{index + 1}</span>
            <span class="dialogue-option-label">{option.label}</span>
          </div>
        {/each}
      </div>
    </div>
  </div>
{/if}

<style>
  .dialogue-anchor {
    position: fixed;
    left: 0;
    right: 0;
    display: flex;
    justify-content: center;
    pointer-events: none;
    z-index: 100;
  }

  .dialogue-panel {
    pointer-events: auto;
  }

  .dialogue-text {
    margin: 0 0 calc(4 * var(--vp));
    font-size: calc(13.5 * var(--vp));
    line-height: 1.5;
    color: var(--text);
  }

  .dialogue-input-row {
    display: flex;
    gap: calc(8 * var(--vp));
  }

  .dialogue-input {
    flex: 1;
    height: calc(36 * var(--vp));
    padding: 0 calc(10 * var(--vp));
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-strong);
    background: var(--bg-field);
    color: var(--white);
    font-family: inherit;
    font-size: calc(14 * var(--vp));
    font-weight: 600;
    outline: none;
    transition: border-color 0.2s ease, background 0.2s ease;
  }

  .dialogue-input::placeholder {
    color: var(--dim);
  }

  .dialogue-input:focus {
    border-color: var(--border-hover);
    background: var(--bg-hover);
  }

  .dialogue-submit {
    height: calc(36 * var(--vp));
    padding: 0 calc(14 * var(--vp));
    border-radius: var(--radius-sm);
    border: 1px solid var(--line-green);
    background: var(--tint-green);
    color: var(--green);
    font-family: inherit;
    font-size: calc(13 * var(--vp));
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.2s ease, border-color 0.2s ease;
  }

  .dialogue-submit:hover:not(:disabled) {
    background: var(--tint-green-hover);
    border-color: var(--green);
  }

  .dialogue-submit:disabled {
    opacity: 0.45;
    cursor: default;
  }

  .dialogue-option {
    cursor: pointer;
    outline: none;
  }

  .dialogue-option-label {
    font-size: calc(13 * var(--vp));
    color: var(--text);
  }

  .dialogue-option.el-tile--active .dialogue-option-label {
    color: var(--white);
  }
</style>
