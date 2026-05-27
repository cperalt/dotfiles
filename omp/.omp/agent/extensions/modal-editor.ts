/**
 * Modal Editor - vim-like modal editing for the omp prompt editor.
 *
 * Ported from the original @mariozechner/pi extension to @oh-my-pi (OMP).
 * OMP's pi-tui Editor uses true JS private fields for its internal state,
 * so this adapter only touches the public `Editor` API:
 *
 *   - getText() / getLines() / getCursor()
 *   - setText(text)            -- replaces buffer; cursor goes to the end
 *   - insertText(text)         -- single-line insert at cursor (records undo)
 *   - moveToLineStart/End()    -- public cursor movers
 *   - moveToMessageStart/End() -- public cursor movers
 *   - super.handleInput(seq)   -- synthesised arrow keys, etc.
 *
 * Mutations go through setText(...) for correctness; we keep our own undo
 * stack because setText bypasses the editor's history.
 *
 * Supported:
 *   motions: h j k l, b w e (and B W E), 0 ^ $
 *   insert:  i a I A o O
 *   jumps:   gg, G, {count}gg, {count}G
 *   edit:    x, u, p, P
 *   ops:     d c y with h l w e b 0 ^ $, plus dd cc yy
 *   counts:  2w, 3x, 4dd, 2dw, ...
 *
 * Yank/paste use the macOS pasteboard via pbcopy/pbpaste.
 */

