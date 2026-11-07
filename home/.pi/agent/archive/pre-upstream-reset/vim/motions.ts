import type { MotionKey, Pos, Range } from "./types";

function isWordChar(char: string | undefined): boolean {
  return !!char && /[A-Za-z0-9_]/.test(char);
}

function isBigWordChar(char: string | undefined): boolean {
  return !!char && !/\s/.test(char);
}

export function comparePos(a: Pos, b: Pos): number {
  if (a.line !== b.line) return a.line - b.line;
  return a.col - b.col;
}

export function normalizeRange(start: Pos, end: Pos): Range {
  return comparePos(start, end) <= 0 ? { start, end } : { start: end, end: start };
}

export function firstNonBlankCol(lines: string[], line: number): number {
  const text = lines[line] ?? "";
  const idx = text.search(/\S/);
  return idx === -1 ? 0 : idx;
}

export function clampCursor(lines: string[], pos: Pos): Pos {
  const line = Math.max(0, Math.min(pos.line, Math.max(0, lines.length - 1)));
  const text = lines[line] ?? "";
  const col = Math.max(0, Math.min(pos.col, text.length));
  return { line, col };
}

function nextWordStart(lines: string[], pos: Pos, bigWord: boolean): Pos {
  const isChar = bigWord ? isBigWordChar : isWordChar;
  let line = pos.line;

  while (line < lines.length) {
    const text = lines[line] ?? "";
    let i = line === pos.line ? pos.col : 0;

    if (line === pos.line && i < text.length && isChar(text[i])) {
      while (i < text.length && isChar(text[i])) i++;
    }
    while (i < text.length && !isChar(text[i])) i++;
    if (i < text.length) return { line, col: i };

    line++;
  }

  return pos;
}

function prevWordStart(lines: string[], pos: Pos, bigWord: boolean): Pos {
  const isChar = bigWord ? isBigWordChar : isWordChar;
  let line = pos.line;
  let col = pos.col - 1;

  while (line >= 0) {
    const text = lines[line] ?? "";
    let i = line === pos.line ? Math.min(col, text.length - 1) : text.length - 1;

    while (i >= 0 && !isChar(text[i])) i--;
    while (i > 0 && isChar(text[i - 1])) i--;
    if (i >= 0 && isChar(text[i])) return { line, col: i };

    line--;
    col = Number.MAX_SAFE_INTEGER;
  }

  return { line: 0, col: 0 };
}

function wordEnd(lines: string[], pos: Pos, bigWord: boolean): Pos {
  const isChar = bigWord ? isBigWordChar : isWordChar;
  let line = pos.line;

  while (line < lines.length) {
    const text = lines[line] ?? "";
    let i = line === pos.line ? pos.col : 0;

    if (i < text.length && isChar(text[i])) {
      if (i + 1 < text.length && isChar(text[i + 1])) {
        while (i + 1 < text.length && isChar(text[i + 1])) i++;
        return { line, col: i };
      }
      i++;
    }

    while (i < text.length && !isChar(text[i])) i++;
    if (i < text.length) {
      while (i + 1 < text.length && isChar(text[i + 1])) i++;
      return { line, col: i };
    }

    line++;
  }

  return pos;
}

function applySingleMotion(lines: string[], from: Pos, motion: MotionKey): Pos {
  const text = lines[from.line] ?? "";

  switch (motion) {
    case "h":
      return { line: from.line, col: Math.max(0, from.col - 1) };
    case "l":
      return { line: from.line, col: Math.min(text.length, from.col + 1) };
    case "j": {
      const next = Math.min(lines.length - 1, from.line + 1);
      return clampCursor(lines, { line: next, col: from.col });
    }
    case "k": {
      const prev = Math.max(0, from.line - 1);
      return clampCursor(lines, { line: prev, col: from.col });
    }
    case "w":
      return nextWordStart(lines, from, false);
    case "W":
      return nextWordStart(lines, from, true);
    case "b":
      return prevWordStart(lines, from, false);
    case "B":
      return prevWordStart(lines, from, true);
    case "e":
      return wordEnd(lines, from, false);
    case "E":
      return wordEnd(lines, from, true);
    case "0":
      return { line: from.line, col: 0 };
    case "^":
      return { line: from.line, col: firstNonBlankCol(lines, from.line) };
    case "$":
      return { line: from.line, col: text.length };
  }
}

export function resolveMotion(lines: string[], from: Pos, motion: MotionKey, count = 1): Pos {
  let result = from;
  for (let i = 0; i < count; i++) {
    const next = applySingleMotion(lines, result, motion);
    if (comparePos(next, result) === 0) break;
    result = next;
  }
  return clampCursor(lines, result);
}

export function motionRange(lines: string[], start: Pos, motion: MotionKey, count = 1): Range | null {
  const target = resolveMotion(lines, start, motion, count);

  if (motion === "b" || motion === "B" || motion === "h") {
    return comparePos(target, start) === 0 ? null : { start: target, end: start };
  }

  if (motion === "e" || motion === "E") {
    return comparePos(target, start) < 0 ? null : { start, end: clampCursor(lines, { line: target.line, col: target.col + 1 }) };
  }

  return comparePos(target, start) === 0 ? null : { start, end: target };
}

export function posToIndex(lines: string[], pos: Pos): number {
  let idx = 0;
  for (let i = 0; i < pos.line; i++) idx += (lines[i] ?? "").length + 1;
  return idx + pos.col;
}
