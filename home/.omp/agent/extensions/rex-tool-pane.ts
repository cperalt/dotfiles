/**
 * rex-tool-pane — mirror custom data-source tool calls into a Rex pane.
 *
 * When omp runs inside Rex (REX_SESSION / REX_BLOCK set), the first call to one
 * of the tools below opens a pane to the right of the omp block running
 * `tail -f` on a per-session log. Each call appends the query or command
 * verbatim (so it can be copied and run by hand) followed by the result, so
 * the harness pane can stay on the conversation with tool cards hidden
 * (Ctrl+Shift+O) while the data work is visible on the side.
 *
 * Tools: pg_query, databricks_sql, databricks, aws, newrelic_nrql,
 * rollbar_search. Everything else is ignored. The `xd://` wrapper fires the
 * inner tool's own `tool_call` / `tool_result` with parsed input, so no JSON
 * unwrapping is needed here.
 *
 * Log files live in ~/.omp/tool-log/<session-id>.log. The pane is closed on
 * session shutdown; the log is kept.
 */
import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const LOG_DIR = join(homedir(), ".omp", "tool-log");
const RESULT_CAP = 4000;
const WATCHED: Record<string, true> = {
	pg_query: true,
	databricks_sql: true,
	databricks: true,
	aws: true,
	newrelic_nrql: true,
	rollbar_search: true,
};

/** The copy-pasteable form of a call: the statement, the command line, or the args. */
function commandOf(toolName: string, input: Record<string, unknown>): string {
	const { statement, query, command, profile, env, accountId } = input as Record<string, unknown>;
	switch (toolName) {
		case "pg_query":
			return `-- pg_query env=${env}\n${String(statement ?? "").trim()}`;
		case "databricks_sql":
			return `-- databricks_sql${input.catalog ? ` catalog=${input.catalog}` : ""}${input.schema ? ` schema=${input.schema}` : ""}\n${String(statement ?? "").trim()}`;
		case "newrelic_nrql":
			return `-- newrelic_nrql${accountId ? ` account=${accountId}` : ""}\n${String(query ?? "").trim()}`;
		case "aws":
			return `aws ${(Array.isArray(command) ? command : []).join(" ")} --profile ${profile}`;
		case "databricks":
			return `databricks ${(Array.isArray(command) ? command : []).join(" ")} --profile ${profile}${input.output ? ` -o ${input.output}` : ""}`;
		case "rollbar_search": {
			const parts = Object.entries(input)
				.filter(([, v]) => v !== undefined)
				.map(([k, v]) => `${k}=${JSON.stringify(v)}`);
			return `rollbar_search ${parts.join(" ")}`;
		}
		default:
			return JSON.stringify(input, null, 2);
	}
}

function stamp(): string {
	return new Date().toTimeString().slice(0, 8);
}

export default function (pi: ExtensionAPI) {
	const rexSession = process.env.REX_SESSION;
	const rexBlock = process.env.REX_BLOCK;
	if (!rexSession || !rexBlock) return;

	let logPath: string | undefined;
	let paneId: string | undefined;
	let opening: Promise<void> | undefined;
	const started = new Map<string, number>();

	async function ensurePane(notify: (message: string, type: "warning") => void): Promise<void> {
		if (paneId || !logPath) return;
		opening ??= (async () => {
			const result = await pi.exec("rex", [
				"split",
				"-s",
				rexSession!,
				"-b",
				rexBlock!,
				"--split=right",
				"--ratio",
				"40",
				"--label",
				"Tool calls",
				"--focus=false",
				"--keep-open",
				"--json",
				"--",
				"tail",
				"-n",
				"+1",
				"-f",
				logPath!,
			]);
			if (result.code !== 0) throw new Error(result.stderr || `rex split exited ${result.code}`);
			const parsed: unknown = JSON.parse(result.stdout);
			const ids =
				parsed && typeof parsed === "object" && "block_ids" in parsed && Array.isArray(parsed.block_ids)
					? parsed.block_ids
					: [];
			paneId = typeof ids[0] === "string" ? ids[0] : undefined;
		})().catch((err) => {
			opening = undefined;
			notify(`rex-tool-pane: ${err instanceof Error ? err.message : String(err)}`, "warning");
		});
		await opening;
	}

	pi.on("session_start", async (_event, ctx) => {
		mkdirSync(LOG_DIR, { recursive: true });
		logPath = join(LOG_DIR, `${ctx.sessionManager.getSessionId()}.log`);
		paneId = undefined;
		opening = undefined;
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!WATCHED[event.toolName] || !logPath) return;
		await ensurePane(ctx.ui.notify);
		started.set(event.toolCallId, performance.now());
		const input = event.input as unknown as Record<string, unknown>;
		appendFileSync(logPath, `\n━━ ${stamp()} ${event.toolName}\n${commandOf(event.toolName, input)}\n`);
	});

	pi.on("tool_result", async (event) => {
		if (!WATCHED[event.toolName] || !logPath) return;
		const t0 = started.get(event.toolCallId);
		started.delete(event.toolCallId);
		const ms = t0 === undefined ? "" : ` ${Math.round(performance.now() - t0)}ms`;
		const text = event.content
			.map((c) => (c.type === "text" ? c.text : `[${c.type}]`))
			.join("\n")
			.trimEnd();
		const body = text.length > RESULT_CAP ? `${text.slice(0, RESULT_CAP)}\n… (${text.length - RESULT_CAP} more chars)` : text;
		appendFileSync(logPath, `── ${event.isError ? "ERROR" : "ok"}${ms}\n${body}\n`);
	});

	pi.on("session_shutdown", async () => {
		if (!paneId) return;
		await pi.exec("rex", ["block", "close", "-s", rexSession, paneId]).catch(() => undefined);
		paneId = undefined;
	});
}