import { execFileSync } from "node:child_process";
import { CustomEditor, type ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { CURSOR_MARKER, matchesKey, truncateToWidth, visibleWidth } from "@oh-my-pi/pi-tui";
import {
	clampCursor,
	firstNonBlankCol,
	motionRange,
	normalizeRange,
	posToIndex,
	resolveMotion,
} from "./vim/motions";
import { transition, type TransitionContext } from "./vim/transitions";
import {
	createIdleCommandState,
	createInitialVimState,
	type CommandState,
	type MotionKey,
	type Operator,
	type Pos,
	type Range,
	type VimState,
} from "./vim/types";

const CURSOR_BLOCK = "\x1b[1 q";
const CURSOR_BEAM = "\x1b[5 q";

const KEY_LEFT = "\x1b[D";
const KEY_RIGHT = "\x1b[C";
const KEY_DOWN = "\x1b[B";
const KEY_UP = "\x1b[A";

const MAX_UNDO = 100;

function writeToTerminal(sequence: string): void {
	if (process.stdout.isTTY) process.stdout.write(sequence);
}

type Snapshot = { text: string; cursor: Pos };

class ModalEditor extends CustomEditor {
	private vimState: VimState = createInitialVimState();
	private undoStack: Snapshot[] = [];

	public syncCursorShape(): void {
		writeToTerminal(this.vimState.mode === "insert" ? CURSOR_BEAM : CURSOR_BLOCK);
	}

	// ----- vim state helpers ---------------------------------------------------

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
		this.vimState =
			mode === "insert"
				? ({ mode: "insert" } satisfies VimState)
				: ({ mode: "normal", command: createIdleCommandState() } satisfies VimState);
		this.syncCursorShape();
		this.invalidate();
	}

	// ----- editor adapters -----------------------------------------------------

	private getCursorPos(): Pos {
		const c = this.getCursor();
		return { line: c.line, col: c.col };
	}

	private snapshot(): Snapshot {
		return { text: this.getText(), cursor: this.getCursorPos() };
	}

	private pushUndo(): void {
		this.undoStack.push(this.snapshot());
		if (this.undoStack.length > MAX_UNDO) this.undoStack.shift();
	}

	private positionCursor(target: Pos): void {
		// After setText(), the editor's cursor sits at the end of the buffer.
		// Reset to (0,0) and step to target with public movers + synthesized arrows.
		const lines = this.getLines();
		const clamped = clampCursor(lines, target);
		this.moveToMessageStart();
		for (let i = 0; i < clamped.line; i++) super.handleInput(KEY_DOWN);
		this.moveToLineStart();
		for (let i = 0; i < clamped.col; i++) super.handleInput(KEY_RIGHT);
		this.invalidate();
	}

	private replaceBuffer(text: string, cursor: Pos): void {
		this.setText(text);
		this.positionCursor(cursor);
	}

	private sliceRange(range: Range): string {
		const normalized = normalizeRange(range.start, range.end);
		const lines = this.getLines();
		const text = this.getText();
		return text.slice(posToIndex(lines, normalized.start), posToIndex(lines, normalized.end));
	}

	private replaceRange(range: Range, replacement: string, cursor?: Pos): void {
		const normalized = normalizeRange(range.start, range.end);
		const lines = this.getLines();
		const text = this.getText();
		const start = posToIndex(lines, normalized.start);
		const end = posToIndex(lines, normalized.end);
		this.pushUndo();
		this.replaceBuffer(text.slice(0, start) + replacement + text.slice(end), cursor ?? normalized.start);
	}

	private deleteRange(range: Range): string {
		const normalized = normalizeRange(range.start, range.end);
		const deleted = this.sliceRange(normalized);
		this.replaceRange(normalized, "", normalized.start);
		return deleted;
	}

	// ----- clipboard -----------------------------------------------------------

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
			// pbcopy unavailable: silently drop the yank.
		}
	}

	private yankRange(range: Range): void {
		const text = this.sliceRange(range);
		if (text) this.writeClipboard(text);
	}

	// ----- vim operations ------------------------------------------------------

	private enterInsert(kind: "i" | "a" | "I" | "A" | "o" | "O"): void {
		const lines = this.getLines();
		const cur = this.getCursorPos();

		switch (kind) {
			case "i":
				this.setMode("insert");
				return;
			case "a": {
				const lineLen = (lines[cur.line] ?? "").length;
				if (cur.col < lineLen) this.positionCursor({ line: cur.line, col: cur.col + 1 });
				this.setMode("insert");
				return;
			}
			case "I":
				this.positionCursor({ line: cur.line, col: firstNonBlankCol(lines, cur.line) });
				this.setMode("insert");
				return;
			case "A":
				this.positionCursor({ line: cur.line, col: (lines[cur.line] ?? "").length });
				this.setMode("insert");
				return;
			case "o": {
				this.pushUndo();
				const next = [...lines];
				next.splice(cur.line + 1, 0, "");
				this.replaceBuffer(next.join("\n"), { line: cur.line + 1, col: 0 });
				this.setMode("insert");
				return;
			}
			case "O": {
				this.pushUndo();
				const next = [...lines];
				next.splice(cur.line, 0, "");
				this.replaceBuffer(next.join("\n"), { line: cur.line, col: 0 });
				this.setMode("insert");
				return;
			}
		}
	}

	private moveMotion(motion: MotionKey, count: number): void {
		const target = resolveMotion(this.getLines(), this.getCursorPos(), motion, count);
		this.positionCursor(target);
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
		const startLine = this.getCursor().line;
		const endExclusive = Math.min(lines.length, startLine + count);
		const removed = lines.slice(startLine, endExclusive);
		const linewiseText = removed.length
			? `${removed.join("\n")}${endExclusive < lines.length || removed.length > 0 ? "\n" : ""}`
			: "";
		if (linewiseText) this.writeClipboard(linewiseText);

		if (op === "yank") return;

		this.pushUndo();

		if (op === "delete") {
			if (lines.length === removed.length) {
				this.replaceBuffer("", { line: 0, col: 0 });
				return;
			}
			lines.splice(startLine, removed.length);
			const nextLine = Math.max(0, Math.min(startLine, lines.length - 1));
			this.replaceBuffer(lines.join("\n"), { line: nextLine, col: 0 });
			return;
		}

		// change: leave a single empty line in place and enter insert
		if (lines.length === removed.length) {
			this.replaceBuffer("", { line: 0, col: 0 });
		} else {
			lines.splice(startLine, removed.length, "");
			this.replaceBuffer(lines.join("\n"), { line: startLine, col: 0 });
		}
		this.setMode("insert");
	}

	private executeDeleteChar(count: number): void {
		const cur = this.getCursorPos();
		const lineText = this.getLines()[cur.line] ?? "";
		if (cur.col >= lineText.length) return;
		const end = Math.min(lineText.length, cur.col + count);
		const deleted = this.deleteRange({ start: cur, end: { line: cur.line, col: end } });
		if (deleted) this.writeClipboard(deleted);
	}

	private executePaste(after: boolean, count: number): void {
		const clip = this.readClipboard();
		if (!clip) return;

		const lines = [...this.getLines()];
		const cur = this.getCursorPos();
		const wantsLinePaste = clip.endsWith("\n");

		if (wantsLinePaste) {
			const base = clip.replace(/\n$/, "").split("\n");
			const toInsert: string[] = [];
			for (let i = 0; i < count; i++) toInsert.push(...base);

			this.pushUndo();
			const insertAt = cur.line + (after ? 1 : 0);
			lines.splice(insertAt, 0, ...toInsert);
			this.replaceBuffer(lines.join("\n"), { line: insertAt, col: 0 });
			return;
		}

		// charwise paste
		const lineText = lines[cur.line] ?? "";
		const insertCol = after ? Math.min(lineText.length, cur.col + (lineText.length > 0 ? 1 : 0)) : cur.col;
		const repeated = clip.repeat(count);
		const newLine = lineText.slice(0, insertCol) + repeated + lineText.slice(insertCol);

		this.pushUndo();
		lines[cur.line] = newLine;
		// In vim, after charwise paste the cursor lands on the last inserted char.
		const cursorCol = insertCol + repeated.length - 1;
		this.replaceBuffer(lines.join("\n"), { line: cur.line, col: Math.max(insertCol, cursorCol) });
	}

	private performUndo(): void {
		const snap = this.undoStack.pop();
		if (!snap) return;
		this.replaceBuffer(snap.text, snap.cursor);
	}

	private goToLineStart(): void {
		this.positionCursor({ line: this.getCursor().line, col: 0 });
	}

	private goToFirstLine(count: number): void {
		if (count > 1) {
			this.goToLine(count);
			return;
		}
		this.positionCursor({ line: 0, col: 0 });
	}

	private goToLastLine(count: number): void {
		if (count > 1) {
			this.goToLine(count);
			return;
		}
		const lines = this.getLines();
		const line = Math.max(0, lines.length - 1);
		this.positionCursor({ line, col: (lines[line] ?? "").length });
	}

	private goToLine(count: number): void {
		const lines = this.getLines();
		const line = Math.max(0, Math.min(lines.length - 1, count - 1));
		this.positionCursor({ line, col: 0 });
	}

	private createTransitionContext(): TransitionContext {
		return {
			moveMotion: (motion, count) => this.moveMotion(motion, count),
			executeOperatorMotion: (op, motion, count) => this.executeOperatorMotion(op, motion, count),
			executeLineOp: (op, count) => this.executeLineOp(op, count),
			executeDeleteChar: count => this.executeDeleteChar(count),
			executePaste: (after, count) => this.executePaste(after, count),
			goToFirstLine: count => this.goToFirstLine(count),
			goToLastLine: count => this.goToLastLine(count),
			goToLineStart: () => this.goToLineStart(),
			enterInsert: kind => this.enterInsert(kind),
			undo: () => this.performUndo(),
		};
	}

	// ----- input routing -------------------------------------------------------

	handleInput(data: string): void {
		if (matchesKey(data, "escape")) {
			if (this.vimState.mode === "insert") {
				this.setMode("normal");
			} else if (this.commandState.type !== "idle") {
				this.resetCommandState();
			} else {
				// Already in normal mode with no pending command: defer to the
				// CustomEditor's escape handling (interrupt, autocomplete dismiss, ...).
				super.handleInput(data);
			}
			return;
		}

		// Control characters (Ctrl+C, Ctrl+R, configured app shortcuts, etc.)
		// must always reach CustomEditor so app-level hotkeys keep working.
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

		// Unhandled single printable in normal mode: swallow so it doesn't leak
		// into the buffer. CSI / multi-byte sequences fall through to super.
		if (data.length === 1 && data.charCodeAt(0) >= 32) return;
		super.handleInput(data);
	}

	// ----- render ---------------------------------------------------------------

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

		// Strip the editor's inverse-video cursor block so the terminal block
		// cursor is the only thing the user sees in normal mode.
		for (let i = 0; i < lines.length; i++) {
			lines[i] = lines[i]!
				.replace(`${CURSOR_MARKER}\x1b[7m \x1b[0m`, CURSOR_MARKER)
				.replace(new RegExp(`${CURSOR_MARKER}\\x1b\\[7m([\\s\\S])\\x1b\\[0m`, "g"), `${CURSOR_MARKER}$1`);
		}

		const label = `${this.vimState.mode === "normal" ? " NORMAL" : " INSERT"}${this.commandSuffix()} `;
		const last = lines.length - 1;
		if (visibleWidth(lines[last]!) >= label.length) {
			lines[last] = truncateToWidth(lines[last]!, width - label.length) + label;
		}
		return lines;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setEditorComponent((_tui, theme, _kb) => {
			const editor = new ModalEditor(theme);
			editor.syncCursorShape();
			return editor;
		});
	});
}
