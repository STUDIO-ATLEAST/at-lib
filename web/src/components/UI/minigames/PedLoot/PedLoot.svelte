<script lang="ts">
  import { untrack } from "svelte";
  import Ban from "@lucide/svelte/icons/ban";
  import Lock from "@lucide/svelte/icons/lock";
  import Package from "@lucide/svelte/icons/package";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { PedLootConfig, PedLootSlot } from "../../../../types/minigame";
  import { iconSize } from "../../../../utils/vp";
  import "./PedLoot.scss";

  let { config: configProp }: { config: PedLootConfig } = $props();

  const config = untrack(() => configProp);

  type SlotView = {
    empty: boolean;
    item: PedLootSlot | null;
    /** 0-1 green hit window (0 = full fail / empty) */
    window: number;
    chance: number;
    taken: boolean;
  };

  type FoundItem = {
    id: string;
    count: number;
    metadata?: Record<string, unknown>;
    slot?: number;
    sourceIndex?: number;
  };

  function clamp(n: number, min: number, max: number) {
    return Math.min(max, Math.max(min, n));
  }

  function normalizeBoard(
    board: PedLootConfig["board"],
    count: number
  ): SlotView[] {
    const out: SlotView[] = [];
    for (let i = 0; i < count; i++) {
      const entry = board?.[i];
      if (entry && typeof entry === "object" && !entry.empty && entry.id) {
        const chance = clamp(Number(entry.chance) || 30, 1, 100);
        const window = clamp(
          Number(entry.window) || 0.22 + (chance / 100) * 0.66,
          0.18,
          0.92
        );
        out.push({
          empty: false,
          item: {
            id: String(entry.id),
            label: String(entry.label || entry.id),
            count: Math.max(1, Number(entry.count) || 1),
            image: entry.image,
            value: Number(entry.value) || 0,
            chance,
            window,
            metadata: entry.metadata,
            sourceIndex: entry.sourceIndex,
          },
          window,
          chance,
          taken: false,
        });
      } else {
        out.push({ empty: true, item: null, window: 0, chance: 0, taken: false });
      }
    }
    return out;
  }

  function keyLabel(bindKey: string) {
    if (bindKey === "SPACE" || bindKey === " ") return "SPACE";
    return bindKey.slice(0, 1).toUpperCase();
  }

  function localInSlot(pos: number, idx: number, count: number) {
    const start = (idx / count) * 100;
    const width = 100 / count;
    return clamp((pos - start) / width, 0, 1);
  }

  function inGreenWindow(local: number, window: number) {
    if (window <= 0) return false;
    const pad = (1 - window) / 2;
    return local >= pad && local <= pad + window;
  }

  const slotCount = Math.min(8, Math.max(3, config.slotCount || 5));
  const speed = Math.max(30, config.speed);
  const duration = Math.max(5000, config.duration);
  const key = (config.key || "SPACE").toUpperCase();
  const label = keyLabel(key);

  let slots = $state<SlotView[]>(normalizeBoard(config.board, slotCount));
  const required = Math.max(
    1,
    normalizeBoard(config.board, slotCount).filter((s) => !s.empty).length ||
      config.required ||
      1
  );

  let cursor = $state(0);
  let active = $state(0);
  let inWindow = $state(false);
  let found = $state(0);
  let flash = $state<"ok" | "bad" | null>(null);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let imgBroken = $state<Record<number, boolean>>({});
  let timeLeft = $state(100);

  let finishedRef = false;
  let stoppedRef = false;
  let lockRef = false;
  let cursorRef = 0;
  let dirRef = 1;
  let slotsRef = untrack(() => slots);
  let foundRef = 0;
  let foundItemsRef: FoundItem[] = [];
  let last = performance.now();
  let started = performance.now();

  $effect(() => {
    slotsRef = slots;
  });

  const greenZones = $derived.by(() => {
    const zones: { left: number; width: number; taken: boolean }[] = [];
    for (let i = 0; i < slots.length; i++) {
      const slot = slots[i];
      if (!slot || slot.empty || slot.window <= 0) continue;
      const slotStart = (i / slotCount) * 100;
      const slotWidth = 100 / slotCount;
      const winWidth = slot.window * slotWidth;
      const pad = ((1 - slot.window) / 2) * slotWidth;
      zones.push({
        left: slotStart + pad,
        width: winWidth,
        taken: slot.taken,
      });
    }
    return zones;
  });

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok), {
      items: foundItemsRef.map((it) => ({
        id: it.id,
        count: it.count,
        metadata: it.metadata,
        slot: it.slot,
        sourceIndex: it.sourceIndex,
      })),
    });
  }

  function slotFromCursor(pos: number) {
    const idx = Math.floor((pos / 100) * slotCount);
    return Math.min(slotCount - 1, Math.max(0, idx));
  }

  function grab() {
    if (finishedRef || lockRef) return;
    lockRef = true;

    const pos = cursorRef;
    const idx = slotFromCursor(pos);
    const slot = slotsRef[idx];
    const local = localInSlot(pos, idx, slotCount);
    const hitGreen = slot && !slot.empty && inGreenWindow(local, slot.window);

    active = idx;

    if (!slot || slot.empty || !hitGreen) {
      flash = "bad";
      stoppedRef = true;
      // a miss ends the board, but whatever was already grabbed is kept
      window.setTimeout(() => void endGame(foundRef > 0), 240);
      return;
    }

    if (slot.taken) {
      lockRef = false;
      return;
    }

    const next = slots.map((s, i) => (i === idx ? { ...s, taken: true } : s));
    slotsRef = next;
    slots = next;

    if (slot.item?.id) {
      foundItemsRef = [
        ...foundItemsRef,
        {
          id: String(slot.item.id),
          count: slot.item.count ?? 1,
          metadata: slot.item.metadata,
          slot: idx,
          sourceIndex: slot.item.sourceIndex,
        },
      ];
    }

    const nextFound = foundRef + 1;
    foundRef = nextFound;
    found = nextFound;
    flash = "ok";
    if (nextFound >= required) stoppedRef = true;

    window.setTimeout(() => {
      flash = null;
      lockRef = false;
      if (nextFound >= required) {
        void endGame(true);
      }
    }, 180);
  }

  $effect(() => {
    last = performance.now();
    started = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef || stoppedRef) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;

      let next = cursorRef + dirRef * speed * dt;
      if (next >= 100) {
        next = 100;
        dirRef = -1;
      } else if (next <= 0) {
        next = 0;
        dirRef = 1;
      }
      cursorRef = next;
      cursor = next;

      const idx = slotFromCursor(next);
      active = idx;
      const slot = slotsRef[idx];
      const local = localInSlot(next, idx, slotCount);
      inWindow = Boolean(
        slot && !slot.empty && !slot.taken && inGreenWindow(local, slot.window)
      );

      timeLeft = Math.max(0, 100 - ((now - started) / duration) * 100);
      if (now - started >= duration) {
        void endGame(foundRef > 0); // time up: keep what was grabbed
        return;
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  });

  $effect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (finishedRef) return;
      if (e.repeat) return;

      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(foundRef > 0); // walking away keeps what was grabbed
        return;
      }

      const isSpace = key === "SPACE" && e.code === "Space";
      const isLetter =
        key.length === 1 &&
        (e.code === `Key${key}` || e.key.toUpperCase() === key);

      if (isSpace || isLetter) {
        e.preventDefault();
        grab();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });
