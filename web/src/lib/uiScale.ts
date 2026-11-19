const BASE_HEIGHT = 1080;
const MAX_SCALE = 2;

export let uiScale = 1;

function applyUiScale() {
  uiScale = Math.min(MAX_SCALE, Math.max(1, window.innerHeight / BASE_HEIGHT));
  document.documentElement.style.setProperty("--ui-scale", String(uiScale));
}

applyUiScale();
window.addEventListener("resize", applyUiScale);
