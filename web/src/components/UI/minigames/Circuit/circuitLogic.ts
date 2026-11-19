export type TileKind =
  | "straight"
  | "corner"
  | "tee"
  | "cross"
  | "source"
  | "output"
  | "danger"
  | "block";

export type CircuitTile = {
  kind: TileKind;
  rot: number; // 0-3
  fixed?: boolean;
  /** Optional absolute opening mask (for source/output). */
  openMask?: number;
};

export type CircuitPuzzle = {
  size: number;
  tiles: CircuitTile[][];
};

/** N=1 E=2 S=4 W=8 */
export const N = 1;
export const E = 2;
export const S = 4;
export const W = 8;

const DR = [-1, 0, 1, 0];
const DC = [0, 1, 0, -1];
const DIR_BIT = [N, E, S, W];
const OPP = [S, W, N, E];

const BASE_MASK: Record<TileKind, number> = {
  straight: N | S,
  corner: N | E,
  tee: N | E | S,
  cross: N | E | S | W,
  source: E,
  output: W,
  danger: N | E | S | W,
  block: 0,
};

function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function rotMask(mask: number, rot: number) {
  let m = mask & 15;
  for (let i = 0; i < (rot & 3); i++) {
    m =
      ((m & N ? E : 0) |
        (m & E ? S : 0) |
        (m & S ? W : 0) |
        (m & W ? N : 0)) &
      15;
  }
  return m;
}

export function openings(tile: CircuitTile): number {
  if (tile.kind === "block") return 0;
  if (tile.openMask != null) return tile.openMask & 15;
  return rotMask(BASE_MASK[tile.kind], tile.rot);
}

function kindForMask(mask: number): TileKind {
  const bits = [N, E, S, W].filter((b) => mask & b).length;
  if (bits >= 4) return "cross";
  if (bits === 3) return "tee";
  if (bits === 2) {
    if (mask === (N | S) || mask === (E | W)) return "straight";
    return "corner";
  }
  // Single opening - use corner rotated; extra arm will be unused visually via openMask later if needed
  return "corner";
}

function rotToMatch(kind: TileKind, want: number): number {
  for (let r = 0; r < 4; r++) {
    if (rotMask(BASE_MASK[kind], r) === (want & 15)) return r;
  }
  // Partial match: any rotation that covers all wanted bits
  for (let r = 0; r < 4; r++) {
    const m = rotMask(BASE_MASK[kind], r);
    if ((m & want) === want) return r;
  }
  return 0;
}

function inBounds(size: number, r: number, c: number) {
  return r >= 0 && c >= 0 && r < size && c < size;
}

function keyOf(r: number, c: number) {
  return `${r},${c}`;
}

function shuffle<T>(arr: T[], rand: () => number): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function poweredSet(tiles: CircuitTile[][]): Set<string> {
  const size = tiles.length;
  const powered = new Set<string>();
  const q: [number, number][] = [];

  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (tiles[r][c].kind === "source") {
        powered.add(keyOf(r, c));
        q.push([r, c]);
      }
    }
  }

  while (q.length) {
    const [r, c] = q.pop()!;
    const open = openings(tiles[r][c]);
    for (let d = 0; d < 4; d++) {
      if (!(open & DIR_BIT[d])) continue;
      const nr = r + DR[d];
      const nc = c + DC[d];
      if (!inBounds(size, nr, nc)) continue;
      const key = keyOf(nr, nc);
      if (powered.has(key)) continue;
      if (tiles[nr][nc].kind === "block") continue;
      if (!(openings(tiles[nr][nc]) & OPP[d])) continue;
      powered.add(key);
      q.push([nr, nc]);
    }
  }

  return powered;
}

export function isSolved(tiles: CircuitTile[][]): boolean {
  const powered = poweredSet(tiles);
  let outputs = 0;
  let on = 0;
  for (let r = 0; r < tiles.length; r++) {
    for (let c = 0; c < tiles[r].length; c++) {
      const t = tiles[r][c];
      const key = keyOf(r, c);
      if (t.kind === "output") {
        outputs += 1;
        if (powered.has(key)) on += 1;
      }
      if (t.kind === "danger" && powered.has(key)) return false;
    }
  }
  return outputs > 0 && on === outputs;
}

