import { isEnvBrowser } from "../utils/misc";
import type { MinigameConfig, MinigameId } from "../types/minigame";

export const game = $state({
  active: false,
  id: null as MinigameId | null,
  config: null as MinigameConfig | null,
  showDevTools: isEnvBrowser(),
});

export function startGame(id: MinigameId, config: MinigameConfig) {
  game.active = true;
  game.id = id;
  game.config = config;
  game.showDevTools = false;
}

export function stopGame() {
  game.active = false;
  game.id = null;
  game.config = null;
  game.showDevTools = isEnvBrowser();
}

export function openDevTools() {
  game.showDevTools = true;
}

export function closeDevTools() {
  game.showDevTools = false;
}
