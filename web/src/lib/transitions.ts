import { cubicOut } from "svelte/easing";

type SlideParams = {
  axis?: "x" | "y";
  distance?: string;
  duration?: number;
};

export function mantineSlide(
  _node: Element,
  { axis = "y", distance = "100%", duration = 300 }: SlideParams = {},
) {
  const translate = axis === "x" ? "translateX" : "translateY";
  return {
    duration,
    easing: cubicOut,
    css: (t: number, u: number) =>
      `opacity: ${t}; transform: ${translate}(calc(${distance} * ${u}));`,
  };
}
