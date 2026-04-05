/**
 * Modal Editor - vim-like modal editing extension
 *
 * Refactored to use a small vim state machine architecture inspired by more
 * complete modal editors: a thin Pi editor adapter + isolated command
 * transitions + pure motion helpers.
 *
 * Supported:
 * - motions: h j k l, b w e, 0 ^ $
 * - insert: i a I A o O
 * - jumps: gg, G, {count}gg, {count}G
 * - edit: x, u, p, P
 * - operators: d c y with h l w e b 0 ^ $, plus dd cc yy
 * - counts: 2w, 3x, 4dd, 2dw, ...
 *
 * Notes:
 * - Still intentionally lightweight, not embedded Neovim.
 * - Yanks/pastes use the macOS global clipboard via pbcopy/pbpaste.
 */

import { execFileSync } from "node:child_process";
import { CustomEditor, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { CURSOR_MARKER, matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { clampCursor, firstNonBlankCol, motionRange, normalizeRange, posToIndex, resolveMotion } from "./vim/motions";
import { transition, type TransitionContext } from "./vim/transitions";
import { createIdleCommandState, createInitialVimState, type CommandState, type MotionKey, type Operator, type Pos, type Range, type VimState } from "./vim/types";

const CURSOR_BLOCK = "\x1b[1 q";
const CURSOR_BEAM = "\x1b[5 q";

function writeToTerminal(sequence: string): void {
  if (process.stdout.isTTY) process.stdout.write(sequence);
}

class ModalEditor extends CustomEditor {
  private vimState: VimState = createInitialVimState();

  public syncCursorShape(): void {
    writeToTerminal(this.vimState.mode === "insert" ? CURSOR_BEAM : CURSOR_BLOCK);
  }

  private get internal(): any {
    return this as any;
  }

  private getState(): { lines: string[]; cursorLine: number; cursorCol: number } {
    return this.internal.state;
  }

  private get commandState(): CommandState {
    return this.vimState.mode === "normal" ? this.vimState.command : createIdleCommandState();
  }

  private setCommandState(command: CommandState): void {
    if (this.vimState.mode !== "normal") return;
    this.vimState = { mode: "normal", command };
    this.invalidate();
  }

  private resetCommandState(): void {
    if (this.vimState.mode === "normal") this.setCommandState(createIdleCommandState());
  }

  private setMode(mode: "normal" | "insert"): void {
    const next = mode === "insert" ? ({ mode: "insert" } satisfies VimState) : ({ mode: "normal", command: createIdleCommandState() } satisfies VimState);
    this.vimState = next;
    this.syncCursorShape();
    this.invalidate();
  }

  private pushUndo(): void {
    this.internal.pushUndoSnapshot?.();
  }

  private emitChange(): void {
    this.onChange?.(this.getText());
    this.invalidate();
  }

  private lineText(line = this.getCursor().line): string {
    return this.getLines()[line] ?? "";
  }

  private getCursorPos(): Pos {
    const c = this.getCursor();
    return { line: c.line, col: c.col };
  }

  private setCursor(pos: Pos): void {
    const state = this.getState();
    const next = clampCursor(this.getLines(), pos);
    state.cursorLine = next.line;
    state.cursorCol = next.col;
    this.invalidate();
  }

  private replaceText(text: string, cursor: Pos): void {
    this.internal.setTextInternal?.(text);
    this.setCursor(cursor);
    this.emitChange();
  }

  private sliceRange(range: Range): string {
    const normalized = normalizeRange(range.start, range.end);
    const lines = this.getLines();
    const text = this.getText();
    return text.slice(posToIndex(lines, normalized.start), posToIndex(lines, normalized.end));
  }

  private replaceRange(range: Range, replacement: string, cursor = range.start): void {
    const normalized = normalizeRange(range.start, range.end);
    const lines = this.getLines();
    const text = this.getText();
    const start = posToIndex(lines, normalized.start);
    const end = posToIndex(lines, normalized.end);
    this.pushUndo();
    this.replaceText(text.slice(0, start) + replacement + text.slice(end), normalized.start.line === cursor.line && normalized.start.col === cursor.col ? normalized.start : cursor);
  }

  private deleteRange(range: Range): string {
    const normalized = normalizeRange(range.start, range.end);
    const deleted = this.sliceRange(normalized);
    this.replaceRange(normalized, "", normalized.start);
    return deleted;
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
    const text = this.sliceRange(range);
    if (text) this.writeClipboard(text);
  }

  private enterInsert(kind: "i" | "a" | "I" | "A" | "o" | "O"): void {
    if (kind === "i") {
      this.setMode("insert");
      return;
    }

    if (kind === "a") {
      const cur = this.getCursorPos();
      if (cur.col < this.lineText(cur.line).length) this.setCursor({ line: cur.line, col: cur.col + 1 });
      this.setMode("insert");
      return;
    }

    if (kind === "I") {
      this.setCursor({ line: this.getCursor().line, col: firstNonBlankCol(this.getLines(), this.getCursor().line) });
      this.setMode("insert");
      return;
    }

    if (kind === "A") {
      this.setCursor({ line: this.getCursor().line, col: this.lineText().length });
      this.setMode("insert");
      return;
    }

    const state = this.getState();
    const lines = state.lines;
    const line = state.cursorLine;
    this.pushUndo();

    if (kind === "o") {
      lines.splice(line + 1, 0, "");
      state.cursorLine = line + 1;
      state.cursorCol = 0;
    } else {
      lines.splice(line, 0, "");
      state.cursorLine = line;
      state.cursorCol = 0;
    }

    this.setMode("insert");
    this.emitChange();
  }

  private moveMotion(motion: MotionKey, count: number): void {
    const target = resolveMotion(this.getLines(), this.getCursorPos(), motion, count);
    this.setCursor(target);
  }

  private executeOperatorMotion(op: Operator, motion: MotionKey, count: number): void {
    const range = motionRange(this.getLines(), this.getCursorPos(), motion, count);
    if (!range) return;

    if (op === "yank") {
      this.yankRange(range);
      return;
    }

    const deleted = this.deleteRange(range);
    if (deleted) this.writeClipboard(deleted);
    if (op === "change") this.setMode("insert");
  }

  private executeLineOp(op: Operator, count: number): void {
    const lines = [...this.getLines()];
    const line = this.getCursor().line;
    const start = line;
    const endExclusive = Math.min(lines.length, line + count);
    const removed = lines.slice(start, endExclusive);
    const linewiseText = `${removed.join("\n")}${endExclusive < lines.length || removed.length > 0 ? "\n" : ""}`;
    this.writeClipboard(linewiseText);

    if (op === "yank") return;

    this.pushUndo();

    if (op === "delete") {
      if (lines.length === removed.length) {
        lines.splice(0, lines.length, "");
      } else {
        lines.splice(start, removed.length);
      }
      const nextLine = Math.max(0, Math.min(start, lines.length - 1));
      this.replaceText(lines.join("\n"), { line: nextLine, col: 0 });
      return;
    }

    if (lines.length === removed.length) {
      this.replaceText("", { line: 0, col: 0 });
    } else {
      lines.splice(start, removed.length, "");
      this.replaceText(lines.join("\n"), { line: Math.max(0, Math.min(start, lines.length - 1)), col: 0 });
    }
    this.setMode("insert");
  }

  private executeDeleteChar(count: number): void {
    const cur = this.getCursorPos();
    const text = this.lineText(cur.line);
    if (cur.col >= text.length) return;
    const end = Math.min(text.length, cur.col + count);
    const deleted = this.deleteRange({ start: cur, end: { line: cur.line, col: end } });
    if (deleted) this.writeClipboard(deleted);
  }

  private executePaste(after: boolean, count: number): void {
    const clip = this.readClipboard();
    if (!clip) return;

    const state = this.getState();
    const currentLine = this.lineText();
    const wantsLinePaste = clip.endsWith("\n");

    if (wantsLinePaste) {
      const insertAt = state.cursorLine + (after ? 1 : 0);
      const base = clip.replace(/\n$/, "").split("\n");
      const toInsert = Array.from({ length: count }, () => base).flat();
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
    this.insertTextAtCursor(clip.repeat(count));
    this.setMode("normal");
  }

  private performUndo(): void {
    this.internal.undo?.();
    this.invalidate();
  }

  private goToLineStart(): void {
    this.setCursor({ line: this.getCursor().line, col: 0 });
  }

  private goToFirstLine(count: number): void {
    if (count > 1) {
      this.goToLine(count);
      return;
    }
    this.setCursor({ line: 0, col: 0 });
  }

  private goToLastLine(count: number): void {
    if (count > 1) {
      this.goToLine(count);
      return;
    }
    const lines = this.getLines();
    const line = Math.max(0, lines.length - 1);
    this.setCursor({ line, col: (lines[line] ?? "").length });
  }

  private goToLine(count: number): void {
    const lines = this.getLines();
    const line = Math.max(0, Math.min(lines.length - 1, count - 1));
    this.setCursor({ line, col: 0 });
  }

  private createTransitionContext(): TransitionContext {
    return {
      moveMotion: (motion, count) => this.moveMotion(motion, count),
      executeOperatorMotion: (op, motion, count) => this.executeOperatorMotion(op, motion, count),
      executeLineOp: (op, count) => this.executeLineOp(op, count),
      executeDeleteChar: (count) => this.executeDeleteChar(count),
      executePaste: (after, count) => this.executePaste(after, count),
      goToFirstLine: (count) => this.goToFirstLine(count),
      goToLastLine: (count) => this.goToLastLine(count),
      goToLineStart: () => this.goToLineStart(),
      enterInsert: (kind) => this.enterInsert(kind),
      undo: () => this.performUndo(),
    };
  }

  handleInput(data: string): void {
    if (matchesKey(data, "escape")) {
      if (this.vimState.mode === "insert") this.setMode("normal");
      else this.resetCommandState();
      return;
    }

    // Let app/editor control keys behave exactly like the base editor.
    // In particular, Ctrl+C should still trigger Pi's interrupt behavior in
    // normal mode instead of being swallowed by vim command parsing.
    if (data.length > 0 && data.charCodeAt(0) < 32) {
      super.handleInput(data);
      return;
    }

    if (this.vimState.mode === "insert") {
      super.handleInput(data);
      return;
    }

    const result = transition(this.commandState, data, this.createTransitionContext());
    if (result.handled) {
      this.setCommandState(result.next);
      if (result.mode === "insert") this.setMode("insert");
      return;
    }

    if (data.length === 1 && data.charCodeAt(0) >= 32) return;
    super.handleInput(data);
  }

  private commandSuffix(): string {
    if (this.vimState.mode !== "normal") return "";

    const state = this.vimState.command;
    if (state.type === "idle") return "";
    if (state.type === "count") return ` ${state.digits}`;
    if (state.type === "g") return ` ${state.count === 1 ? "g" : `${state.count}g`}`;
    if (state.type === "operator") {
      const prefix = state.op === "delete" ? "d" : state.op === "change" ? "c" : "y";
      return ` ${state.count > 1 ? `${state.count}` : ""}${prefix}`;
    }
    const prefix = state.op === "delete" ? "d" : state.op === "change" ? "c" : "y";
    return ` ${state.count > 1 ? `${state.count}` : ""}${prefix}${state.digits}`;
  }

  render(width: number): string[] {
    const lines = super.render(width);
    if (lines.length === 0) return lines;

    for (let i = 0; i < lines.length; i++) {
      lines[i] = lines[i]!
        .replace(`${CURSOR_MARKER}\x1b[7m \x1b[0m`, CURSOR_MARKER)
        .replace(new RegExp(`${CURSOR_MARKER}\\x1b\\[7m([\\s\\S])\\x1b\\[0m`, "g"), `${CURSOR_MARKER}$1`);
    }

    const label = `${this.vimState.mode === "normal" ? " NORMAL" : " INSERT"}${this.commandSuffix()} `;
    const last = lines.length - 1;
    if (visibleWidth(lines[last]!) >= label.length) {
      lines[last] = truncateToWidth(lines[last]!, width - label.length, "") + label;
    }
    return lines;
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setEditorComponent((tui, theme, kb) => {
      const editor = new ModalEditor(tui, theme, kb);
      editor.syncCursorShape();
      return editor;
    });
  });
}
