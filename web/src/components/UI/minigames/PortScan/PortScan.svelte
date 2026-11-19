<script lang="ts">
  import { untrack } from "svelte";
  import Radar from "@lucide/svelte/icons/radar";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { PortScanConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./PortScan.css";

  let { config: configProp }: { config: PortScanConfig } = $props();

  const config = untrack(() => configProp);

  type PortStatus = "open" | "closed" | "secured" | "trapped" | "fake";

  type Port = {
    id: number;
    label: string;
    status: PortStatus;
    scanned: boolean;
  };

  function gridCols(_count: number) {
    return 4;
  }

  function statusLabel(status: PortStatus, lookalike: boolean) {
    if (!lookalike) {
      if (status === "open") return "Open";
      if (status === "closed") return "Closed";
      if (status === "secured") return "Secured";
      if (status === "trapped") return "Trapped";
      return "Open";
    }
    if (status === "open") return "OPEN";
    if (status === "fake") return "0PEN";
    if (status === "closed") return "CLOSE";
    if (status === "secured") return "SECURE";
    return "TRAP";
  }

  function rollStatus(rand: () => number, allowFake: boolean): PortStatus {
    const roll = rand();
    if (roll < 0.22) return "open";
    if (roll < 0.42) return "closed";
    if (roll < 0.62) return "secured";
    if (roll < 0.82) return "trapped";
    return allowFake ? "fake" : "closed";
  }

  function mulberry32(seed: number) {
    let a = seed >>> 0;
    return () => {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function makePorts(count: number): Port[] {
    const ports: Port[] = [];
    const used = new Set<number>();
    while (ports.length < count) {
      const n = 20 + Math.floor(Math.random() * 980);
      if (used.has(n)) continue;
      used.add(n);
      ports.push({
        id: ports.length,
        label: String(n),
        status: "closed",
        scanned: false,
      });
    }
    return ports;
  }

  const portCount = $derived(Math.min(20, Math.max(6, config.ports)));
  const required = $derived(Math.min(12, Math.max(2, config.required)));
  const tickMs = $derived(Math.max(280, config.tick));
  const trapPenalty = $derived(Math.max(500, config.trapPenalty));
  const similar = $derived(!!config.similar);
  const duration = $derived(Math.max(10000, config.duration));
  const allowFake = $derived(similar || portCount >= 10);
  const cols = $derived(gridCols(portCount));

  let ports = $state<Port[]>([]);
  let scans = $state(0);
  let progress = $state(100);
  let flash = $state<{ id: number; kind: "good" | "bad" } | null>(null);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let portsRef: Port[] = [];
  let scansRef = 0;
  let startRef = performance.now();
  let penaltyRef = 0;
  let randRef = mulberry32(Date.now() % 1000000);

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);
  const subtitle = $derived(
    result !== null
      ? result
        ? "Access granted"
        : "Detected"
      : `${scans}/${required} scans`
  );

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function onPortClick(port: Port) {
    if (finishedRef || port.scanned) return;

    if (port.status === "open") {
      const nextScans = scansRef + 1;
      scansRef = nextScans;
      scans = nextScans;
      flash = { id: port.id, kind: "good" };
      const next = portsRef.map((p) =>
        p.id === port.id ? { ...p, scanned: true, status: "open" as PortStatus } : p
      );
      portsRef = next;
      ports = next;
      window.setTimeout(() => (flash = null), 220);
      if (nextScans >= required) {
        window.setTimeout(() => void endGame(true), 200);
      }
      return;
    }

    if (port.status === "trapped" || port.status === "fake") {
      flash = { id: port.id, kind: "bad" };
      penaltyRef += trapPenalty;
      window.setTimeout(() => (flash = null), 220);
      return;
    }

    flash = { id: port.id, kind: "bad" };
    penaltyRef += Math.floor(trapPenalty * 0.35);
    window.setTimeout(() => (flash = null), 220);
  }

  $effect(() => {
    const count = portCount;
    void config.duration;
    const req = required;
    const next = makePorts(count);
    ports = next;
    portsRef = next;
    scans = 0;
    scansRef = 0;
    flash = null;
    finished = false;
    result = null;
    finishedRef = false;
    startRef = performance.now();
    penaltyRef = 0;
    randRef = mulberry32((Date.now() ^ (req * 997)) >>> 0);
    progress = 100;
    runId = untrack(() => runId) + 1;
  });

  $effect(() => {
    if (finished) return;
    void runId;
    const fakeOk = allowFake;
    const interval = tickMs;

    const tick = () => {
      if (finishedRef) return;
      const rand = randRef;
      const next = portsRef.map((p) => {
        if (p.scanned) return p;
        return {
          ...p,
          status: rollStatus(rand, fakeOk),
        };
      });

      const openCount = next.filter(
        (p) => !p.scanned && p.status === "open"
      ).length;
      if (openCount === 0) {
        const candidates = next
          .map((p, i) => ({ p, i }))
          .filter(({ p }) => !p.scanned);
        if (candidates.length) {
          const pick = candidates[Math.floor(rand() * candidates.length)].i;
          next[pick] = { ...next[pick], status: "open" };
        }
      }
      portsRef = next;
      ports = next;
    };

    tick();
    const id = window.setInterval(tick, interval);
    return () => window.clearInterval(id);
  });

  $effect(() => {
    void runId;
    const total = duration;
    const need = required;
    startRef = performance.now();
    penaltyRef = 0;
    progress = 100;

    let raf = 0;
    const loop = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - startRef + penaltyRef;
      const left = Math.max(0, 100 - (elapsed / total) * 100);
      progress = left;
      if (left <= 0) {
        void endGame(scansRef >= need);
        return;
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<div class="mg">
  <div class="mg__card portscan__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Radar class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Port Scan</span>
        <span class="mg__subtitle">{subtitle}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div class="portscan__body">
        <div
          class="portscan__grid"
          style="grid-template-columns: repeat({cols}, 1fr)"
        >
          {#each ports as port (port.id)}
            {@const flashCls =
              flash?.id === port.id
                ? flash.kind === "good"
                  ? "portscan__port--flash-good"
                  : "portscan__port--flash-bad"
                : ""}
            <button
              type="button"
              class={[
                "portscan__port",
                `portscan__port--${port.status}`,
                port.scanned ? "portscan__port--scanned" : "",
                flashCls,
              ]}
              disabled={finished || port.scanned}
              onclick={() => onPortClick(port)}
            >
              <span class="portscan__id">:{port.label}</span>
              <span class="portscan__status">
                {port.scanned ? "SCANNED" : statusLabel(port.status, similar)}
              </span>
            </button>
          {/each}
        </div>

        <div class="portscan__meta">
          <span>
            Target <strong>{required}</strong> open ports
          </span>
          <span>
            Trap cuts <strong>{(trapPenalty / 1000).toFixed(1)}s</strong>
          </span>
        </div>
      </div>
    </div>

    <div class="mg__footer">Click OPEN only - traps cost time - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
