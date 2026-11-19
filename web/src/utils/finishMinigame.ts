import { fetchNui } from "./fetchNui";
import { isEnvBrowser } from "./misc";
import { stopGame } from "../stores/minigame.svelte";

const RESULT_HOLD_MS = 1400;

export type MinigameResultPayload = {
  success: boolean;
  items?: {
    id: string;
    count: number;
    metadata?: Record<string, unknown>;
    slot?: number;
    sourceIndex?: number;
  }[];
};

/** Show result overlay briefly, then report to Lua / close browser preview. */
export async function finishMinigame(
  success: boolean,
  showResult: (success: boolean) => void,
  extra?: Omit<MinigameResultPayload, "success">
) {
  showResult(success);
  await new Promise((r) => window.setTimeout(r, RESULT_HOLD_MS));
  await fetchNui(
    "minigameResult",
    { success, ...(extra || {}) },
    { data: true, delay: 0 }
  );
  if (isEnvBrowser()) stopGame();
}
