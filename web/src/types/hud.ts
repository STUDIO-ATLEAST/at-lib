export interface DialogueOption {
  id: string;
  label: string;
}

export interface DialogueInput {
  type?: "number" | "text";
  placeholder?: string;
  submitLabel?: string;
  min?: number;
  max?: number;
}

export interface DialogueData {
  name: string;
  text: string;
  options: DialogueOption[];
  input?: DialogueInput;
}

export interface MissionObjective {
  id: string;
  label: string;
  completed: boolean;
  step?: number;
  subtitle?: string;
  meta?: string;
}

export interface MissionStep {
  id?: string;
  label: string;
  done?: boolean;
  active?: boolean;
  progress?: number;
  count?: number;
}

export interface MissionOptional {
  id?: string;
  label: string;
  done?: boolean;
}

export type MissionTone = "normal" | "accent" | "warn" | "danger" | "ok";

export interface MissionGauge {
  id?: string;
  label?: string;
  icon?: string;
  kind: "bar" | "segments" | "text";
  value?: number;
  max?: number;
  tone?: MissionTone;
  text?: string;
  ttl?: number;
  expiresAt?: number;
}

export interface MissionBadge {
  icon?: string;
  text: string;
}

export interface MissionStat {
  id?: string;
  label: string;
  value: number;
  icon?: string;
  format?: "money" | "number";
}

export interface MissionData {
  title: string;
  objectives: MissionObjective[];
  task?: string;
  detail?: string;
  icon?: string;
  meta?: string;
  badge?: MissionBadge;
  steps?: MissionStep[];
  tasks?: MissionStep[];
  optional?: MissionOptional[];
  gauges?: MissionGauge[];
  stat?: MissionStat;
  hint?: string;
}

export const MISSION_DETAIL_KEYS = [
  "task",
  "detail",
  "meta",
  "icon",
  "badge",
  "steps",
  "tasks",
  "optional",
  "gauges",
  "stat",
  "hint",
] as const;

export type MissionDetailsUpdate = Partial<Pick<MissionData, (typeof MISSION_DETAIL_KEYS)[number]>>;

export interface TimerData {
  seconds: number;
  header?: string;
  text?: string;
  position?: "top-center" | "bottom-center";
  variant?: "default" | "heist";
}

export interface ProgressData {
  progress: number;
  header?: string;
  label?: string;
}

export type TextUIPosition = "right-center" | "left-center" | "top-center" | "bottom-center";

export interface TextUIData {
  key?: string;
  label: string;
  position?: TextUIPosition;
}

export interface GangZoneSide {
  name: string;
  logo?: string;
  color?: string;
}

export interface GangZoneData {
  percent: number;
  seconds: number;
  left: GangZoneSide;
  right: GangZoneSide;
  owner?: "left" | "right";
  leftCount?: number;
  rightCount?: number;
  status?: GangZoneStatus;
}

export type GangZoneStatus = "idle" | "contested" | "securing" | "held" | "takeover";

export type DevPreviewKey =
  | "dialogue"
  | "mission"
  | "missionCard"
  | "timer"
  | "timerV2"
  | "textui"
  | "textuiPlain"
  | "progress"
  | "gangZone";
