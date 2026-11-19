// Element theme values for components that set colours inline. Mirrors the CSS tokens in index.css.
export const dark = [
  "#c1c2c5", // text
  "#a6a7ab",
  "#909296", // muted
  "#5c5f66", // dim
  "#43454b", // border-hover
  "#2c2e33", // bg-hover
  "#25262b", // bg-field
  "#1a1b1e", // bg-panel
  "#141517", // bg-frame
  "#111214", // bg-sidebar
] as const;

// Only the .4 accent is used; the array keeps the old index-based imports working.
export const blue = [
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
  "#4dabf7",
] as const;

export const green6 = "#69db7c";
export const red5 = "#ff8787";
export const red6 = "#ff8787";

export const radiusSm = "4px";
export const shadowMd = "0 1.2vh 4vh rgba(0, 0, 0, 0.45)";

export const panelBg = "#1a1b1e";
export const headerBg = "#141517";
export const border = "1px solid #26272b";
export const borderColor = "#26272b";
export const trackBg = "#111214";

export const fontXs = "12px";
export const fontSm = "14px";
export const fontMd = "16px";
export const fontXl = "20px";
