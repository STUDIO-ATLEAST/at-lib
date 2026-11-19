<script lang="ts">
  import { untrack } from "svelte";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import { fetchNui } from "../../../../utils/fetchNui";
  import type { SkillBarConfig } from "../../../../types/minigame";
  import "./SkillBar.css";

  let { config: configProp }: { config: SkillBarConfig } = $props();

  const config = untrack(() => configProp);

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  function randomZone(size: number) {
    const w = clamp(size, 4, 40);
    const maxStart = 100 - w;
    return Math.random() * maxStart;
  }

  const speed = $derived(Math.max(20, config.segmentSpeed));
  const zoneSize = $derived(clamp(config.targetZoneSize, 4, 40));
  const hitsRequired = $derived(Math.min(10, Math.max(1, config.hitsRequired)));

  let pos = $state(0);
  let zoneStart = $state(0);
  let hits = $state(0);
  let flash = $state<"hit" | "miss" | null>(null);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let runId = $state(0);

  let finishedRef = false;
  let stoppedRef = false;
  let lockRef = false;
  let posRef = 0;
  let dirRef = 1;
  let zoneRef = 0;
  let hitsRef = 0;
  let lastRef = performance.now();

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function tryHit() {
    if (finishedRef || lockRef) return;
    lockRef = true;

    const p = posRef;
    const z0 = zoneRef;
    const z1 = z0 + zoneSize;
    const hit = p >= z0 && p <= z1;
    void fetchNui("minigameInput", { hit });

    if (hit) {
      flash = "hit";
      const nextHits = hitsRef + 1;
      hitsRef = nextHits;
      hits = nextHits;

      if (nextHits >= hitsRequired) {
        stoppedRef = true;
        window.setTimeout(() => void endGame(true), 220);
        return;
      }

      const pause = Math.max(0, config.hitPause ?? 0);
      if (pause > 0) stoppedRef = true;
      window.setTimeout(() => {
        if (finishedRef) return;
        const z = randomZone(zoneSize);
        zoneRef = z;
        zoneStart = z;
        flash = null;
        lockRef = false;
        if (pause > 0) {
          stoppedRef = false;
          runId = performance.now();
        }
      }, Math.max(180, pause));
      return;
    }

    flash = "miss";
    stoppedRef = true;
    window.setTimeout(() => void endGame(false), 240);
  }

  $effect(() => {
    speed;
    hitsRequired;
    const z = randomZone(zoneSize);
    zoneStart = z;
    zoneRef = z;
    pos = 0;
    posRef = 0;
    dirRef = 1;
    hits = 0;
    hitsRef = 0;
    flash = null;
    finished = false;
    result = null;
    finishedRef = false;
    stoppedRef = false;
    lockRef = false;
    lastRef = performance.now();
    runId = performance.now();
  });

  $effect(() => {
    runId;
    const spd = speed;
    lastRef = performance.now();
    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef || stoppedRef) return;
      const dt = Math.min(0.05, (now - lastRef) / 1000);
      lastRef = now;

      let next = posRef + dirRef * spd * dt;
      if (next >= 100) {
        next = 100;
        dirRef = -1;
      } else if (next <= 0) {
        next = 0;
        dirRef = 1;
      }
      posRef = next;
      pos = next;
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
        return;
      }
      if (e.code === "Space" || e.code === "Enter" || e.code === "KeyE") {
        e.preventDefault();
        tryHit();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  const subtitle = $derived(
    result !== null ? (result ? "Success" : "Failed") : `${hits}/${hitsRequired}`
  );
</script>

<div class="mgbar">
  <div
    class={[
      "mgbar__box",
      result === true || flash === "hit" ? "mgbar__box--ok" : "",
      result === false || flash === "miss" ? "mgbar__box--fail" : "",
    ]}
  >
    <kbd class="mgbar__key">E</kbd>
    <button
      type="button"
      aria-label="Skill bar"
      class="mgbar__track"
      disabled={finished}
      onclick={tryHit}
    >
      <div class="mgbar__rail"></div>
      <div class="mgbar__zone" style="left: {zoneStart}%; width: {zoneSize}%"></div>
      <div class="mgbar__pill skillbar__cursor" style="left: {pos}%"></div>
    </button>
    <span class="mgbar__count">{subtitle}</span>
  </div>
</div>
