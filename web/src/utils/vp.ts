export function vp(px: number): string {
  return `calc((100vw * ${px} / 1920 + 100vh * ${px} / 1080) / 2 / var(--ui-scale, 1))`;
}

export function iconSize(vh: number): string {
  return `width: calc(${vh}vh / var(--ui-scale, 1)); height: calc(${vh}vh / var(--ui-scale, 1))`;
}

export function square(px: number): string {
  return `width: ${vp(px)}; height: ${vp(px)};`;
}