function carvePath(masks: number[][], path: [number, number][]) {
  for (let i = 1; i < path.length; i++) {
    const [pr, pc] = path[i - 1];
    const [r, c] = path[i];
    for (let d = 0; d < 4; d++) {
      if (pr + DR[d] === r && pc + DC[d] === c) {
        masks[pr][pc] |= DIR_BIT[d];
        masks[r][c] |= OPP[d];
      }
    }
  }
}

/** Pick a random edge cell, preferring variety across edges. */
function randomEdgeCell(
  size: number,
  rand: () => number,
  taken: Set<string>
): [number, number] {
  for (let attempt = 0; attempt < 60; attempt++) {
    const edge = Math.floor(rand() * 4); // 0N 1E 2S 3W
    let r = 0;
    let c = 0;
    if (edge === 0) {
      r = 0;
      c = Math.floor(rand() * size);
    } else if (edge === 1) {
      r = Math.floor(rand() * size);
      c = size - 1;
    } else if (edge === 2) {
      r = size - 1;
      c = Math.floor(rand() * size);
    } else {
      r = Math.floor(rand() * size);
      c = 0;
    }
    const k = keyOf(r, c);
    if (!taken.has(k)) return [r, c];
  }
  // Fallback scan
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (r === 0 || c === 0 || r === size - 1 || c === size - 1) {
        const k = keyOf(r, c);
        if (!taken.has(k)) return [r, c];
      }
    }
  }
  return [0, 0];
}

/**
 * Winding path: biased random walk that must reach the goal.
 * Longer / twistier than plain BFS so boards don't all look L→R.
 */
function windingPath(
  size: number,
  start: [number, number],
  end: [number, number],
  rand: () => number,
  softBlocked: Set<string>
): [number, number][] {
  const tryWalk = (): [number, number][] | null => {
    const path: [number, number][] = [start];
    const seen = new Set<string>([keyOf(start[0], start[1])]);
    let [r, c] = start;
    const limit = size * size * 3;

    for (let step = 0; step < limit; step++) {
      if (r === end[0] && c === end[1]) return path;

      const options: { r: number; c: number; score: number }[] = [];
      for (let d = 0; d < 4; d++) {
        const nr = r + DR[d];
        const nc = c + DC[d];
        if (!inBounds(size, nr, nc)) continue;
        const k = keyOf(nr, nc);
        if (seen.has(k)) continue;
        // Soft-block: prefer avoiding reserved specials except the goal
        if (softBlocked.has(k) && !(nr === end[0] && nc === end[1])) continue;
        const dist =
          Math.abs(nr - end[0]) + Math.abs(nc - end[1]);
        const noise = rand() * 2.5;
        options.push({ r: nr, c: nc, score: dist + noise });
      }

      if (!options.length) return null;
      options.sort((a, b) => a.score - b.score);
      // Sometimes take 2nd/3rd best for more wiggles
      const pick =
        options[
          Math.min(
            options.length - 1,
            rand() < 0.55 ? 0 : rand() < 0.7 ? 1 : 2
          )
        ];
      r = pick.r;
      c = pick.c;
      seen.add(keyOf(r, c));
      path.push([r, c]);
    }
    return r === end[0] && c === end[1] ? path : null;
  };

  for (let i = 0; i < 12; i++) {
    const path = tryWalk();
    if (path) return path;
  }

  // Guaranteed orthogonal fallback
  const path: [number, number][] = [];
  let [r, c] = start;
  path.push([r, c]);
  // Randomize whether we fix row or col first
  if (rand() < 0.5) {
    while (c !== end[1]) {
      c += c < end[1] ? 1 : -1;
      path.push([r, c]);
    }
    while (r !== end[0]) {
      r += r < end[0] ? 1 : -1;
      path.push([r, c]);
    }
  } else {
    while (r !== end[0]) {
      r += r < end[0] ? 1 : -1;
      path.push([r, c]);
    }
    while (c !== end[1]) {
      c += c < end[1] ? 1 : -1;
      path.push([r, c]);
    }
  }
  return path;
}