</script>

<!-- skill-check style: compact bar at the bottom, no backdrop card -->
<div class="mgbar">
  <div
    class={[
      "mgbar__box",
      "mgbar__box--auto",
      "pedloot__box",
      result === true || flash === "ok" ? "mgbar__box--ok" : "",
      result === false || flash === "bad" ? "mgbar__box--fail" : "",
    ]}
  >
    <kbd class="mgbar__key">{label}</kbd>

    <button
      type="button"
      aria-label="Pickpocket"
      class="mgbar__track pedloot__track"
      disabled={finished}
      onclick={grab}
    >
      <div class="pedloot__slots">
        {#each slots as slot, i}
          {@const isActive = i === active && !finished}
          {@const showImg = Boolean(slot.item?.image) && slot.taken && !imgBroken[i]}
          <div
            class={[
              "pedloot__slot",
              isActive ? "pedloot__slot--active" : "",
              isActive && inWindow ? "pedloot__slot--hot" : "",
              slot.empty ? "pedloot__slot--empty" : "",
              slot.taken ? "pedloot__slot--taken" : "",
            ]}
            title={slot.taken && slot.item ? slot.item.label : undefined}
          >
            {#if slot.empty}
              <Ban class="pedloot__icon pedloot__icon--empty" style={iconSize(1.6)} strokeWidth={2} />
            {:else if slot.taken && slot.item}
              {#if showImg}
                <img
                  class="pedloot__img"
                  src={slot.item.image}
                  alt=""
                  onerror={() => (imgBroken = { ...imgBroken, [i]: true })}
                />
              {:else}
                <Package class="pedloot__icon" style={iconSize(1.6)} strokeWidth={2} />
              {/if}
            {:else}
              <Lock class="pedloot__icon pedloot__icon--lock" style={iconSize(1.5)} strokeWidth={2} />
            {/if}
          </div>
        {/each}
      </div>

      <div class="pedloot__bar">
        <div class="mgbar__rail"></div>
        {#each greenZones as zone}
          <div
            class={["mgbar__zone", "pedloot__zone", zone.taken ? "pedloot__zone--taken" : ""]}
            style="left: {zone.left}%; width: {zone.width}%"
          ></div>
        {/each}
        <div
          class={["mgbar__pill", "pedloot__cursor", inWindow ? "pedloot__cursor--hot" : ""]}
          style="left: {cursor}%"
        ></div>
      </div>
    </button>

    <span class="mgbar__count">
      {result !== null
        ? result
          ? found < required ? `Got ${found}/${required}` : "Success"
          : "Failed"
        : `${found}/${required}`}
    </span>

    <div class="mgbar__timer">
      <div class="mgbar__timer-fill" style="width: {timeLeft}%"></div>
    </div>
  </div>
</div>
