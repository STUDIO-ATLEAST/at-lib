<script lang="ts">
  import { onMount, untrack } from "svelte";
  import { Tween } from "svelte/motion";
  import { cubicOut } from "svelte/easing";
  import { fade, fly } from "svelte/transition";
  import Navigation from "@lucide/svelte/icons/navigation";
  import MissionGaugeView from "./MissionGauge.svelte";
  import ObjectiveTrack from "./ObjectiveTrack.svelte";
  import { icon, ListChecks, Package, Users } from "../../lib/icons";
  import { onNui } from "../../lib/nui";
  import { square } from "../../utils/vp";
  import {
    closeMission,
    devPreview,
    missionCard,
    missionCardLayout,
    setMission,
    updateMissionDetails,
    updateObjective,
  } from "../../stores/hud.svelte";
  import type { MissionData, MissionDetailsUpdate, MissionStep } from "../../types/hud";
  import { isEnvBrowser } from "../../utils/misc";

  const MAX_STEPS = 8;
  const STEP_WINDOW = 6;
  const GAIN_MS = 1800;
  const inBrowser = isEnvBrowser();

  onMount(() => {
    const offs = [
      onNui<MissionData>("SET_MISSION_CARD", (data) => setMission(missionCard, data)),
      onNui<{ id: string; completed: boolean }>("UPDATE_OBJECTIVE_CARD", (data) =>
        updateObjective(missionCard, data.id, data.completed),
      ),
      onNui<MissionDetailsUpdate>("UPDATE_MISSION_CARD", (data) =>
        updateMissionDetails(missionCard, data),
      ),
      onNui("CLOSE_MISSION_CARD", () => closeMission(missionCard)),
    ];
    return () => offs.forEach((off) => off());
  });

  const show = $derived(
    missionCard.visible && !!missionCard.data && (!inBrowser || devPreview.toggles.missionCard),
  );

  const MissionIcon = $derived(icon(missionCard.data?.icon, Package));
  const BadgeIcon = $derived(icon(missionCard.data?.badge?.icon, Users));
  const StatIcon = $derived(icon(missionCard.data?.stat?.icon, ListChecks));

  const steps = $derived<MissionStep[]>(
    missionCard.data?.steps?.length
      ? missionCard.data.steps
      : (missionCard.data?.objectives ?? []).map((objective) => ({
          id: objective.id,
          label: objective.label,
          done: objective.completed,
        })),
  );
  const tasks = $derived(missionCard.data?.tasks || []);
  const total = $derived(steps.length);
  const completed = $derived(steps.filter((step) => step.done).length);
  const activeIndex = $derived.by(() => {
    const flagged = steps.findIndex((step) => step.active);
    return flagged >= 0 ? flagged : steps.findIndex((step) => !step.done);
  });
  const activeStep = $derived<MissionStep | undefined>(steps[activeIndex]);
  const allDone = $derived(total > 0 && activeIndex < 0);
  const currentLabel = $derived(
    missionCard.data?.task || activeStep?.label || (allDone ? "All steps complete" : ""),
  );
  const meta = $derived(
    missionCard.data?.meta ||
      (allDone ? "All steps complete" : total > 0 ? `Step ${activeIndex + 1} of ${total}` : ""),
  );
  const stepCount = $derived(activeStep?.count ?? 0);
  const stepDone = $derived(Math.min(activeStep?.progress ?? 0, stepCount));
  const showStepBar = $derived(stepCount > 1 && tasks.length === 0);
  const compactSteps = $derived(tasks.length > 0);
  const nextStep = $derived(
    activeIndex < 0 ? undefined : steps.slice(activeIndex + 1).find((step) => !step.done),
  );
  const activeTask = $derived(
    (tasks.find((task) => !task.done && (task.progress ?? 0) > 0) ?? tasks.find((task) => !task.done))?.id,
  );

  const stepRange = $derived.by(() => {
    if (total <= MAX_STEPS) return { start: 0, end: total };
    const anchor = activeIndex < 0 ? total : activeIndex;
    const start = Math.max(0, Math.min(anchor - 1, total - STEP_WINDOW));
    return { start, end: start + STEP_WINDOW };
  });
  const visibleSteps = $derived(
    steps
      .slice(stepRange.start, stepRange.end)
      .map((step, offset) => ({ step, index: stepRange.start + offset })),
  );
  const hiddenBefore = $derived(stepRange.start);
  const hiddenAfter = $derived(total - stepRange.end);

  const optional = $derived(missionCard.data?.optional || []);

  let now = $state(Date.now());
  const liveGauges = $derived(
    (missionCard.data?.gauges || []).filter((gauge) => !gauge.expiresAt || gauge.expiresAt > now),
  );
  const meters = $derived(liveGauges.filter((gauge) => gauge.kind !== "text"));
  const chips = $derived(liveGauges.filter((gauge) => gauge.kind === "text"));

  $effect(() => {
    const next = (missionCard.data?.gauges || []).reduce(
      (soonest, gauge) => (gauge.expiresAt && gauge.expiresAt < soonest ? gauge.expiresAt : soonest),
      Infinity,
    );
    if (next === Infinity) return;
    const timer = setTimeout(() => (now = Date.now()), Math.max(0, next - Date.now()) + 20);
    return () => clearTimeout(timer);
  });

  const stat = $derived(missionCard.data?.stat || undefined);
  const statValue = Tween.of(() => stat?.value ?? 0, { duration: 700, easing: cubicOut });
  let gain = $state(0);
  let gainKey = $state(0);
  let lastValue = untrack(() => stat?.value ?? 0);
  let lastStatId = untrack(() => stat?.id);

  $effect(() => {
    const value = stat?.value ?? 0;
    const sameStat = stat?.id === lastStatId;
    const diff = value - lastValue;
    lastValue = value;
    lastStatId = stat?.id;
    if (!sameStat) {
      gain = 0;
      return;
    }
    if (diff <= 0) return;
    gain = untrack(() => gain) + diff;
    gainKey = untrack(() => gainKey) + 1;
  });

  $effect(() => {
    if (gainKey === 0) return;
    const timer = setTimeout(() => (gain = 0), GAIN_MS);
    return () => clearTimeout(timer);
  });

  function formatStat(value: number): string {
    const whole = Math.floor(value).toLocaleString("en-US");
    return stat?.format === "money" ? `$${whole}` : whole;
  }