/** Short spur off the main path for visual variety (still part of solution mask). */
function addSpur(
  size: number,
  masks: number[][],
  reserved: Set<string>,
  rand: () => number
) {
  const pathCells = [...reserved];
  if (!pathCells.length) return;
  const startKey = pathCells[Math.floor(rand() * pathCells.length)];
  const [sr, sc] = startKey.split(",").map(Number);
  const dirs = shuffle([0, 1, 2, 3], rand);
  for (const d of dirs) {
    const len = 1 + Math.floor(rand() * 2); // 1-2
    const spur: [number, number][] = [[sr, sc]];
    let r = sr;
    let c = sc;
    let ok = true;
    for (let i = 0; i < len; i++) {
      r += DR[d];
      c += DC[d];
      if (!inBounds(size, r, c)) {
        ok = false;
        break;
      }
      const k = keyOf(r, c);
      if (reserved.has(k)) {
        ok = false;
        break;
      }
      spur.push([r, c]);
    }
    if (!ok || spur.length < 2) continue;
    carvePath(masks, spur);
    for (const [pr, pc] of spur) reserved.add(keyOf(pr, pc));
    return;
  }
}

function applySolution(tiles: CircuitTile[][], masks: number[][]) {
  const size = tiles.length;
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const t = tiles[r][c];
      if (t.kind === "source" || t.kind === "output") {
        t.openMask = masks[r][c] || (t.kind === "source" ? E : W);
        t.rot = 0;
        t.fixed = true;
        continue;
      }
      if (t.kind === "danger" || t.kind === "block") continue;
      const want = masks[r][c];
      if (!want) continue;
      const kind = kindForMask(want);
      t.kind = kind;
      t.rot = rotToMatch(kind, want);
      t.openMask = undefined;
      t.fixed = false;
    }
  }
}

function scramble(tiles: CircuitTile[][], rand: () => number) {
  const size = tiles.length;
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const t = tiles[r][c];
      if (
        t.fixed ||
        t.kind === "block" ||
        t.kind === "source" ||
        t.kind === "output"
      ) {
        continue;
      }
      // At least one turn away from solution often
      const turns = 1 + Math.floor(rand() * 3);
      t.rot = (t.rot + turns) % 4;
    }
  }
  if (isSolved(tiles)) {
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        const t = tiles[r][c];
        if (
          t.fixed ||
          t.kind === "block" ||
          t.kind === "source" ||
          t.kind === "output"
        ) {
          continue;
        }
        t.rot = (t.rot + 1) % 4;
        return;
      }
    }
  }
}

const FILLER_KINDS: TileKind[] = ["straight", "corner", "corner", "tee", "cross"];

