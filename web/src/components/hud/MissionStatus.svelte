<script lang="ts">
  import { onMount } from "svelte";
  import Check from "@lucide/svelte/icons/check";
  import Target from "@lucide/svelte/icons/target";
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
  import { vp } from "../../utils/vp";

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

  const completed = $derived(
    missionStatus.data?.objectives.filter((objective) => objective.completed).length ?? 0,
  );
  const total = $derived(missionStatus.data?.objectives.length ?? 0);
</script>

{#if show && missionStatus.data}
  {@const data = missionStatus.data}
  <div class="mission-anchor" style={`left: ${vp(20)};`}>
    <div
      class="el-panel"
      style={`width: min(${vp(280)}, calc(100vw / var(--ui-scale, 1) - ${vp(32)}));`}
      transition:mantineSlide={{ axis: "x", distance: "-100%", duration: 400 }}
    >
      <div class="el-header">
        <div class="el-brand"><Target /></div>
        <div class="el-heading">
          <span class="el-title">{data.title}</span>
          <span class="el-subtitle">Objectives</span>
        </div>
        <span class="el-badge" class:el-badge--green={total > 0 && completed === total}>
          {completed} / {Math.max(1, total)}
        </span>
      </div>

      <div class="el-body">
        {#each data.objectives as objective, index (objective.id)}
          <div class="el-tile" class:el-tile--done={objective.completed}>
            {#if objective.completed}
              <span class="mission-check"><Check size={12} style={`width: ${vp(12)}; height: ${vp(12)};`} strokeWidth={3} /></span>
            {:else}
              <span class="el-num">{index + 1}</span>
            {/if}
            <span class="mission-objective-label" class:mission-objective-label--done={objective.completed}>
              {objective.label}
            </span>
          </div>
        {/each}
        <div class="el-track" style={`margin-top: ${vp(4)};`}>
          <div style={`width: ${(completed / Math.max(1, total)) * 100}%;`}></div>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .mission-anchor {
    position: fixed;
    top: 50%;
    transform: translateY(-50%);
    pointer-events: none;
    z-index: 100;
  }

  .mission-objective-label {
    font-size: calc(12.5 * var(--vp));
    line-height: 1.4;
    color: var(--text);
  }

  .mission-check {
    display: inline-grid;
    place-items: center;
    flex-shrink: 0;
    width: calc(20 * var(--vp));
    height: calc(20 * var(--vp));
    border-radius: 3px;
    background: var(--tint-green);
    color: var(--green);
  }

  .mission-objective-label--done {
    color: var(--muted);
    text-decoration: line-through;
    text-decoration-color: var(--dim);
  }
</style>