</script>

{#if show && missionCard.data}
  {@const data = missionCard.data}
  <aside class="card" bind:offsetHeight={missionCardLayout.height} transition:fade={{ duration: 150 }}>
    <header class="head">
      <span class="head-icon"><MissionIcon size={17} style={square(17)} strokeWidth={2.2} /></span>
      <div class="head-text">
        <span class="title">{data.title}</span>
        {#if meta}<span class="meta">{meta}</span>{/if}
      </div>
      {#if data.badge?.text}
        <span class="tag" transition:fade={{ duration: 150 }}><BadgeIcon size={11} style={square(11)} strokeWidth={2.2} />{data.badge.text}</span>
      {/if}
    </header>

    {#key currentLabel}
      <section class="current" in:fade={{ duration: 150 }}>
        {#if currentLabel}
          <div class="line">
            <span class="mark" class:mark--done={allDone}></span>
            <span class="line-text">{currentLabel}</span>
            {#if stepCount > 1 && !showStepBar}
              <span class="line-count">{stepDone}/{stepCount}</span>
            {/if}
          </div>
        {/if}
        {#if data.detail && !compactSteps}
          <p class="detail">{data.detail}</p>
        {/if}

        {#if tasks.length > 0}
          <ul class="rows">
            {#each tasks as task, index (task.id ?? index)}
              <li class="row" class:done={task.done} class:active={task.id !== undefined && task.id === activeTask}>
                <span class="mark"></span>
                <span class="row-label">{task.label}</span>
                {#if task.count}
                  <span class="row-count">{task.progress ?? 0}/{task.count}</span>
                {/if}
              </li>
            {/each}
          </ul>
        {:else if showStepBar}
          <ObjectiveTrack value={stepDone} max={stepCount} />
        {/if}
      </section>
    {/key}

    {#if compactSteps}
      {#if nextStep}
        <div class="next section">
          <span class="eyebrow">Next</span>
          <span class="next-text">{nextStep.label}</span>
        </div>
      {/if}
    {:else if total > 0}
      <ul class="rows section">
        {#if hiddenBefore > 0}
          <li class="row-more">{hiddenBefore} completed</li>
        {/if}
        {#each visibleSteps as { step, index } (step.id ?? index)}
          <li class="row" class:done={step.done} class:active={index === activeIndex}>
            <span class="mark"></span>
            <span class="row-label">{step.label}</span>
            {#if step.count && step.count > 1 && !step.done && index !== activeIndex}
              <span class="row-count">{step.progress ?? 0}/{step.count}</span>
            {/if}
          </li>
        {/each}
        {#if hiddenAfter > 0}
          <li class="row-more">+{hiddenAfter} more</li>
        {/if}
      </ul>
    {/if}

    {#if optional.length > 0}
      <div class="optional section" transition:fade={{ duration: 150 }}>
        <span class="eyebrow">Optional</span>
        <ul class="rows">
          {#each optional as item, index (item.id ?? index)}
            <li class="row row--optional" class:done={item.done} transition:fade={{ duration: 150 }}>
              <span class="mark mark--hollow"></span>
              <span class="row-label">{item.label}</span>
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    {#if meters.length > 0 || chips.length > 0}
      <section class="gauges section">
        {#each meters as gauge (gauge.id)}
          <div transition:fade={{ duration: 150 }}><MissionGaugeView {gauge} /></div>
        {/each}
        {#if chips.length > 0}
          <div class="chips">
            {#each chips as chip (chip.id)}
              {@const ChipIcon = icon(chip.icon)}
              <span class="chip tone-{chip.tone ?? 'normal'}" transition:fade={{ duration: 150 }}>
                <span class="chip-icon"><ChipIcon size={12} style={square(12)} strokeWidth={2.2} /></span>
                {#if chip.label}<span class="chip-label">{chip.label}</span>{/if}
                <span class="chip-text">{chip.text ?? ""}</span>
              </span>
            {/each}
          </div>
        {/if}
      </section>
    {/if}

    {#if stat}
      <footer class="stat-row section">
        <span class="stat-label"><StatIcon size={13} style={square(13)} strokeWidth={2.2} />{stat.label}</span>
        <span class="stat">
          {#if gain > 0}
            {#key gainKey}
              <span class="gain" in:fly={{ y: 4, duration: 150 }} out:fade={{ duration: 150 }}>+{formatStat(gain)}</span>
            {/key}
          {/if}
          <span class="stat-value" class:money={stat.format === "money"}>{formatStat(statValue.current)}</span>
        </span>
      </footer>
    {:else if total > 0}
      <footer class="section">
        <ObjectiveTrack value={completed} max={total} />
      </footer>
    {/if}

    {#if data.hint}
      <div class="hint section" transition:fade={{ duration: 150 }}>
        <Navigation size={12} style={square(12)} strokeWidth={2.4} />
        <span>{data.hint}</span>
      </div>
    {/if}
  </aside>
{/if}

<style>
  /* Same family as the rm-hud objective card: solid #141517 panel, #26272b border, 4px radius,
     30px square icon tile, uppercase title, 5px square marks, 17px track with a centered count tag.
     Flat, no tilt, no glow, no circles. */
  .card {
    position: fixed;
    top: 50%;
    right: calc(20 * var(--vp));
    z-index: 100;
    display: flex;
    flex-direction: column;
    gap: calc(12 * var(--vp));
    box-sizing: border-box;
    width: calc(320 * var(--vp));
    padding: calc(16 * var(--vp)) calc(16 * var(--vp)) calc(14 * var(--vp));
    overflow: hidden;
    background: var(--bg-frame);
    border: 1px solid var(--border);
    border-radius: 4px;
    box-shadow: 0 calc(10 * var(--vp)) calc(30 * var(--vp)) rgba(0, 0, 0, 0.35);
    color: var(--text);
    font-family: "Tussilago", "Segoe UI", sans-serif;
    font-size: calc(12.5 * var(--vp));
    pointer-events: none;
    transform: translateY(-50%);
  }

  ul {
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .section {
    padding-top: calc(12 * var(--vp));
    border-top: 1px solid var(--border);
  }

  /* Header */
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

  .meta,
  .eyebrow {
    overflow: hidden;
    color: var(--muted);
    font-size: calc(10 * var(--vp));
    letter-spacing: 0.12em;
    text-overflow: ellipsis;
    text-transform: uppercase;
    white-space: nowrap;
  }

  .tag {
    display: inline-flex;
    align-items: center;
    gap: calc(5 * var(--vp));
    flex-shrink: 0;
    padding: 0 calc(7 * var(--vp));
    border-radius: 2px;
    background: #101113;
    border: 1px solid var(--border-strong);
    color: var(--white);
    font-size: calc(10.5 * var(--vp));
    font-variant-numeric: tabular-nums;
    line-height: calc(18 * var(--vp));
  }

  /* Current objective */
  .current {
    display: flex;
    flex-direction: column;
    gap: calc(8 * var(--vp));
  }

  .line {
    display: flex;
    align-items: center;
    gap: calc(8 * var(--vp));
  }

  .line-text {
    flex: 1;
    min-width: 0;
    color: var(--white);
    font-size: calc(13 * var(--vp));
    line-height: 1.35;
  }

  .line-count,
  .row-count {
    flex-shrink: 0;
    color: var(--muted);
    font-size: calc(11 * var(--vp));
    font-variant-numeric: tabular-nums;
  }

  .detail {
    margin: 0;
    color: var(--muted);
    font-size: calc(11.5 * var(--vp));
    line-height: 1.45;
    white-space: pre-line;
  }

  /* 5px square marks: blue = current, green = done, grey = waiting */
  .mark {
    flex-shrink: 0;
    width: calc(5 * var(--vp));
    height: calc(5 * var(--vp));
    min-width: 3px;
    min-height: 3px;
    background: var(--blue);
    transition: background 150ms ease;
  }

  .mark--done {
    background: var(--green);
  }

  /* Step / task rows */
  .rows {
    display: flex;
    flex-direction: column;
    gap: calc(7 * var(--vp));
  }

  .row {
    display: flex;
    align-items: center;
    gap: calc(8 * var(--vp));
    color: var(--text);
    font-size: calc(12 * var(--vp));
    line-height: 1.35;
    transition: color 150ms ease;
  }

  .row .mark {
    background: var(--dim);
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

  .row-more {
    padding-left: calc(13 * var(--vp));
    color: var(--dim);
    font-size: calc(11 * var(--vp));
  }

  /* Optional side objectives */
  .optional {
    display: flex;
    flex-direction: column;
    gap: calc(8 * var(--vp));
  }

  .row--optional {
    font-size: calc(11.5 * var(--vp));
  }

  .row .mark--hollow {
    box-sizing: border-box;
    background: transparent;
    border: 1px solid var(--dim);
  }

  .row.done .mark--hollow {
    background: var(--green);
    border-color: var(--green);
  }

  .next {
    display: flex;
    align-items: baseline;
    gap: calc(8 * var(--vp));
  }

  .next-text {
    min-width: 0;
    overflow: hidden;
    color: var(--text);
    font-size: calc(11.5 * var(--vp));
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Gauges + chips */
  .gauges {
    display: flex;
    flex-direction: column;
    gap: calc(10 * var(--vp));
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: calc(6 * var(--vp));
  }

  .chip {
    --tone: var(--muted);
    display: inline-flex;
    align-items: center;
    gap: calc(6 * var(--vp));
    max-width: 100%;
    height: calc(22 * var(--vp));
    padding: 0 calc(8 * var(--vp));
    border-radius: 2px;
    background: var(--bg-field);
    border: 1px solid var(--border-strong);
    font-size: calc(11 * var(--vp));
    transition:
      background 150ms ease,
      border-color 150ms ease;
  }

  .chip.tone-ok {
    --tone: var(--green);
    background: var(--tint-green);
    border-color: var(--line-green);
  }

  .chip.tone-accent {
    --tone: var(--blue);
    background: var(--tint-blue);
    border-color: var(--line-blue);
  }

  .chip.tone-warn {
    --tone: var(--orange);
    background: var(--tint-orange);
    border-color: var(--line-orange);
  }

  .chip.tone-danger {
    --tone: var(--red);
    background: var(--tint-red);
    border-color: var(--line-red);
  }

  .chip-icon {
    display: flex;
    flex-shrink: 0;
    color: var(--tone);
  }

  .chip-label {
    flex-shrink: 0;
    color: var(--muted);
  }

  .chip-text {
    min-width: 0;
    overflow: hidden;
    color: var(--white);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Stat footer */
  .stat-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .stat-label {
    display: inline-flex;
    align-items: center;
    gap: calc(7 * var(--vp));
    color: var(--muted);
    font-size: calc(12 * var(--vp));
  }

  .stat {
    display: inline-flex;
    align-items: baseline;
    gap: calc(8 * var(--vp));
  }

  .stat-value {
    color: var(--white);
    font-size: calc(16 * var(--vp));
    font-variant-numeric: tabular-nums;
  }

  .stat-value.money,
  .gain {
    color: var(--green);
  }

  .gain {
    font-size: calc(11 * var(--vp));
    font-variant-numeric: tabular-nums;
  }

  .hint {
    display: flex;
    align-items: center;
    gap: calc(8 * var(--vp));
    color: var(--text);
    font-size: calc(11.5 * var(--vp));
    line-height: 1.35;
  }

  .hint :global(svg) {
    flex-shrink: 0;
    color: var(--blue);
  }
</style>