export function generateCircuit(
  opts: {
    size: number;
    sources: number;
    outputs: number;
    dangers: number;
    seed: number;
  },
  attempt = 0
): CircuitPuzzle {
  const size = Math.min(6, Math.max(3, opts.size));
  const rand = mulberry32(((opts.seed || 1) + attempt * 9973) >>> 0);

  const tiles: CircuitTile[][] = Array.from({ length: size }, () =>
    Array.from({ length: size }, () => ({
      kind: "block" as TileKind,
      rot: 0,
      fixed: true,
    }))
  );
  const masks = Array.from({ length: size }, () => Array(size).fill(0));

  const sources: [number, number][] = [];
  const outputs: [number, number][] = [];
  const taken = new Set<string>();

  const srcCount = Math.min(Math.max(1, opts.sources), Math.max(1, size - 1));
  const outCount = Math.min(Math.max(1, opts.outputs), Math.max(1, size - 1));

  for (let i = 0; i < srcCount; i++) {
    const cell = randomEdgeCell(size, rand, taken);
    sources.push(cell);
    taken.add(keyOf(cell[0], cell[1]));
  }
  for (let i = 0; i < outCount; i++) {
    const cell = randomEdgeCell(size, rand, taken);
    outputs.push(cell);
    taken.add(keyOf(cell[0], cell[1]));
  }

  const reserved = new Set<string>();
  for (const [r, c] of sources) {
    tiles[r][c] = { kind: "source", rot: 0, fixed: true };
    reserved.add(keyOf(r, c));
  }
  for (const [r, c] of outputs) {
    tiles[r][c] = { kind: "output", rot: 0, fixed: true };
    reserved.add(keyOf(r, c));
  }

  // Soft-block other terminals while pathfinding
  const softBlocked = new Set<string>(reserved);

  for (const out of shuffle(outputs, rand)) {
    // Prefer a random source each time for multi-source variety
    const srcOrder = shuffle(sources, rand);
    let best: [number, number][] | null = null;
    for (const src of srcOrder) {
      const blocked = new Set(softBlocked);
      blocked.delete(keyOf(src[0], src[1]));
      blocked.delete(keyOf(out[0], out[1]));
      const path = windingPath(size, src, out, rand, blocked);
      if (!best || path.length > best.length) {
        // Prefer longer/winding when reasonable
        if (!best || rand() < 0.65 || path.length < best.length + 2) {
          best = path;
        }
      }
      // Early accept sometimes
      if (best && best.length >= size && rand() < 0.4) break;
    }
    if (best) {
      carvePath(masks, best);
      for (const [r, c] of best) reserved.add(keyOf(r, c));
    }
  }

  // Spurs for shape variety
  const spurCount = 1 + Math.floor(rand() * Math.max(1, size - 2));
  for (let i = 0; i < spurCount; i++) {
    addSpur(size, masks, reserved, rand);
  }

  // Dangers: near path, never on solution cells
  let dangersLeft = Math.max(0, opts.dangers);
  let tries = 0;
  while (dangersLeft > 0 && tries++ < 120) {
    const r = Math.floor(rand() * size);
    const c = Math.floor(rand() * size);
    const k = keyOf(r, c);
    if (reserved.has(k)) continue;
    // Prefer adjacency to path
    let near = false;
    for (let d = 0; d < 4; d++) {
      const nr = r + DR[d];
      const nc = c + DC[d];
      if (inBounds(size, nr, nc) && reserved.has(keyOf(nr, nc))) near = true;
    }
    if (!near && rand() > 0.25) continue;

    const dangerKinds: TileKind[] = ["corner", "tee", "straight", "cross"];
    tiles[r][c] = {
      kind: dangerKinds[Math.floor(rand() * dangerKinds.length)],
      rot: Math.floor(rand() * 4),
    };
    // Mark as danger kind (keep shape variety via rot on danger cross visually)
    tiles[r][c] = {
      kind: "danger",
      rot: Math.floor(rand() * 4),
    };
    reserved.add(k);
    dangersLeft -= 1;
  }

  // Materialize path + busy filler so boards aren't empty blocks
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (tiles[r][c].kind === "source" || tiles[r][c].kind === "output") continue;
      if (tiles[r][c].kind === "danger") continue;

      const want = masks[r][c];
      if (want) {
        const kind = kindForMask(want);
        tiles[r][c] = { kind, rot: rotToMatch(kind, want) };
        continue;
      }

      // Filler: mostly pipes, occasional block
      if (rand() < 0.22) {
        tiles[r][c] = { kind: "block", rot: 0, fixed: true };
      } else {
        const kind = FILLER_KINDS[Math.floor(rand() * FILLER_KINDS.length)];
        tiles[r][c] = { kind, rot: Math.floor(rand() * 4) };
      }
    }
  }

  applySolution(tiles, masks);

  // Guarantee completable - if not, force solution state then scramble
  if (!isSolved(tiles)) {
    applySolution(tiles, masks);
  }

  // Final safety: retry with a different seed (cap attempts)
  if (!isSolved(tiles)) {
    if (attempt < 8) {
      return generateCircuit(
        { ...opts, dangers: attempt >= 4 ? 0 : opts.dangers },
        attempt + 1
      );
    }
    // Last resort: keep solution orientation (still playable)
    applySolution(tiles, masks);
    scramble(tiles, rand);
    return { size, tiles };
  }

  scramble(tiles, rand);

  return { size, tiles };
}

export function cloneTiles(tiles: CircuitTile[][]): CircuitTile[][] {
  return tiles.map((row) => row.map((t) => ({ ...t })));
}
