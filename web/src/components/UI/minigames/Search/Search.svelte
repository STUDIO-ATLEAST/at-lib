<script lang="ts">
  import { untrack } from "svelte";
  import CircleHelp from "@lucide/svelte/icons/circle-help";
  import LoaderCircle from "@lucide/svelte/icons/loader-circle";
  import Package from "@lucide/svelte/icons/package";
  import PackageSearch from "@lucide/svelte/icons/package-search";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { SearchConfig, SearchSlotItem } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Search.css";

  let { config: configProp }: { config: SearchConfig } = $props();

  const config = untrack(() => configProp);

  type SlotState = "sealed" | "searching" | "open";

  type FoundItem = {
    id: string;
    count: number;
    metadata?: Record<string, unknown>;
  };

  function normalizeSlots(
    raw: SearchConfig["slots"],
    gridSize: number
  ): (SearchSlotItem | null)[] {
    const totalSlots = gridSize * gridSize;
    const out: (SearchSlotItem | null)[] = Array.from(
      { length: totalSlots },
      () => null
    );
    if (!Array.isArray(raw)) return out;

    for (let i = 0; i < totalSlots; i++) {
      const entry = raw[i];
      if (entry && typeof entry === "object" && "id" in entry && entry.id) {
        out[i] = {
          id: String(entry.id),
          label: String(entry.label || entry.id),
          count: Math.max(1, Number(entry.count) || 1),
          image: entry.image || undefined,
          metadata: entry.metadata,
        };
      }
    }
    return out;
  }

  const size = Math.min(4, Math.max(3, config.size || 3));
  const total = size * size;
  const required = Math.max(1, config.required);
  const searchTime = Math.max(400, config.searchTime);
  const duration = Math.max(8000, config.duration);
  const loot = normalizeSlots(config.slots, size);

  let states = $state<SlotState[]>(
    Array.from({ length: total }, () => "sealed")
  );
  let busy = $state(false);
  let found = $state(0);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);
  let imgBroken = $state<Record<number, boolean>>({});

  let finishedRef = false;
  let busyRef = false;
  let foundRef = 0;
  let foundItemsRef: FoundItem[] = [];
  let started = performance.now();
  let searchTimer: number | null = null;

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    busyRef = false;
    busy = false;
    if (searchTimer !== null) {
      window.clearTimeout(searchTimer);
      searchTimer = null;
    }

    await finishMinigame(success, (ok) => (result = ok), {
      items: foundItemsRef.map((it) => ({
        id: it.id,
        count: it.count,
        metadata: it.metadata,
      })),
    });
  }

  function onSlotClick(index: number) {
    if (finishedRef || busyRef) return;
    if (states[index] !== "sealed") return;

    busyRef = true;
    busy = true;

    const next = [...states];
    next[index] = "searching";
    states = next;

    searchTimer = window.setTimeout(() => {
      searchTimer = null;
      if (finishedRef) return;

      const item = loot[index];
      const opened = [...states];
      opened[index] = "open";
      states = opened;

      if (item) {
        foundItemsRef = [
          ...foundItemsRef,
          {
            id: item.id,
            count: item.count ?? 1,
            metadata: item.metadata,
          },
        ];
        const nextFound = foundRef + 1;
        foundRef = nextFound;
        found = nextFound;
        if (nextFound >= required) {
          window.setTimeout(() => void endGame(true), 220);
          return;
        }
      }

      busyRef = false;
      busy = false;
    }, searchTime);
  }

  $effect(() => {
    started = performance.now();
    let raf = 0;

    const tick = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - started;
      const left = Math.max(0, 100 - (elapsed / duration) * 100);
      progress = left;
      if (left <= 0) {
        void endGame(false);
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
      if (e.code === "Escape") {
        e.preventDefault();
        void endGame(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  $effect(() => {
    return () => {
      if (searchTimer !== null) {
        window.clearTimeout(searchTimer);
      }
    };
  });
</script>

<div class="mg">
  <div class="mg__card search__card">
    <div class="mg__header">
      <div class="mg__heading">
        <PackageSearch class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Search</span>
        <span class="mg__subtitle">{found} / {required}</span>
      </div>
      <div class="mg__timer">
        <div class="mg__timer-track">
          <div class="mg__timer-fill" style="width: {progress}%"></div>
        </div>
        <span class="mg__timer-text">{secondsLeft.toFixed(1)}</span>
      </div>
    </div>

    <div class="mg__body">
      <div
        class="search__grid"
        style="grid-template-columns: repeat({size}, minmax(0, 1fr)); grid-template-rows: repeat({size}, minmax(0, 1fr));"
      >
        {#each states as state, i}
          {@const item = loot[i]}
          {@const showImg = Boolean(item?.image) && !imgBroken[i]}
          <button
            type="button"
            class={[
              "search__slot",
              state === "searching" ? "search__slot--busy" : "",
              state === "open" ? "search__slot--open" : "",
              state === "open" && item ? "search__slot--loot" : "",
            ]}
            disabled={finished || busy || state !== "sealed"}
            onclick={() => onSlotClick(i)}
          >
            {#if state === "sealed"}
              <CircleHelp class="search__q" style={iconSize(2.8)} strokeWidth={1.75} />
            {:else if state === "searching"}
              <LoaderCircle class="search__spin" style={iconSize(2.6)} strokeWidth={2} />
            {:else if state === "open" && item}
              {#if showImg}
                <img
                  class="search__img"
                  src={item.image}
                  alt=""
                  onerror={() => (imgBroken = { ...imgBroken, [i]: true })}
                />
              {:else}
                <Package
                  class="search__item-icon"
                  style={iconSize(2.6)}
                  strokeWidth={1.75}
                />
              {/if}
              <span class="search__label">{item.label}</span>
            {:else if state === "open" && !item}
              <span class="search__empty">-</span>
            {/if}
          </button>
        {/each}
      </div>
    </div>

    <div class="mg__footer">
      Once you close this, you can't loot this package anymore - Esc
    </div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
