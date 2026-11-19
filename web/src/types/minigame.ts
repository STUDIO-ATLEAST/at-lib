export type SafeCrackDirection = "clockwise" | "anticlockwise";

export type SafeCrackConfig = {
  combination: number[];
  startDirection: SafeCrackDirection;
  dialStart: number;
  /** wrong Try presses allowed before the safe jams */
  tries?: number;
  /** ms for the whole safe */
  duration?: number;
  /** ms after a wrong Try before the next one counts */
  wrongLockoutMs?: number;
};

export type AlphabetConfig = {
  sequence: string[];
  duration: number;
};

export type KeypadConfig = {
  code: number[];
  length: number;
  tries: number;
  duration: number;
};

export type DecryptConfig = {
  rounds: number;
  tokenLength: number;
  duration: number;
};

export type OverflowConfig = {
  size: number;
  duration: number;
};

export type RememberConfig = {
  size: number;
  targets: number;
  lives: number;
  preview: number;
  duration: number;
};

export type PairsConfig = {
  pairs: number;
  duration: number;
};

export type UntangleConfig = {
  dots: number;
  duration: number;
};

export type MergeConfig = {
  size: number;
  target: number;
  duration: number;
};

export type CircleLockConfig = {
  stages: number;
  zoneSize: number;
  speed: number;
  lives: number;
  duration: number;
};

export type LockpickV2Config = {
  segments: number;
  greenCount: number;
  emptyCount: number;
  speed: number;
  lives: number;
  duration: number;
};

export type LockpickConfig = {
  nodes: number;
  spinTolerance: number;
  nodeLifetime: number;
  duration: number;
};

export type WiresConfig = {
  wires: number;
  duration: number;
};

export type ColorMatchConfig = {
  target: [number, number, number];
  preview: number;
  tolerance: number;
  duration: number;
};

export type SignalTuneConfig = {
  frequency: number;
  amplitude: number;
  phase: number;
  freqTolerance: number;
  ampTolerance: number;
  phaseTolerance: number;
  duration: number;
};

export type BinaryConfig = {
  sequence: number[];
  rows: number[][];
  correctRow: number;
  preview: number;
  reverse: boolean;
  glitches: boolean;
  duration: number;
};

export type CircuitConfig = {
  size: number;
  sources: number;
  outputs: number;
  dangers: number;
  maxRotations: number;
  duration: number;
  seed: number;
};

export type PortScanConfig = {
  ports: number;
  required: number;
  tick: number;
  trapPenalty: number;
  similar: boolean;
  duration: number;
};

export type PinTensionPin = {
  target: number;
  zone: number;
  tension: number;
  tensionTol: number;
};

export type PinTensionConfig = {
  pins: PinTensionPin[];
  durability: number;
  fallSpeed: number;
  duration: number;
};

export type SkillBarConfig = {
  segmentSpeed: number;
  targetZoneSize: number;
  hitsRequired: number;
  hitPause?: number;
};

export type LaserGridConfig = {
  laserCount: number;
  laserSpeed: number;
  sections: number;
  detectionHits: number;
  fog: boolean;
  cameraSway: boolean;
  duration: number;
  seed: number;
};

export type PathingConfig = {
  stages: number;
  dots: number;
  duration: number;
  seed: number;
};

export type OddOneOutConfig = {
  size: number;
  oddCount: number;
  visibility: number;
  animated: boolean;
  stages: number;
  lives: number;
  duration: number;
  seed: number;
};

export type SequenceConfig = {
  stages: number;
  gridSize: number;
  sequenceLength: number;
  duration: number;
  penalty: number;
  scrambleCount: number;
  instantFail: boolean;
  seed: number;
};

export type ArrowsConfig = {
  sequence: string[];
  length: number;
  stages: number;
  duration: number;
  seed: number;
};

export type SearchSlotItem = {
  id: string;
  label: string;
  count?: number;
  image?: string;
  metadata?: Record<string, unknown>;
};

export type SearchConfig = {
  size: number;
  itemCount: number;
  required: number;
  searchTime: number;
  duration: number;
  slots: (SearchSlotItem | false | null)[];
  seed?: number;
};

export type SmashConfig = {
  key: string;
  gain: number;
  decay: number;
  start: number;
  duration: number;
};

export type NotchConfig = {
  notches: number;
  angles: number[];
  speed: number;
  tolerance: number;
  key: string;
  duration: number;
  seed?: number;
};

export type PedLootSlot = {
  id?: string;
  label?: string;
  count?: number;
  image?: string;
  value?: number;
  /** Spawn weight 1-100 (higher = more common + longer green window) */
  chance?: number;
  /** Hit window 0-1 (green line length). Derived from chance if omitted. */
  window?: number;
  empty?: boolean;
  metadata?: Record<string, unknown>;
  /** Optional index into an external loot list (e.g. sd-pettycrime pickpocket) */
  sourceIndex?: number;
};

