import type {
  AlphabetConfig,
  DecryptConfig,
  KeypadConfig,
  OverflowConfig,
  CircleLockConfig,
  LockpickV2Config,
  MergeConfig,
  PairsConfig,
  RememberConfig,
  SafeCrackConfig,
  LockpickConfig,
  UntangleConfig,
  WiresConfig,
  ColorMatchConfig,
  SignalTuneConfig,
  BinaryConfig,
  CircuitConfig,
  PortScanConfig,
  PinTensionConfig,
  SkillBarConfig,
  LaserGridConfig,
  PathingConfig,
  OddOneOutConfig,
  SequenceConfig,
  ArrowsConfig,
  SearchConfig,
  SmashConfig,
  NotchConfig,
  PedLootConfig,
  DrillConfig,
  DataCrackConfig,
  StackerConfig,
  PulseBarConfig,
  PinLockConfig,
} from "../types/minigame";

export const browserConfigs: {
  safecrack: SafeCrackConfig;
  alphabet: AlphabetConfig;
  keypad: KeypadConfig;
  decrypt: DecryptConfig;
  overflow: OverflowConfig;
  remember: RememberConfig;
  pairs: PairsConfig;
  untangle: UntangleConfig;
  merge: MergeConfig;
  circlelock: CircleLockConfig;
  lockpickv2: LockpickV2Config;
  lockpick: LockpickConfig;
  wires: WiresConfig;
  colormatch: ColorMatchConfig;
  signaltune: SignalTuneConfig;
  binary: BinaryConfig;
  circuit: CircuitConfig;
  portscan: PortScanConfig;
  pintension: PinTensionConfig;
  skillbar: SkillBarConfig;
  lasergrid: LaserGridConfig;
  pathing: PathingConfig;
  oddoneout: OddOneOutConfig;
  sequence: SequenceConfig;
  arrows: ArrowsConfig;
  search: SearchConfig;
  smash: SmashConfig;
  notch: NotchConfig;
  pedloot: PedLootConfig;
  drill: DrillConfig;
  datacrack: DataCrackConfig;
  stacker: StackerConfig;
  pulsebar: PulseBarConfig;
  pinlock: PinLockConfig;
} = {
  safecrack: {
    combination: [25, 70, 40],
    startDirection: "clockwise",
    dialStart: 0,
  },
  alphabet: {
    sequence: ["W", "Q", "A", "S", "S", "S", "A", "W", "W", "S", "Q", "S", "A", "D", "A"],
    duration: 12000,
  },
  keypad: {
    code: [1, 2, 3, 4],
    length: 4,
    tries: 6,
    duration: 35000,
  },
  decrypt: {
    rounds: 5,
    tokenLength: 6,
    duration: 28000,
  },
  overflow: {
    size: 5,
    duration: 35000,
  },
  remember: {
    size: 5,
    targets: 6,
    lives: 1,
    preview: 3000,
    duration: 14000,
  },
  pairs: {
    pairs: 8,
    duration: 36000,
  },
  untangle: {
    dots: 7,
    duration: 40000,
  },
  merge: {
    size: 4,
    target: 128,
    duration: 40000,
  },
  circlelock: {
    stages: 3,
    zoneSize: 34,
    speed: 180,
    lives: 2,
    duration: 28000,
  },
  lockpickv2: {
    segments: 9,
    greenCount: 4,
    emptyCount: 3,
    speed: 130,
    lives: 2,
    duration: 24000,
  },
  lockpick: {
    nodes: 4,
    spinTolerance: 12,
    nodeLifetime: 1600,
    duration: 32000,
  },
  wires: {
    wires: 4,
    duration: 32000,
  },
  colormatch: {
    target: [64, 160, 220],
    preview: 2200,
    tolerance: 32,
    duration: 28000,
  },
  signaltune: {
    frequency: 3.2,
    amplitude: 62,
    phase: 140,
    freqTolerance: 0.28,
    ampTolerance: 6,
    phaseTolerance: 12,
    duration: 32000,
  },
  binary: {
    sequence: [1, 0, 1, 1, 0, 1, 0, 0, 1],
    rows: [[1, 0, 1, 1, 0, 1, 0, 0, 1]],
    correctRow: 0,
    preview: 2100,
    reverse: false,
    glitches: true,
    duration: 28000,
  },
  circuit: {
    size: 4,
    sources: 1,
    outputs: 2,
    dangers: 1,
    maxRotations: 0,
    duration: 36000,
    seed: 4242,
  },
  portscan: {
    ports: 12,
    required: 5,
    tick: 750,
    trapPenalty: 3500,
    similar: true,
    duration: 28000,
  },
  pintension: {
    pins: [
      { target: 42, zone: 10, tension: 48, tensionTol: 12 },
      { target: 61, zone: 10, tension: 55, tensionTol: 12 },
      { target: 35, zone: 10, tension: 40, tensionTol: 12 },
      { target: 70, zone: 10, tension: 62, tensionTol: 12 },
    ],
    durability: 3,
    fallSpeed: 42,
    duration: 36000,
  },
  skillbar: {
    segmentSpeed: 90,
    targetZoneSize: 14,
    hitsRequired: 3,
  },
  lasergrid: {
    laserCount: 4,
    laserSpeed: 20,
    sections: 2,
    detectionHits: 4,
    fog: false,
    cameraSway: false,
    duration: 45000,
    seed: 777,
  },
  pathing: {
    stages: 2,
    dots: 7,
    duration: 18000,
    seed: 4242,
  },
  oddoneout: {
    size: 4,
    oddCount: 1,
    visibility: 3,
    animated: false,
    stages: 2,
    lives: 1,
    duration: 13000,
    seed: 5151,
  },
  sequence: {
    stages: 2,
    gridSize: 8,
    sequenceLength: 4,
    duration: 20000,
    penalty: 3000,
    scrambleCount: 1,
    instantFail: false,
    seed: 6060,
  },
  arrows: {
    sequence: ["down", "up", "left", "up", "up", "down", "right", "down"],
    length: 8,
    stages: 1,
    duration: 8000,
    seed: 7171,
  },
  search: {
    size: 3,
    itemCount: 4,
    required: 3,
    searchTime: 1400,
    duration: 26000,
    slots: [
      {
        id: "lockpick",
        label: "Lockpick",
        count: 1,
        image: "nui://ox_inventory/web/images/lockpick.png",
      },
      false,
      {
        id: "phone",
        label: "Phone",
        count: 1,
        image: "nui://ox_inventory/web/images/phone.png",
      },
      {
        id: "money",
        label: "Money",
        count: 1,
        image: "nui://ox_inventory/web/images/money.png",
      },
      false,
      false,
      {
        id: "radio",
        label: "Radio",
        count: 1,
        image: "nui://ox_inventory/web/images/radio.png",
      },
      false,
      false,
    ],
  },
  smash: {
    key: "E",
    gain: 8,
    decay: 15,
    start: 6,
    duration: 14000,
  },
  notch: {
    notches: 4,
    angles: [20, 110, 200, 295],
    speed: 130,
    tolerance: 12,
    key: "E",
    duration: 20000,
    seed: 4242,
  },
  pedloot: {
    slotCount: 5,
    empties: 2,
    required: 3,
    speed: 90,
    key: "SPACE",
    duration: 15000,
    board: [
      { empty: true, window: 0, chance: 0 },
      {
        id: "lockpick",
        label: "Lockpick",
        count: 1,
        chance: 40,
        window: 0.55,
        image: "nui://ox_inventory/web/images/lockpick.png",
      },
      {
        id: "money",
        label: "Money",
        count: 50,
        value: 50,
        chance: 25,
        window: 0.4,
        image: "nui://ox_inventory/web/images/money.png",
      },
      {
        id: "phone",
        label: "Phone",
        count: 1,
        chance: 15,
        window: 0.3,
        image: "nui://ox_inventory/web/images/phone.png",
      },
      { empty: true, window: 0, chance: 0 },
    ],
  },
  drill: {
    hitsRequired: 9,
    fallMs: 2400,
    duration: 32000,
    seed: 4242,
  },
  datacrack: {
    stages: 2,
    segments: 8,
    segmentSpeed: 60,
    gapSize: 22,
    lineWidth: 34,
    duration: 25000,
    seed: 4242,
  },
  stacker: {
    stages: 1,
    rowsToGoal: 7,
    startWidthPercent: 40,
    segmentSpeed: 70,
    speedUpEachRow: true,
    duration: 25000,
  },
  pulsebar: {
    segmentSpeed: 45,
    targetZoneSize: 12,
    numberOfSegments: 4,
    seed: 4242,
  },
  pinlock: {
    numberOfPins: 6,
    pushStrength: 55,
    gravity: 140,
    zoneTolerance: 7,
    instantFail: false,
    maxAttempts: 3,
    duration: 40000,
    seed: 4242,
  },
};

/** Fresh vivid RGB for browser / preview launches. */
export function randomColorMatchTarget(): [number, number, number] {
  const h = Math.random();
  const s = 0.55 + Math.random() * 0.4;
  const l = 0.38 + Math.random() * 0.28;
  const hue2rgb = (p: number, q: number, t: number) => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  };
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  return [
    Math.round(hue2rgb(p, q, h + 1 / 3) * 255),
    Math.round(hue2rgb(p, q, h) * 255),
    Math.round(hue2rgb(p, q, h - 1 / 3) * 255),
  ];
}

