<script lang="ts">
  import { onMount, untrack } from "svelte";
  import Flag from "@lucide/svelte/icons/flag";
  import Users from "@lucide/svelte/icons/users";
  import { onNui } from "../../lib/nui";
  import { border, dark, headerBg } from "../../lib/theme";
  import { mantineSlide } from "../../lib/transitions";
  import {
    closeGangZone,
    devPreview,
    gangZone,
    showGangZone,
    updateGangZone,
  } from "../../stores/hud.svelte";
  import type { GangZoneData, GangZoneSide } from "../../types/hud";
  import { isEnvBrowser } from "../../utils/misc";
  import { vp } from "../../utils/vp";

  const inBrowser = isEnvBrowser();
  const CONTESTED = "#ffd43b";
  const FALLBACK_COLOR = "#868e96";

  let seconds = $state(gangZone.data?.seconds ?? 0);
  let session = $state(0);
  let failedLogos = $state<Record<string, boolean>>({});

  onMount(() => {
    const offs = [
      onNui<GangZoneData>("SHOW_GANGZONE", (data) => {
        showGangZone(data);
        seconds = data.seconds;
        session += 1;
      }),
      onNui<Partial<GangZoneData>>("UPDATE_GANGZONE", (data) => {
        updateGangZone(data);
        if (typeof data.seconds === "number") {
          seconds = data.seconds;
          session += 1;
        }
      }),
      onNui("CLOSE_GANGZONE", () => closeGangZone()),
    ];
    return () => offs.forEach((off) => off());
  });

  const show = $derived(
    gangZone.visible && !!gangZone.data && (!inBrowser || devPreview.toggles.gangZone),
  );

  $effect(() => {
    session;
    if (!show) return;

    if (untrack(() => seconds) <= 0) {
      const next = gangZone.data?.seconds ?? 0;
      if (next <= 0) return;
      seconds = next;
    }

    const id = window.setInterval(() => {
      seconds = Math.max(0, seconds - 1);
    }, 1000);

    return () => window.clearInterval(id);
  });

  function formatTime(total: number): string {
    const s = Math.max(0, Math.floor(total));
    return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}`;
  }

  // team colour mixed over the #141517 header strip, kept solid so it never goes see-through
  function tint(hex: string | undefined, alpha: number): string {
    if (!hex) return headerBg;
    const clean = hex.replace("#", "");
    const r = parseInt(clean.substring(0, 2), 16);
    const g = parseInt(clean.substring(2, 4), 16);
    const b = parseInt(clean.substring(4, 6), 16);
    if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) return headerBg;
    const mix = (c: number, base: number) => Math.round(base + (c - base) * alpha);
    return `rgb(${mix(r, 0x14)}, ${mix(g, 0x15)}, ${mix(b, 0x17)})`;
  }

  const view = $derived.by(() => {
    const data = gangZone.data;
    if (!data) return null;
    const owner = data.owner ?? null;
    const holder = owner ? data[owner] : null;
    const challengerSide = owner === "left" ? "right" : owner === "right" ? "left" : null;
    const challenger = challengerSide ? data[challengerSide] : null;
    const holderCount = owner === "left" ? data.leftCount : owner === "right" ? data.rightCount : undefined;
    const challengerCount = owner === "left" ? data.rightCount : owner === "right" ? data.leftCount : undefined;
    const percent = Math.max(0, Math.min(100, data.percent ?? 0));

    let status = data.status;
    if (!status && holderCount !== undefined && challengerCount !== undefined) {
      if (holderCount === 0 && challengerCount === 0) status = "idle";
      else if (holderCount === challengerCount) status = "contested";
      else if (holderCount > challengerCount) status = percent >= 100 ? "held" : "securing";
      else status = "takeover";
    }

    let text = holder ? `${holder.name} holds the point` : "Nobody holds the point";
    let color = holder?.color ?? FALLBACK_COLOR;
    if (status === "contested") {
      text = "Contested - hold paused";
      color = CONTESTED;
    } else if (status === "takeover" && challenger) {
      text = `${challenger.name} taking over`;
      color = challenger.color ?? FALLBACK_COLOR;
    } else if (status === "securing" && holder) {
      text = `${holder.name} securing the hold`;
    } else if (status === "held" && holder) {
      text = `${holder.name} in full control`;
    } else if (status === "idle") {
      text = holder ? `Point empty - ${holder.name} keeps the hold` : "Point empty";
      color = dark[2];
    }

    return { data, owner, holder, percent, status, text, color };
  });
</script>

{#snippet logo(side: GangZoneSide, slot: string)}
  <div class="zone-logo" style={`width: ${vp(34)}; height: ${vp(34)}; border-radius: var(--radius);`}>
    {#if side.logo && !failedLogos[slot]}
      <img src={side.logo} alt="" onerror={() => (failedLogos = { ...failedLogos, [slot]: true })} />
    {:else}
      <Flag color="#909296" style={`width: ${vp(16)}; height: ${vp(16)};`} />
    {/if}
  </div>
{/snippet}

{#snippet sideInfo(side: GangZoneSide, count: number | undefined, holding: boolean, align: "left" | "right")}
  <div class="zone-info" style={`gap: ${vp(3)}; align-items: ${align === "left" ? "flex-start" : "flex-end"};`}>
    <span class="zone-name" style={`font-size: ${vp(13)};`}>{side.name}</span>
    <span class="zone-meta" style={`gap: ${vp(6)}; font-size: ${vp(10.5)}; justify-content: ${align === "left" ? "flex-start" : "flex-end"};`}>
      {#if holding}
        <span class="zone-tag" style={`padding: ${vp(1)} ${vp(5)}; border-radius: ${vp(3)};`}>Holding</span>
      {/if}
      {#if count !== undefined}
        <span class="zone-count" style={`gap: ${vp(3)};`}>
          <Users style={`width: ${vp(11)}; height: ${vp(11)};`} />{count} on point
        </span>
      {/if}
    </span>
  </div>
{/snippet}

{#if show && view}
  {@const data = view.data}
  <div class="zone-anchor" style={`top: ${vp(24)};`}>
    <div
      class="el-panel zone-panel"
      style={`width: min(${vp(560)}, calc(100vw / var(--ui-scale, 1) - ${vp(32)}));`}
      transition:mantineSlide={{ axis: "y", distance: "-100%", duration: 250 }}
    >
      <div class="zone-head">
        <div
          class="zone-side"
          style={`gap: ${vp(10)}; padding: ${vp(9)} ${vp(12)};
            background: ${view.owner === "left" ? tint(data.left.color, 0.22) : headerBg};`}
        >
          {@render logo(data.left, "left")}
          {@render sideInfo(data.left, data.leftCount, view.owner === "left", "left")}
        </div>

        <div
          class="zone-center"
          style={`gap: ${vp(3)}; min-width: ${vp(92)}; padding: ${vp(6)} ${vp(10)};
            border-left: ${border}; border-right: ${border};`}
        >
          <span class="zone-time" style={`font-size: ${vp(17)};`}>{formatTime(seconds)}</span>
          <span class="zone-time-label" style={`font-size: ${vp(9)}; color: ${dark[2]};`}>holder wins</span>
        </div>

        <div
          class="zone-side zone-side--right"
          style={`gap: ${vp(10)}; padding: ${vp(9)} ${vp(12)};
            background: ${view.owner === "right" ? tint(data.right.color, 0.22) : headerBg};`}
        >
          {@render sideInfo(data.right, data.rightCount, view.owner === "right", "right")}
          {@render logo(data.right, "right")}
        </div>
      </div>

      <div class="zone-foot" style={`gap: ${vp(6)}; padding: ${vp(8)} ${vp(12)} ${vp(10)};`}>
        <div class="zone-status" style={`gap: ${vp(8)}; font-size: ${vp(11.5)};`}>
          <span class="zone-dot" class:zone-dot--pulse={view.status === "takeover" || view.status === "contested"}
            style={`width: ${vp(7)}; height: ${vp(7)}; background: ${view.color};`}></span>
          <span class="zone-status-text">{view.text}</span>
          <span class="el-badge">{Math.round(view.percent)}%</span>
        </div>
        <div class="zone-bar" style={`height: ${vp(8)}; border-radius: ${vp(2)};`}>
          <div
            class="zone-bar__fill"
            class:zone-bar__fill--right={view.owner === "right"}
            class:zone-bar__fill--draining={view.status === "takeover"}
            style={`width: ${view.percent}%; background-color: ${view.holder?.color ?? FALLBACK_COLOR};`}
          ></div>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .zone-anchor {
    position: fixed;
    left: 50%;
    transform: translateX(-50%);
    pointer-events: none;
    z-index: 99;
  }

  .zone-panel {
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .zone-head {
    display: flex;
    align-items: stretch;
  }

  .zone-side {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: center;
    transition: background-color 0.4s ease;
  }

  .zone-side--right {
    justify-content: flex-end;
  }

  .zone-logo {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    border: 1px solid var(--border-strong);
    background: var(--bg-field);
  }

  .zone-logo img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .zone-info {
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .zone-name {
    max-width: 100%;
    font-weight: 700;
    color: var(--white);
    line-height: 1.1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .zone-meta {
    display: flex;
    flex-wrap: wrap;
    row-gap: 3px;
    max-width: 100%;
    align-items: center;
    color: var(--text);
    font-weight: 600;
    line-height: 1;
  }

  .zone-tag {
    background: var(--bg-frame);
    color: var(--white);
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .zone-count {
    display: inline-flex;
    align-items: center;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }

  .zone-center {
    background: var(--bg-frame);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  .zone-time {
    font-weight: 800;
    line-height: 1;
    color: var(--white);
    font-variant-numeric: tabular-nums;
  }

  .zone-time-label {
    font-weight: 600;
    line-height: 1;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .zone-foot {
    display: flex;
    flex-direction: column;
    border-top: 1px solid var(--border);
  }

  .zone-status {
    display: flex;
    align-items: center;
    color: var(--white);
    font-weight: 600;
    line-height: 1;
  }

  .zone-status-text {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .zone-dot {
    flex-shrink: 0;
    border-radius: 2px;
  }

  .zone-dot--pulse {
    animation: zone-pulse 1s ease-in-out infinite;
  }


  .zone-bar {
    position: relative;
    overflow: hidden;
    background: var(--bg-sidebar);
    border: 1px solid var(--border);
  }

  .zone-bar__fill {
    position: absolute;
    top: 0;
    bottom: 0;
    left: 0;
    transition: width 0.9s linear, background-color 0.4s ease;
  }

  .zone-bar__fill--right {
    left: auto;
    right: 0;
  }

  .zone-bar__fill--draining {
    background-image: repeating-linear-gradient(
      -45deg,
      #141517 0,
      #141517 4px,
      transparent 4px,
      transparent 12px
    );
    background-size: 17px 17px;
    animation: zone-drain 0.6s linear infinite;
  }

  @keyframes zone-pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.35; }
  }

  @keyframes zone-drain {
    from { background-position: 0 0; }
    to { background-position: 17px 0; }
  }
</style>