export type PedLootConfig = {
  slotCount: number;
  empties: number;
  required: number;
  speed: number;
  key: string;
  duration: number;
  board: (PedLootSlot | false | null)[];
  seed?: number;
};

export type DrillConfig = {
  hitsRequired: number;
  fallMs: number;
  duration: number;
  seed?: number;
};

export type DataCrackConfig = {
  stages: number;
  segments: number;
  segmentSpeed: number;
  gapSize: number;
  lineWidth: number;
  /** 0 disables the timer */
  duration: number;
  seed?: number;
};

export type StackerConfig = {
  stages: number;
  rowsToGoal: number;
  startWidthPercent: number;
  segmentSpeed: number;
  speedUpEachRow: boolean;
  /** 0 disables the timer */
  duration: number;
};

export type PulseBarConfig = {
  segmentSpeed: number;
  targetZoneSize: number;
  numberOfSegments: number;
  seed?: number;
};

export type PinLockConfig = {
  numberOfPins: number;
  pushStrength: number;
  gravity: number;
  zoneTolerance: number;
  instantFail: boolean;
  maxAttempts: number;
  /** 0 disables the timer */
  duration: number;
  seed?: number;
};

export type MinigameId =
  | "datacrack"
  | "stacker"
  | "pulsebar"
  | "pinlock"
  | "safecrack"
  | "alphabet"
  | "keypad"
  | "decrypt"
  | "overflow"
  | "remember"
  | "pairs"
  | "untangle"
  | "merge"
  | "circlelock"
  | "lockpickv2"
  | "lockpick"
  | "wires"
  | "colormatch"
  | "signaltune"
  | "binary"
  | "circuit"
  | "portscan"
  | "pintension"
  | "skillbar"
  | "lasergrid"
  | "pathing"
  | "oddoneout"
  | "sequence"
  | "arrows"
  | "search"
  | "smash"
  | "notch"
  | "pedloot"
  | "drill";

export type MinigameConfig =
  | DataCrackConfig
  | StackerConfig
  | PulseBarConfig
  | PinLockConfig
  | SafeCrackConfig
  | AlphabetConfig
  | KeypadConfig
  | DecryptConfig
  | OverflowConfig
  | RememberConfig
  | PairsConfig
  | UntangleConfig
  | MergeConfig
  | CircleLockConfig
  | LockpickV2Config
  | LockpickConfig
  | WiresConfig
  | ColorMatchConfig
  | SignalTuneConfig
  | BinaryConfig
  | CircuitConfig
  | PortScanConfig
  | PinTensionConfig
  | SkillBarConfig
  | LaserGridConfig
  | PathingConfig
  | OddOneOutConfig
  | SequenceConfig
  | ArrowsConfig
  | SearchConfig
  | SmashConfig
  | NotchConfig
  | PedLootConfig
  | DrillConfig;

export type StartMinigamePayload =
  | { id: "datacrack"; config: DataCrackConfig }
  | { id: "stacker"; config: StackerConfig }
  | { id: "pulsebar"; config: PulseBarConfig }
  | { id: "pinlock"; config: PinLockConfig }
  | { id: "safecrack"; config: SafeCrackConfig }
  | { id: "alphabet"; config: AlphabetConfig }
  | { id: "keypad"; config: KeypadConfig }
  | { id: "decrypt"; config: DecryptConfig }
  | { id: "overflow"; config: OverflowConfig }
  | { id: "remember"; config: RememberConfig }
  | { id: "pairs"; config: PairsConfig }
  | { id: "untangle"; config: UntangleConfig }
  | { id: "merge"; config: MergeConfig }
  | { id: "circlelock"; config: CircleLockConfig }
  | { id: "lockpickv2"; config: LockpickV2Config }
  | { id: "lockpick"; config: LockpickConfig }
  | { id: "wires"; config: WiresConfig }
  | { id: "colormatch"; config: ColorMatchConfig }
  | { id: "signaltune"; config: SignalTuneConfig }
  | { id: "binary"; config: BinaryConfig }
  | { id: "circuit"; config: CircuitConfig }
  | { id: "portscan"; config: PortScanConfig }
  | { id: "pintension"; config: PinTensionConfig }
  | { id: "skillbar"; config: SkillBarConfig }
  | { id: "lasergrid"; config: LaserGridConfig }
  | { id: "pathing"; config: PathingConfig }
  | { id: "oddoneout"; config: OddOneOutConfig }
  | { id: "sequence"; config: SequenceConfig }
  | { id: "arrows"; config: ArrowsConfig }
  | { id: "search"; config: SearchConfig }
  | { id: "smash"; config: SmashConfig }
  | { id: "notch"; config: NotchConfig }
  | { id: "pedloot"; config: PedLootConfig }
  | { id: "drill"; config: DrillConfig };

export type DevLaunchPayload = {
  id: MinigameId;
  opts?: Record<string, unknown>;
};
