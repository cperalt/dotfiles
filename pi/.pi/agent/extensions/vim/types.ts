export type Mode = "normal" | "insert";

export type Operator = "delete" | "change" | "yank";

export type MotionKey = "h" | "j" | "k" | "l" | "w" | "e" | "b" | "W" | "E" | "B" | "0" | "^" | "$";

export type Pos = { line: number; col: number };
export type Range = { start: Pos; end: Pos };

export type CommandState =
  | { type: "idle" }
  | { type: "count"; digits: string }
  | { type: "operator"; op: Operator; count: number }
  | { type: "operatorCount"; op: Operator; count: number; digits: string }
  | { type: "g"; count: number };

export type VimState =
  | { mode: "insert" }
  | { mode: "normal"; command: CommandState };

export const OPERATORS = {
  d: "delete",
  c: "change",
  y: "yank",
} as const satisfies Record<string, Operator>;

export function isOperatorKey(key: string): key is keyof typeof OPERATORS {
  return key in OPERATORS;
}

export const SIMPLE_MOTIONS = new Set<MotionKey>([
  "h",
  "j",
  "k",
  "l",
  "w",
  "e",
  "b",
  "W",
  "E",
  "B",
  "0",
  "^",
  "$",
]);

export const OPERATOR_MOTIONS = new Set<MotionKey>([
  "h",
  "l",
  "w",
  "e",
  "b",
  "W",
  "E",
  "B",
  "0",
  "^",
  "$",
]);

export function createInitialVimState(): VimState {
  return { mode: "insert" };
}

export function createIdleCommandState(): CommandState {
  return { type: "idle" };
}

export function parseCount(digits: string): number {
  return Math.max(1, Number.parseInt(digits, 10) || 1);
}
