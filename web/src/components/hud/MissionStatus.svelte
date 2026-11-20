<script lang="ts">
  import { onMount } from "svelte";
  import Target from "@lucide/svelte/icons/target";
  import ObjectiveTrack from "./ObjectiveTrack.svelte";
  import { onNui } from "../../lib/nui";
  import { mantineSlide } from "../../lib/transitions";
  import {
    closeMission,
    devPreview,
    missionStatus,
    setMission,
    updateObjective,
  } from "../../stores/hud.svelte";
  import type { MissionData } from "../../types/hud";
  import { isEnvBrowser } from "../../utils/misc";
  import { square, vp } from "../../utils/vp";

  const inBrowser = isEnvBrowser();

  onMount(() => {
    const offs = [
      onNui<MissionData>("SET_MISSION", (data) => setMission(missionStatus, data)),
      onNui<{ id: string; completed: boolean }>("UPDATE_OBJECTIVE", (data) =>
        updateObjective(missionStatus, data.id, data.completed),
      ),
      onNui("CLOSE_MISSION", () => closeMission(missionStatus)),
    ];
    return () => offs.forEach((off) => off());
  });

  const show = $derived(
    missionStatus.visible && !!missionStatus.data && (!inBrowser || devPreview.toggles.mission),
  );

  const objectives = $derived(missionStatus.data?.objectives ?? []);
  const completed = $derived(objectives.filter((objective) => objective.completed).length);
  const total = $derived(objectives.length);
  const currentIndex = $derived(objectives.findIndex((objective) => !objective.completed));
</script>

{#if show && missionStatus.data}
  {@const data = missionStatus.data}
  <div class="anchor" style={`left: ${vp(20)};`}>
    <div
      class="ms"
      style={`width: min(${vp(300)}, calc(100vw / var(--ui-scale, 1) - ${vp(32)}));`}
      transition:mantineSlide={{ axis: "x", distance: "-100%", duration: 400 }}
    >
      <div class="head">
        <span class="head-icon"><Target size={17} style={square(17)} strokeWidth={2.2} /></span>
        <div class="head-text">
          <span class="title">{data.title}</span>
          <span class="eyebrow">Objectives</span>
        </div>
      </div>

      {#if total > 0}
        <ul class="rows">
          {#each objectives as objective, index (objective.id)}
            <li class="row" class:done={objective.completed} class:active={index === currentIndex}>
              <span class="mark"></span>
              <span class="row-label">{objective.label}</span>
            </li>
          {/each}
        </ul>
        <ObjectiveTrack value={completed} max={total} />
      {/if}
    </div>
  </div>
{/if}

<style>
  /* Same family as the rm-hud objective card and at-lib MissionCard: solid #141517 panel,
     30px square icon tile, uppercase title, 5px square marks, 17px track with count tag. */
  .anchor {
    position: fixed;
    top: 50%;
    z-index: 100;
    pointer-events: none;
    transform: translateY(-50%);
  }

  .ms {
    display: flex;
    flex-direction: column;
    gap: calc(12 * var(--vp));
    box-sizing: border-box;
    padding: calc(16 * var(--vp)) calc(16 * var(--vp)) calc(14 * var(--vp));
    overflow: hidden;
    background: var(--bg-frame);
    border: 1px solid var(--border);
    border-radius: 4px;
    box-shadow: 0 calc(10 * var(--vp)) calc(30 * var(--vp)) rgba(0, 0, 0, 0.35);
    color: var(--text);
    font-family: "Tussilago", "Segoe UI", sans-serif;
  }

  .head {
    display: flex;
    align-items: center;
    gap: calc(10 * var(--vp));
  }

  .head-icon {
    display: inline-grid;
    place-items: center;
    flex-shrink: 0;
    width: calc(30 * var(--vp));
    height: calc(30 * var(--vp));
    border-radius: 3px;
    background: var(--bg-field);
    border: 1px solid var(--border-strong);
    color: var(--white);
  }

  .head-text {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: calc(3 * var(--vp));
    min-width: 0;
  }

  .title {
    color: var(--white);
    font-size: calc(15 * var(--vp));
    letter-spacing: 0.03em;
    line-height: 1.15;
    overflow-wrap: anywhere;
    text-transform: uppercase;
  }

  .eyebrow {
    color: var(--muted);
    font-size: calc(10 * var(--vp));
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .rows {
    display: flex;
    flex-direction: column;
    gap: calc(8 * var(--vp));
    margin: 0;
    padding: calc(12 * var(--vp)) 0 0;
    border-top: 1px solid var(--border);
    list-style: none;
  }

  .row {
    display: flex;
    align-items: center;
    gap: calc(8 * var(--vp));
    color: var(--text);
    font-size: calc(12.5 * var(--vp));
    line-height: 1.35;
    transition: color 150ms ease;
  }

  .mark {
    flex-shrink: 0;
    width: calc(5 * var(--vp));
    height: calc(5 * var(--vp));
    min-width: 3px;
    min-height: 3px;
    background: var(--dim);
    transition: background 150ms ease;
  }

  .row.active {
    color: var(--white);
  }

  .row.active .mark {
    background: var(--blue);
  }

  .row.done {
    color: var(--muted);
  }

  .row.done .mark {
    background: var(--green);
  }

  .row-label {
    flex: 1;
    min-width: 0;
  }

  .row.done .row-label {
    text-decoration: line-through;
    text-decoration-color: var(--dim);
  }
</style>
