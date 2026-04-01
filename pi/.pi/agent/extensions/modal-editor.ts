/**
 * Modal Editor - vim-like modal editing example
 *
 * Usage: pi --extension ./examples/extensions/modal-editor.ts
 *
 * Added here with a more practical Vim-ish normal mode:
 * - motions: h j k l, b w e, 0 ^ $
 * - insert: i a I A o O
 * - jumps: gg, G
 * - edit: x, u, p, P
 * - operators: d c y with w e b 0 ^ $, plus dd cc yy
 *
 * Notes:
 * - This is a lightweight approximation, not embedded Neovim.
 * - Yanks/pastes use the macOS global clipboard via pbcopy/pbpaste.
 */

import { execFileSync } from "node:child_process";
import { CustomEditor, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type Mode = "normal" | "insert";
type PendingOp = "g" | "d" | "c" | "y" | null;
type MotionKey = "w" | "e" | "b" | "W" | "E" | "B" | "0" | "^" | "$";

type Pos = { line: number; col: number };
type Range = { start: Pos; end: Pos };

const DIRECT_KEYS: Record<string, string | null> = {
  h: "\x1b[D",
  j: "\x1b[B",
  k: "\x1b[A",
  l: "\x1b[C",
  b: null,
  w: null,
  e: null,
  B: null,
  W: null,
  E: null,
  "0": null,
  "^": null,
  $: null,
  x: null,
  i: null,
  a: null,
  I: null,
  A: null,
  o: null,
  O: null,
  u: null,
  p: null,
  P: null,
  g: null,
  G: null,
  d: null,
  c: null,
  y: null,
};

class ModalEditor extends CustomEditor {
  private mode: Mode = "insert";
  private pending: PendingOp = null;

  private get internal(): any {
    return this as any;
  }

  private getState(): { lines: string[]; cursorLine: number; cursorCol: number } {
    return this.internal.state;
  }

  private clampCursor(pos: Pos): Pos {
    const lines = this.getLines();
    const line = Math.max(0, Math.min(pos.line, Math.max(0, lines.length - 1)));
    const text = lines[line] ?? "";
    const col = Math.max(0, Math.min(pos.col, text.length));
    return { line, col };
  }

  private setCursor(pos: Pos): void {
    const state = this.getState();
    const next = this.clampCursor(pos);
    state.cursorLine = next.line;
    state.cursorCol = next.col;
    this.invalidate();
  }

  private getCursorPos(): Pos {
    const c = this.getCursor();
    return { line: c.line, col: c.col };
  }

  private pushUndo(): void {
    this.internal.pushUndoSnapshot?.();
  }

  private emitChange(): void {
    this.onChange?.(this.getText());
    this.invalidate();
  }

  private isWordChar(char: string | undefined): boolean {
    return !!char && /[A-Za-z0-9_]/.test(char);
  }

  private lineText(line = this.getCursor().line): string {
    return this.getLines()[line] ?? "";
  }

  private firstNonBlankCol(line = this.getCursor().line): number {
    const text = this.lineText(line);
    const idx = text.search(/\S/);
    return idx === -1 ? 0 : idx;
  }

  private moveLineStart(): void {
    this.setCursor({ line: this.getCursor().line, col: 0 });
  }

  private moveFirstNonBlank(): void {
    this.setCursor({ line: this.getCursor().line, col: this.firstNonBlankCol() });
  }

  private moveLineEnd(): void {
    this.setCursor({ line: this.getCursor().line, col: this.lineText().length });
  }

  private moveFileStart(): void {
    this.setCursor({ line: 0, col: 0 });
  }

  private moveFileEnd(): void {
    const lines = this.getLines();
    const line = Math.max(0, lines.length - 1);
    this.setCursor({ line, col: (lines[line] ?? "").length });
  }

  private isBigWordChar(char: string | undefined): boolean {
    return !!char && !/\s/.test(char);
  }

  private nextWordStart(pos = this.getCursorPos(), bigWord = false): Pos {
    const lines = this.getLines();
    const isChar = bigWord ? this.isBigWordChar.bind(this) : this.isWordChar.bind(this);
    let line = pos.line;
    let col = pos.col;

    while (line < lines.length) {
      const text = lines[line] ?? "";
      let i = line === pos.line ? col : 0;

      if (line === pos.line && i < text.length && isChar(text[i])) {
        while (i < text.length && isChar(text[i])) i++;
      }
      while (i < text.length && !isChar(text[i])) i++;
      if (i < text.length) return { line, col: i };

      line++;
      col = 0;
    }

    return this.getCursorPos();
  }

  private prevWordStart(pos = this.getCursorPos(), bigWord = false): Pos {
    const lines = this.getLines();
    const isChar = bigWord ? this.isBigWordChar.bind(this) : this.isWordChar.bind(this);
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

  private wordEnd(pos = this.getCursorPos(), bigWord = false): Pos {
    const lines = this.getLines();
    const isChar = bigWord ? this.isBigWordChar.bind(this) : this.isWordChar.bind(this);
    let line = pos.line;

    while (line < lines.length) {
      const text = lines[line] ?? "";
      let i = line === pos.line ? pos.col : 0;

      if (i < text.length && isChar(text[i])) {
        // If we're inside a word, go to the end of this word unless we're
        // already on its last character. In that case, continue to the next
        // word, matching Vim's `e` behavior.
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

    return this.getCursorPos();
  }

  private moveWordForward(bigWord = false): void {
    this.setCursor(this.nextWordStart(this.getCursorPos(), bigWord));
  }

  private moveWordBackward(bigWord = false): void {
    this.setCursor(this.prevWordStart(this.getCursorPos(), bigWord));
  }

  private moveWordEnd(bigWord = false): void {
    this.setCursor(this.wordEnd(this.getCursorPos(), bigWord));
  }

  private comparePos(a: Pos, b: Pos): number {
    if (a.line !== b.line) return a.line - b.line;
    return a.col - b.col;
  }

  private normalizeRange(start: Pos, end: Pos): Range {
    return this.comparePos(start, end) <= 0 ? { start, end } : { start: end, end: start };
  }

  private posToIndex(pos: Pos): number {
    const lines = this.getLines();
    let idx = 0;
    for (let i = 0; i < pos.line; i++) idx += (lines[i] ?? "").length + 1;
    return idx + pos.col;
  }

  private sliceRange(range: Range): string {
    const text = this.getText();
    return text.slice(this.posToIndex(range.start), this.posToIndex(range.end));
  }

  private replaceRange(range: Range, replacement: string, cursor = range.start): void {
    const normalized = this.normalizeRange(range.start, range.end);
    const text = this.getText();
    const start = this.posToIndex(normalized.start);
    const end = this.posToIndex(normalized.end);
    this.pushUndo();
    this.internal.setTextInternal?.(text.slice(0, start) + replacement + text.slice(end));
    this.setCursor(cursor);
    this.invalidate();
  }

  private deleteRange(range: Range): string {
    const normalized = this.normalizeRange(range.start, range.end);
    const deleted = this.sliceRange(normalized);
    this.replaceRange(normalized, "", normalized.start);
    return deleted;
  }

  private getMotionTarget(motion: MotionKey, from = this.getCursorPos()): Pos {
    if (motion === "w") return this.nextWordStart(from, false);
    if (motion === "W") return this.nextWordStart(from, true);
    if (motion === "e") return this.wordEnd(from, false);
    if (motion === "E") return this.wordEnd(from, true);
    if (motion === "b") return this.prevWordStart(from, false);
    if (motion === "B") return this.prevWordStart(from, true);
    if (motion === "0") return { line: from.line, col: 0 };
    if (motion === "^") return { line: from.line, col: this.firstNonBlankCol(from.line) };
    return { line: from.line, col: this.lineText(from.line).length };
  }

  private motionRange(motion: MotionKey): Range | null {
    const start = this.getCursorPos();
    const target = this.getMotionTarget(motion, start);

    if (motion === "b") {
      return this.comparePos(target, start) === 0 ? null : { start: target, end: start };
    }

    if (motion === "e") {
      return this.comparePos(target, start) < 0 ? null : { start, end: { line: target.line, col: target.col + 1 } };
    }

    return this.comparePos(target, start) === 0 ? null : { start, end: target };
  }

  private readClipboard(): string {
    try {
      return execFileSync("pbpaste", { encoding: "utf8" });
    } catch {
      return "";
    }
  }

  private writeClipboard(text: string): void {
    try {
      execFileSync("pbcopy", { input: text, encoding: "utf8" });
    } catch {
      // Ignore when clipboard tooling is unavailable.
    }
  }

  private yankRange(range: Range): void {
    const text = this.sliceRange(this.normalizeRange(range.start, range.end));
    if (text) this.writeClipboard(text);
  }

  private yankLine(): void {
    const lines = this.getLines();
    const line = this.getCursor().line;
    const text = (lines[line] ?? "") + (line < lines.length - 1 ? "\n" : "");
    this.writeClipboard(text);
  }

  private deleteCurrentLine(change = false): void {
    const lines = [...this.getLines()];
    const line = this.getCursor().line;
    const deleted = lines[line] ?? "";
    this.writeClipboard(deleted + (lines.length > 1 ? "\n" : ""));

    this.pushUndo();
    if (lines.length === 1) {
      lines[0] = "";
    } else {
      lines.splice(line, 1);
    }

    this.internal.setTextInternal?.(lines.join("\n"));
    const nextLine = Math.min(line, lines.length - 1);
    this.setCursor({ line: Math.max(0, nextLine), col: change ? this.firstNonBlankCol(Math.max(0, nextLine)) : 0 });
    this.invalidate();
    if (change) this.mode = "insert";
  }

  private changeRange(range: Range): void {
    const deleted = this.deleteRange(range);
    if (deleted) this.writeClipboard(deleted);
    this.mode = "insert";
  }

  private deleteByMotion(motion: MotionKey): void {
    const range = this.motionRange(motion);
    if (!range) return;
    const deleted = this.deleteRange(range);
    if (deleted) this.writeClipboard(deleted);
  }

  private changeByMotion(motion: MotionKey): void {
    const range = this.motionRange(motion);
    if (!range) return;
    this.changeRange(range);
  }

  private yankByMotion(motion: MotionKey): void {
    const range = this.motionRange(motion);
    if (!range) return;
    this.yankRange(range);
  }

  private deleteChar(): void {
    const cur = this.getCursorPos();
    const text = this.lineText(cur.line);
    if (cur.col >= text.length) return;
    const deleted = this.deleteRange({ start: cur, end: { line: cur.line, col: cur.col + 1 } });
    if (deleted) this.writeClipboard(deleted);
  }

  private openBelow(): void {
    const state = this.getState();
    const lines = state.lines;
    const line = state.cursorLine;
    this.pushUndo();
    lines.splice(line + 1, 0, "");
    state.cursorLine = line + 1;
    state.cursorCol = 0;
    this.mode = "insert";
    this.emitChange();
  }

  private openAbove(): void {
    const state = this.getState();
    const lines = state.lines;
    const line = state.cursorLine;
    this.pushUndo();
    lines.splice(line, 0, "");
    state.cursorLine = line;
    state.cursorCol = 0;
    this.mode = "insert";
    this.emitChange();
  }

  private paste(after: boolean): void {
    const clip = this.readClipboard();
    if (!clip) return;

    const state = this.getState();
    const currentLine = this.lineText();
    const wantsLinePaste = clip.endsWith("\n");

    if (wantsLinePaste) {
      const insertAt = state.cursorLine + (after ? 1 : 0);
      const toInsert = clip.replace(/\n$/, "").split("\n");
      this.pushUndo();
      state.lines.splice(insertAt, 0, ...toInsert);
      state.cursorLine = insertAt;
      state.cursorCol = 0;
      this.emitChange();
      return;
    }

    if (after && state.cursorCol < currentLine.length) {
      this.setCursor({ line: state.cursorLine, col: state.cursorCol + 1 });
    }
    this.insertTextAtCursor(clip);
    this.mode = "normal";
  }

  private undo(): void {
    super.handleInput("\x1f");
  }

  private clearPending(): void {
    this.pending = null;
  }

  private handlePending(data: string): boolean {
    const pending = this.pending;
    if (!pending) return false;
    this.pending = null;

    if (pending === "g") {
      if (data === "g") {
        this.moveFileStart();
        return true;
      }
      return true;
    }

    if (pending === "d") {
      if (data === "d") {
        this.deleteCurrentLine(false);
        return true;
      }
      if (["w", "e", "b", "W", "E", "B", "0", "^", "$"].includes(data)) {
        this.deleteByMotion(data as MotionKey);
        return true;
      }
      return true;
    }

    if (pending === "c") {
      if (data === "c") {
        this.deleteCurrentLine(true);
        return true;
      }
      if (["w", "e", "b", "W", "E", "B", "0", "^", "$"].includes(data)) {
        this.changeByMotion(data as MotionKey);
        return true;
      }
      return true;
    }

    if (pending === "y") {
      if (data === "y") {
        this.yankLine();
        return true;
      }
      if (["w", "e", "b", "W", "E", "B", "0", "^", "$"].includes(data)) {
        this.yankByMotion(data as MotionKey);
        return true;
      }
      return true;
    }

    return false;
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape")) {
      this.clearPending();
      if (this.mode === "insert") {
        this.mode = "normal";
      } else {
        super.handleInput(data);
      }
      return;
    }

    if (this.mode === "insert") {
      super.handleInput(data);
      return;
    }

    if (this.handlePending(data)) return;

    if (data in DIRECT_KEYS) {
      if (data === "i") this.mode = "insert";
      else if (data === "a") {
        const cur = this.getCursorPos();
        if (cur.col < this.lineText().length) this.setCursor({ line: cur.line, col: cur.col + 1 });
        this.mode = "insert";
      } else if (data === "I") {
        this.moveFirstNonBlank();
        this.mode = "insert";
      } else if (data === "A") {
        this.moveLineEnd();
        this.mode = "insert";
      } else if (data === "o") this.openBelow();
      else if (data === "O") this.openAbove();
      else if (data === "w") this.moveWordForward(false);
      else if (data === "b") this.moveWordBackward(false);
      else if (data === "e") this.moveWordEnd(false);
      else if (data === "W") this.moveWordForward(true);
      else if (data === "B") this.moveWordBackward(true);
      else if (data === "E") this.moveWordEnd(true);
      else if (data === "0") this.moveLineStart();
      else if (data === "^") this.moveFirstNonBlank();
      else if (data === "$") this.moveLineEnd();
      else if (data === "x") this.deleteChar();
      else if (data === "u") this.undo();
      else if (data === "p") this.paste(true);
      else if (data === "P") this.paste(false);
      else if (data === "g") this.pending = "g";
      else if (data === "G") this.moveFileEnd();
      else if (data === "d") this.pending = "d";
      else if (data === "c") this.pending = "c";
      else if (data === "y") this.pending = "y";
      else {
        const seq = DIRECT_KEYS[data];
        if (seq) super.handleInput(seq);
      }
      return;
    }

    if (data.length === 1 && data.charCodeAt(0) >= 32) return;
    super.handleInput(data);
  }

  render(width: number): string[] {
    const lines = super.render(width);
    if (lines.length === 0) return lines;

    const pending = this.pending ? ` ${this.pending}` : "";
    const label = `${this.mode === "normal" ? " NORMAL" : " INSERT"}${pending} `;
    const last = lines.length - 1;
    if (visibleWidth(lines[last]!) >= label.length) {
      lines[last] = truncateToWidth(lines[last]!, width - label.length, "") + label;
    }
    return lines;
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setEditorComponent((tui, theme, kb) => new ModalEditor(tui, theme, kb));
  });
}
