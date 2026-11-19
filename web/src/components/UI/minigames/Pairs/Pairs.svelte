<script lang="ts">
  import { untrack } from "svelte";
  import Bell from "@lucide/svelte/icons/bell";
  import Bolt from "@lucide/svelte/icons/bolt";
  import Camera from "@lucide/svelte/icons/camera";
  import Coffee from "@lucide/svelte/icons/coffee";
  import Ghost from "@lucide/svelte/icons/ghost";
  import Heart from "@lucide/svelte/icons/heart";
  import KeyRound from "@lucide/svelte/icons/key-round";
  import Layers from "@lucide/svelte/icons/layers";
  import Moon from "@lucide/svelte/icons/moon";
  import Puzzle from "@lucide/svelte/icons/puzzle";
  import Shield from "@lucide/svelte/icons/shield";
  import Star from "@lucide/svelte/icons/star";
  import Sun from "@lucide/svelte/icons/sun";
  import Target from "@lucide/svelte/icons/target";
  import Wifi from "@lucide/svelte/icons/wifi";
  import { finishMinigame } from "../../../../utils/finishMinigame";
  import type { PairsConfig } from "../../../../types/minigame";
  import MinigameResult from "../../../MinigameResult.svelte";
  import { iconSize } from "../../../../utils/vp";
  import "./Pairs.css";

  let { config: configProp }: { config: PairsConfig } = $props();

  const config = untrack(() => configProp);

  type IconComp = typeof Star;

  type Card = {
    id: number;
    iconKey: string;
    Icon: IconComp;
  };

  const ICON_POOL: { key: string; Icon: IconComp }[] = [
    { key: "star", Icon: Star },
    { key: "heart", Icon: Heart },
    { key: "moon", Icon: Moon },
    { key: "sun", Icon: Sun },
    { key: "bolt", Icon: Bolt },
    { key: "shield", Icon: Shield },
    { key: "key", Icon: KeyRound },
    { key: "camera", Icon: Camera },
    { key: "wifi", Icon: Wifi },
    { key: "coffee", Icon: Coffee },
    { key: "bell", Icon: Bell },
    { key: "ghost", Icon: Ghost },
    { key: "target", Icon: Target },
    { key: "layers", Icon: Layers },
  ];

  function shuffle<T>(list: T[]): T[] {
    const arr = [...list];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  function buildDeck(count: number): Card[] {
    const picked = shuffle(ICON_POOL).slice(0, count);
    const nextDeck: Card[] = [];
    let id = 0;
    for (const entry of picked) {
      nextDeck.push({ id: id++, iconKey: entry.key, Icon: entry.Icon });
      nextDeck.push({ id: id++, iconKey: entry.key, Icon: entry.Icon });
    }
    return shuffle(nextDeck);
  }

  function gridColumns(cardTotal: number): number {
    if (cardTotal <= 8) return 4;
    if (cardTotal <= 12) return 4;
    if (cardTotal <= 16) return 4;
    if (cardTotal <= 18) return 6;
    return 5;
  }

  const pairCount = Math.min(12, Math.max(3, config.pairs));
  const duration = Math.max(8000, config.duration);
  const total = pairCount * 2;
  const cols = gridColumns(total);
  const rows = Math.ceil(total / cols);
  const deck = buildDeck(pairCount);

  let flipped = $state<number[]>([]);
  let matched = $state<Set<string>>(new Set());
  let wrong = $state<number[]>([]);
  let locked = $state(false);
  let matchedCount = $state(0);
  let progress = $state(100);
  let finished = $state(false);
  let result = $state<boolean | null>(null);

  let finishedRef = false;
  let flippedRef: number[] = [];
  let matchedRef = new Set<string>();
  let lockedRef = false;
  let startRef = performance.now();
  let matchCountRef = 0;

  const secondsLeft = $derived(((progress / 100) * duration) / 1000);

  async function endGame(success: boolean) {
    if (finishedRef) return;
    finishedRef = true;
    finished = true;
    await finishMinigame(success, (ok) => (result = ok));
  }

  function onCardClick(index: number) {
    if (finishedRef || lockedRef) return;
    if (flippedRef.includes(index)) return;

    const card = deck[index];
    if (!card || matchedRef.has(card.iconKey)) return;

    const nextFlipped = [...flippedRef, index];
    flippedRef = nextFlipped;
    flipped = nextFlipped;

    if (nextFlipped.length < 2) return;

    lockedRef = true;
    locked = true;

    const [a, b] = nextFlipped;
    const cardA = deck[a];
    const cardB = deck[b];

    if (cardA.iconKey === cardB.iconKey) {
      const nextMatched = new Set(matchedRef);
      nextMatched.add(cardA.iconKey);
      matchedRef = nextMatched;
      matched = nextMatched;

      matchCountRef += 1;
      matchedCount = matchCountRef;

      flippedRef = [];
      flipped = [];
      lockedRef = false;
      locked = false;

      if (matchCountRef >= pairCount) {
        window.setTimeout(() => void endGame(true), 180);
      }
      return;
    }

    wrong = [a, b];
    window.setTimeout(() => {
      wrong = [];
      flippedRef = [];
      flipped = [];
      lockedRef = false;
      locked = false;
    }, 650);
  }

  $effect(() => {
    startRef = performance.now();
    progress = 100;

    let raf = 0;
    const tick = (now: number) => {
      if (finishedRef) return;
      const elapsed = now - startRef;
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
</script>

<div class="mg">
  <div class="mg__card pairs__card">
    <div class="mg__header">
      <div class="mg__heading">
        <Puzzle class="mg__icon" style={iconSize(1.8)} strokeWidth={1.75} />
        <span class="mg__title">Pairs</span>
        <span class="mg__subtitle">{matchedCount}/{pairCount}</span>
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
        class="pairs__grid"
        style="grid-template-columns: repeat({cols}, minmax(0, 1fr)); grid-template-rows: repeat({rows}, minmax(0, 1fr)); aspect-ratio: {cols} / {rows}"
      >
        {#each deck as card, index}
          {@const isFlipped =
            flipped.includes(index) || matched.has(card.iconKey) || wrong.includes(index)}
          {@const isMatched = matched.has(card.iconKey)}
          {@const isWrong = wrong.includes(index)}
          {@const Icon = card.Icon}
          <button
            type="button"
            class={[
              "pairs__card-btn",
              isFlipped ? "pairs__card-btn--flipped" : "",
              isMatched ? "pairs__card-btn--matched" : "",
              isWrong ? "pairs__card-btn--wrong" : "",
            ]}
            disabled={finished || locked || isMatched}
            onclick={() => onCardClick(index)}
            aria-label={isFlipped ? card.iconKey : "hidden card"}
          >
            <span class="pairs__face pairs__face--back">?</span>
            <span class="pairs__face pairs__face--front">
              <Icon style={iconSize(2.6)} strokeWidth={1.75} />
            </span>
          </button>
        {/each}
      </div>
    </div>

    <div class="mg__footer">Find matching pairs - Esc</div>
    {#if result !== null}
      <MinigameResult success={result} />
    {/if}
  </div>
</div>
