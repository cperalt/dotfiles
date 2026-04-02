/**
 * Prefer CLAUDE.md Extension
 *
 * Pi's built-in context file loader checks AGENTS.md before CLAUDE.md in each
 * directory and stops at the first match. This means if both files exist in the
 * same directory, CLAUDE.md is silently skipped.
 *
 * This extension compensates: it walks the same directory tree pi walks, finds
 * every directory that has BOTH files (where pi would have ignored CLAUDE.md),
 * reads those CLAUDE.md files, and injects their content into the system prompt
 * via before_agent_start so the LLM always sees them.
 *
 * Placement: ~/.pi/agent/extensions/ (global, applies to all projects)
 */

import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface SkippedClaudeMd {
	filePath: string;
	content: string;
}

export default function preferClaudeMd(pi: ExtensionAPI) {
	let skippedFiles: SkippedClaudeMd[] = [];

	pi.on("session_start", async (_event, ctx) => {
		skippedFiles = findSkippedClaudeMdFiles(ctx.cwd);

		if (skippedFiles.length > 0) {
			const paths = skippedFiles.map((f) => f.filePath).join(", ");
			ctx.ui.notify(`prefer-claude-md: injecting ${skippedFiles.length} skipped CLAUDE.md file(s): ${paths}`, "info");
		}
	});

	pi.on("before_agent_start", async (event) => {
		if (skippedFiles.length === 0) {
			return;
		}

		const injected = skippedFiles
			.map((f) => `<!-- Injected from ${f.filePath} (preferred over AGENTS.md) -->\n${f.content}`)
			.join("\n\n---\n\n");

		return {
			systemPrompt: event.systemPrompt + `\n\n${injected}`,
		};
	});
}

/**
 * Walk the same directory tree pi walks (global agent dir + cwd up to root).
 * For each directory that contains BOTH AGENTS.md and CLAUDE.md, collect the
 * CLAUDE.md — because pi would have loaded AGENTS.md and skipped CLAUDE.md.
 */
function findSkippedClaudeMdFiles(cwd: string): SkippedClaudeMd[] {
	const results: SkippedClaudeMd[] = [];
	const seenDirs = new Set<string>();

	// Check global agent dir (~/.pi/agent/)
	const globalAgentDir = path.join(os.homedir(), ".pi", "agent");
	checkDir(globalAgentDir, results, seenDirs);

	// Walk from cwd up to root, collecting ancestor dirs (same order as pi)
	const ancestorDirs: string[] = [];
	let current = path.resolve(cwd);
	const root = path.resolve("/");

	while (true) {
		ancestorDirs.unshift(current);
		if (current === root) break;
		const parent = path.resolve(current, "..");
		if (parent === current) break;
		current = parent;
	}

	for (const dir of ancestorDirs) {
		checkDir(dir, results, seenDirs);
	}

	return results;
}

function checkDir(dir: string, results: SkippedClaudeMd[], seenDirs: Set<string>): void {
	const resolved = path.resolve(dir);
	if (seenDirs.has(resolved)) return;
	seenDirs.add(resolved);

	if (!fs.existsSync(resolved)) return;

	const agentsMd = path.join(resolved, "AGENTS.md");
	const claudeMd = path.join(resolved, "CLAUDE.md");

	// Only act when BOTH exist — that's the case pi gets wrong for our needs.
	// If only CLAUDE.md exists, pi already loads it correctly; no need to inject.
	if (fs.existsSync(agentsMd) && fs.existsSync(claudeMd)) {
		try {
			const content = fs.readFileSync(claudeMd, "utf-8").trim();
			if (content) {
				results.push({ filePath: claudeMd, content });
			}
		} catch (err) {
			// Silently skip unreadable files
		}
	}
}
