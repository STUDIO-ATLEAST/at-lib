<script lang="ts">
  import { onMount, untrack } from "svelte";
  import { Tween } from "svelte/motion";
  import { cubicOut } from "svelte/easing";
  import { fade, fly } from "svelte/transition";
  import Check from "@lucide/svelte/icons/check";
  import Navigation from "@lucide/svelte/icons/navigation";
  import MissionGaugeView from "./MissionGauge.svelte";
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

  const MAX_SEGMENTS = 20;
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
  const stepSlots = $derived(
    showStepBar && stepCount <= MAX_SEGMENTS ? Array.from({ length: stepCount }, (_, index) => index) : [],
  );
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
  const segments = $derived(
    total <= MAX_SEGMENTS ? Array.from({ length: total }, (_, index) => index) : [],
  );

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
    <header class="header">
      <div class="mission-icon"><MissionIcon size={16} style={square(16)} strokeWidth={2.2} /></div>
      <div class="mission">
        <span class="mission-label">{data.title}</span>
        {#if meta}<span class="mission-meta">{meta}</span>{/if}
      </div>
      {#if data.badge?.text}
        <span class="badge" transition:fade={{ duration: 150 }}><BadgeIcon size={12} style={square(12)} strokeWidth={2.2} />{data.badge.text}</span>
      {/if}
    </header>

    <section class="stage">
      {#key currentLabel}
        <div class="stage-current" in:fade={{ duration: 150 }}>
          <div class="stage-head">
            <span class="stage-label">{currentLabel}</span>
            {#if stepCount > 1}
              <span class="stage-count">{stepDone} / {stepCount}</span>
            {/if}
          </div>
          {#if data.detail && !compactSteps}
            <p class="detail">{data.detail}</p>
          {/if}

          {#if tasks.length > 0}
            <ul class="tasks">
              {#each tasks as task, index (task.id ?? index)}
                <li class="task" class:done={task.done} class:active={task.id !== undefined && task.id === activeTask}>
                  <span class="tick">
                    {#if task.done}<Check size={10} style={square(10)} strokeWidth={3} />{/if}
                  </span>
                  <span class="task-label">{task.label}</span>
                  {#if task.count}
                    <span class="task-count">{task.progress ?? 0}/{task.count}</span>
                  {/if}
                </li>
              {/each}
            </ul>
          {:else if showStepBar}
            {#if stepSlots.length > 0}
              <div class="segments">
                {#each stepSlots as index (index)}
                  <span class="segment" class:filled={index < stepDone}></span>
                {/each}
              </div>
            {:else}
              <div class="track"><div class="fill" style:width="{(stepDone / stepCount) * 100}%"></div></div>
            {/if}
          {/if}
        </div>
      {/key}

      {#if compactSteps}
        {#if nextStep}
          <div class="next">
            <span class="next-label">Next</span>
            <span class="next-text">{nextStep.label}</span>
          </div>
        {/if}
      {:else if total > 0}
        <ul class="checklist">
          {#if hiddenBefore > 0}
            <li class="step-more">{hiddenBefore} completed</li>
          {/if}
          {#each visibleSteps as { step, index } (step.id ?? index)}
            <li class="task" class:done={step.done} class:active={index === activeIndex}>
              <span class="tick">
                {#if step.done}<Check size={10} style={square(10)} strokeWidth={3} />{/if}
              </span>
              <span class="task-label">{step.label}</span>
              {#if step.count && step.count > 1 && !step.done && index !== activeIndex}
                <span class="task-count">{step.progress ?? 0}/{step.count}</span>
              {/if}
            </li>
          {/each}
          {#if hiddenAfter > 0}
            <li class="step-more">+{hiddenAfter} more</li>
          {/if}
        </ul>
      {/if}

      {#if optional.length > 0}
        <div class="optional" transition:fade={{ duration: 150 }}>
          <span class="optional-title">Optional</span>
          <ul class="optional-list">
            {#each optional as item, index (item.id ?? index)}
              <li class="optional-item" class:done={item.done} transition:fade={{ duration: 150 }}>
                <span class="optional-tick">
                  {#if item.done}<Check size={8} style={square(8)} strokeWidth={3} />{/if}
                </span>
                <span class="optional-label">{item.label}</span>
              </li>
            {/each}
          </ul>
        </div>
      {/if}
    </section>

    {#if meters.length > 0 || chips.length > 0}
      <section class="gauges">
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
      <footer class="footer">
        <div class="footer-row">
          <span class="progress-label"><StatIcon size={13} style={square(13)} strokeWidth={2.2} />{stat.label}</span>
          <span class="stat">
            {#if gain > 0}
              {#key gainKey}
                <span class="gain" in:fly={{ y: 4, duration: 150 }} out:fade={{ duration: 150 }}>+{formatStat(gain)}</span>
              {/key}
            {/if}
            <span class="stat-value" class:money={stat.format === "money"}>{formatStat(statValue.current)}</span>
          </span>
        </div>
      </footer>
    {:else if total > 0}
      <footer class="footer">
        <div class="footer-row">
          <span class="progress-label"><ListChecks size={13} style={square(13)} strokeWidth={2.2} />Progress</span>
          <span class="progress-value">{completed} / {total}</span>
        </div>
        {#if segments.length > 0}
          <div class="segments">
            {#each segments as index (index)}
              <span class="segment" class:filled={index < completed}></span>
            {/each}
          </div>
        {:else}
          <div class="track"><div class="fill" style:width="{(completed / total) * 100}%"></div></div>
        {/if}
      </footer>
    {/if}

    {#if data.hint}
      <div class="hint" transition:fade={{ duration: 150 }}>
        <Navigation size={12} style={square(12)} strokeWidth={2.4} />
        <span>{data.hint}</span>
      </div>
    {/if}
  </aside>
{/if}

<style>
  /* Element theme mission card: solid panel, #141517 header strip, tinted icon tile,
     neutral grey rows, solid tinted chips. Flat, no tilt, no glow. */
  .card {
    position: fixed;
    top: 50%;
    right: calc(24 * var(--vp));
    z-index: 100;
    display: flex;
    flex-direction: column;
    width: calc(280 * var(--vp));
    overflow: hidden;
    background: var(--bg-panel);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    box-shadow: var(--shadow);
    color: var(--text);
    font-family: "Tussilago", "Segoe UI", sans-serif;
    font-size: calc(13 * var(--vp));
    pointer-events: none;
    transform: translateY(-50%);
  }

  ul {
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .header {
    display: flex;
    align-items: center;
    gap: calc(10 * var(--vp));
    padding: calc(10 * var(--vp)) calc(12 * var(--vp));
    background: var(--bg-frame);
    border-bottom: 1px solid var(--border);
  }

  .mission-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: calc(34 * var(--vp));
    height: calc(34 * var(--vp));
    border-radius: var(--radius-sm);
    background: var(--tint-blue);
    color: var(--blue);
  }

  .mission {
    display: flex;
    flex: 1;
    flex-direction: column;
    gap: calc(2 * var(--vp));
    min-width: 0;
  }

  .mission-label {
    overflow: hidden;
    color: var(--white);
    font-size: calc(14 * var(--vp));
    font-weight: 700;
    line-height: 1.25;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .mission-meta {
    color: var(--muted);
    font-size: calc(10 * var(--vp));
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .badge {
    display: inline-flex;
    align-items: center;
    gap: calc(5 * var(--vp));
    flex-shrink: 0;
    height: calc(22 * var(--vp));
    padding: 0 calc(8 * var(--vp));
    border-radius: var(--radius-sm);
    background: var(--bg-field);
    border: 1px solid var(--border-strong);
    color: var(--white);
    font-size: calc(11 * var(--vp));
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  .stage {
    display: flex;
    flex-direction: column;
    gap: calc(8 * var(--vp));
    padding: calc(10 * var(--vp)) calc(12 * var(--vp));
  }

  .stage-current {
    display: flex;
    flex-direction: column;
    gap: calc(5 * var(--vp));
  }

  .stage-head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: calc(10 * var(--vp));
  }

  .stage-label {
    color: var(--white);
    font-size: calc(14 * var(--vp));
    font-weight: 700;
    line-height: 1.3;
  }

  .stage-count {
    flex-shrink: 0;
    color: var(--blue);
    font-size: calc(12 * var(--vp));
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  .detail {
    margin: 0;
    color: var(--muted);
    font-size: calc(12 * var(--vp));
    line-height: 1.4;
    white-space: pre-line;
  }

  .checklist,
  .optional,
  .next {
    padding-top: calc(8 * var(--vp));
    border-top: 1px solid var(--border);
  }

  .checklist {
    display: flex;
    flex-direction: column;
    gap: calc(5 * var(--vp));
  }

  .tasks {
    display: flex;
    flex-direction: column;
    gap: calc(5 * var(--vp));
    margin-top: calc(3 * var(--vp));
  }

  .task {
    display: flex;
    align-items: flex-start;
    gap: calc(8 * var(--vp));
    padding: calc(7 * var(--vp)) calc(8 * var(--vp));
    border-radius: var(--radius-sm);
    background: var(--bg-field);
    border: 1px solid var(--border-strong);
    color: var(--text);
    font-size: calc(12 * var(--vp));
    line-height: calc(14 * var(--vp));
    transition:
      color 150ms ease,
      background 150ms ease,
      border-color 150ms ease;
  }

  .task.active {
    background: var(--bg-hover);
    border-color: var(--border-hover);
    color: var(--white);
  }

  .task.done {
    background: var(--bg-raised);
    border-color: var(--border);
    color: var(--muted);
  }

  .tick {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: calc(14 * var(--vp));
    height: calc(14 * var(--vp));
    border-radius: calc(3 * var(--vp));
    background: var(--bg-frame);
    border: 1px solid var(--border-hover);
    color: var(--green);
    transition:
      background 150ms ease,
      border-color 150ms ease;
  }

  .task.active .tick {
    background: var(--tint-blue);
    border-color: var(--blue);
  }

  .task.done .tick {
    background: var(--tint-green);
    border-color: var(--line-green);
  }

  .task-label {
    flex: 1;
    min-width: 0;
  }

  .task.done .task-label {
    text-decoration: line-through;
    text-decoration-color: var(--dim);
  }

  .task-count {
    flex-shrink: 0;
    color: var(--muted);
    font-size: calc(11 * var(--vp));
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  .optional {
    display: flex;
    flex-direction: column;
    gap: calc(5 * var(--vp));
  }

  .optional-title,
  .next-label {
    flex-shrink: 0;
    color: var(--muted);
    font-size: calc(10 * var(--vp));
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .optional-list {
    display: flex;
    flex-direction: column;
    gap: calc(5 * var(--vp));
  }

  .optional-item {
    display: flex;
    align-items: flex-start;
    gap: calc(8 * var(--vp));
    color: var(--text);
    font-size: calc(11 * var(--vp));
    line-height: calc(12 * var(--vp));
    transition: color 150ms ease;
  }

  .optional-item.done {
    color: var(--dim);
  }

  .optional-tick {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: calc(12 * var(--vp));
    height: calc(12 * var(--vp));
    margin: 0 1px;
    border-radius: calc(2 * var(--vp));
    background: var(--bg-frame);
    border: 1px solid var(--border-hover);
    color: var(--green);
    transition:
      background 150ms ease,
      border-color 150ms ease;
  }

  .optional-item.done .optional-tick {
    background: var(--tint-green);
    border-color: var(--line-green);
  }

  .optional-label {
    flex: 1;
    min-width: 0;
  }

  .optional-item.done .optional-label {
    text-decoration: line-through;
    text-decoration-color: var(--dim);
  }

  .next {
    display: flex;
    align-items: baseline;
    gap: calc(8 * var(--vp));
    font-size: calc(11 * var(--vp));
  }

  .next-text {
    min-width: 0;
    overflow: hidden;
    color: var(--text);
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .step-more {
    padding-left: calc(8 * var(--vp));
    color: var(--dim);
    font-size: calc(11 * var(--vp));
  }

  .gauges {
    display: flex;
    flex-direction: column;
    gap: calc(8 * var(--vp));
    padding: calc(10 * var(--vp)) calc(12 * var(--vp));
    border-top: 1px solid var(--border);
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
    height: calc(24 * var(--vp));
    padding: 0 calc(9 * var(--vp));
    border-radius: var(--radius-sm);
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
    font-weight: 700;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .footer {
    display: flex;
    flex-direction: column;
    gap: calc(7 * var(--vp));
    padding: calc(9 * var(--vp)) calc(12 * var(--vp)) calc(11 * var(--vp));
    background: var(--bg-frame);
    border-top: 1px solid var(--border);
  }

  .footer-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .progress-label {
    display: inline-flex;
    align-items: center;
    gap: calc(7 * var(--vp));
    color: var(--muted);
    font-size: calc(12 * var(--vp));
  }

  .progress-value {
    color: var(--white);
    font-size: calc(14 * var(--vp));
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  .segments {
    display: flex;
    gap: calc(3 * var(--vp));
  }

  .segment {
    flex: 1;
    height: calc(6 * var(--vp));
    border-radius: calc(2 * var(--vp));
    background: var(--bg-sidebar);
    transition: background 150ms ease;
  }

  .segment.filled {
    background: var(--blue);
  }

  .track {
    height: calc(6 * var(--vp));
    overflow: hidden;
    border-radius: calc(2 * var(--vp));
    background: var(--bg-sidebar);
  }

  .fill {
    height: 100%;
    border-radius: calc(2 * var(--vp));
    background: var(--blue);
    transition: width 400ms cubic-bezier(0.22, 1, 0.36, 1);
  }

  .stage-current .segments,
  .stage-current .track {
    margin-top: calc(3 * var(--vp));
  }

  .stat {
    display: inline-flex;
    align-items: baseline;
    gap: calc(8 * var(--vp));
  }

  .stat-value {
    color: var(--white);
    font-size: calc(16 * var(--vp));
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  .stat-value.money,
  .gain {
    color: var(--green);
  }

  .gain {
    font-size: calc(11 * var(--vp));
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  .hint {
    display: flex;
    align-items: center;
    gap: calc(8 * var(--vp));
    padding: calc(8 * var(--vp)) calc(12 * var(--vp));
    border-top: 1px solid var(--border);
    background: var(--tint-blue);
    color: var(--blue);
    font-size: calc(11.5 * var(--vp));
    font-weight: 600;
    line-height: 1.35;
  }

  .hint :global(svg) {
    flex-shrink: 0;
  }
</style>
