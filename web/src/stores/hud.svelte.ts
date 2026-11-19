import { isEnvBrowser } from "../utils/misc";
import { MISSION_DETAIL_KEYS } from "../types/hud";
import type {
  DevPreviewKey,
  DialogueData,
  GangZoneData,
  MissionData,
  MissionDetailsUpdate,
  ProgressData,
  TextUIData,
  TimerData,
} from "../types/hud";

const browser = isEnvBrowser();

export const dialogue = $state({
  visible: browser,
  data: browser
    ? ({
        name: "Officer Davis",
        text: "Hey there! I noticed you've been hanging around this area. Is there something I can help you with? We've had some reports of suspicious activity lately.",
        options: [
          { id: "help", label: "Yes, I need some help" },
          { id: "info", label: "What kind of activity?" },
          { id: "nevermind", label: "No thanks, just passing through" },
        ],
      } as DialogueData)
    : null,
});

export function setDialogue(data: DialogueData | null) {
  dialogue.data = data;
  dialogue.visible = !!data;
}

export function closeDialogue() {
  dialogue.data = null;
  dialogue.visible = false;
}

export const missionStatus = $state({
  visible: browser,
  data: browser
    ? ({
        title: "Drug Bust Operation",
        objectives: [
          { id: "1", label: "Go to the marked location", completed: true },
          { id: "2", label: "Talk to the informant", completed: true },
          { id: "3", label: "Find the stash house", completed: false },
          { id: "4", label: "Secure the evidence", completed: false },
          { id: "5", label: "Return to the station", completed: false },
        ],
      } as MissionData)
    : null,
});

export const missionCard = $state({
  visible: browser,
  data: browser
    ? ({
        title: "Humane Labs Heist",
        icon: "flask-conical",
        task: "Empty the vault",
        detail:
          "Thermite one of the barred vault gates, then bag the trolleys, cut the paintings and drill the deposit boxes.",
        objectives: [],
        steps: [
          { label: "Swipe into the loading bay", done: true },
          { label: "Loop the security cameras", done: true },
          { label: "Take the service lift to sub-level B3", done: true },
          { label: "Sync-swipe the access doors", done: true },
          { label: "Blow the vault door", done: true },
          { label: "Empty the vault", active: true, progress: 2, count: 7 },
          { label: "Get out of the area" },
        ],
        optional: [
          { label: "Raid cold storage", done: true },
          { label: "Hack the pool door to swim out" },
        ],
      } as MissionData)
    : null,
});

type MissionSlice = { visible: boolean; data: MissionData | null };

function asList<T>(value: T[] | undefined): T[] | undefined {
  return Array.isArray(value) ? value : undefined;
}

function normalizeDetails(data: MissionDetailsUpdate): MissionDetailsUpdate {
  const stamp = Date.now();
  const out: MissionDetailsUpdate = { ...data };
  if ("steps" in data) out.steps = asList(data.steps);
  if ("tasks" in data) out.tasks = asList(data.tasks);
  if ("optional" in data) out.optional = asList(data.optional);
  if ("gauges" in data) {
    out.gauges = asList(data.gauges)?.map((gauge, index) => ({
      ...gauge,
      id: gauge.id ?? `g${index}`,
      expiresAt: gauge.ttl ? stamp + gauge.ttl : undefined,
    }));
  }
  return out;
}

export function setMission(slice: MissionSlice, data: MissionData | null) {
  slice.data = data
    ? { ...data, ...normalizeDetails(data), objectives: asList(data.objectives) ?? [] }
    : null;
  slice.visible = !!data;
}

export function updateObjective(slice: MissionSlice, id: string, completed: boolean) {
  const objective = slice.data?.objectives?.find((entry) => entry.id === id);
  if (objective) objective.completed = completed;
  const step = slice.data?.steps?.find((entry) => entry.id === id);
  if (step) step.done = completed;
  const task = slice.data?.tasks?.find((entry) => entry.id === id);
  if (task) task.done = completed;
  const optional = slice.data?.optional?.find((entry) => entry.id === id);
  if (optional) optional.done = completed;
}

export function updateMissionDetails(slice: MissionSlice, data: MissionDetailsUpdate) {
  if (!slice.data) return;
  const normalized = normalizeDetails(data);
  for (const key of MISSION_DETAIL_KEYS) {
    if (key in normalized) Object.assign(slice.data, { [key]: normalized[key] });
  }
}

export function closeMission(slice: MissionSlice) {
  slice.data = null;
  slice.visible = false;
}

export const missionCardLayout = $state({ height: 0 });

export const timer = $state({
  visible: browser,
  data: browser
    ? ({
        seconds: 90,
        header: "Timed objective",
        text: "Reach the marker before time runs out.",
      } as TimerData)
    : null,
});

export function showTimer(data: TimerData) {
  timer.data = data;
  timer.visible = true;
}

export function updateTimer(data: Partial<TimerData>) {
  timer.visible = true;
  timer.data = timer.data ? { ...timer.data, ...data } : (data as TimerData);
}

export function closeTimer() {
  timer.data = null;
  timer.visible = false;
}

const clamp = (n: number) => Math.max(0, Math.min(100, n));

export const progress = $state({
  visible: false,
  data: null as ProgressData | null,
});

export function showProgress(data: ProgressData) {
  progress.data = { ...data, progress: clamp(data.progress) };
  progress.visible = true;
}

export function updateProgress(data: Partial<ProgressData>) {
  progress.visible = true;
  const next = { ...(progress.data ?? { progress: 0 }), ...data } as ProgressData;
  next.progress = clamp(next.progress);
  progress.data = next;
}

export function closeProgress() {
  progress.data = null;
  progress.visible = false;
}

export const textUI = $state({
  visible: browser,
  data: browser ? ({ key: "E", label: "Grab bag" } as TextUIData) : null,
});

export function setTextUI(data: TextUIData | null) {
  textUI.data = data;
  textUI.visible = !!data;
}

export function closeTextUI() {
  textUI.data = null;
  textUI.visible = false;
}

export const gangZone = $state({
  visible: browser,
  data: browser
    ? ({
        percent: 64,
        seconds: 232,
        left: { name: "Ballas", color: "#9775fa" },
        right: { name: "Families", color: "#69db7c" },
        owner: "left",
        leftCount: 2,
        rightCount: 4,
      } as GangZoneData)
    : null,
});

export function showGangZone(data: GangZoneData) {
  gangZone.data = data;
  gangZone.visible = true;
}

export function updateGangZone(data: Partial<GangZoneData>) {
  gangZone.visible = true;
  gangZone.data = gangZone.data ? { ...gangZone.data, ...data } : (data as GangZoneData);
}

export function closeGangZone() {
  gangZone.data = null;
  gangZone.visible = false;
}

export const devPreview = $state({
  toggles: {
    dialogue: false,
    mission: false,
    missionCard: false,
    timer: false,
    timerV2: false,
    textui: false,
    textuiPlain: false,
    progress: false,
    gangZone: false,
  } as Record<DevPreviewKey, boolean>,
  progressValue: 38,
});
