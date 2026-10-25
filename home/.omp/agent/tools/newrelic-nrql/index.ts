/**
 * newrelic-nrql — read-only NRQL query tool.
 *
 * Guardrails:
 *  - Only the `newrelic nrql query` subcommand is ever invoked.
 *  - Arguments are passed as separate argv to pi.exec (no shell, no interpolation).
 *  - The NRQL string MUST start with SELECT, FROM, or WITH (case-insensitive).
 *    NRQL has no mutation verbs by design, but this rejects accidental misuse
 *    of the field for unrelated CLI flags.
 *  - accountId, when provided, must be a positive integer.
 */
import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";

/** Written by execute(), read by renderResult(); `wallTimeMs` is the bash renderer's footer field. */
interface NrqlRenderDetails {
	query?: string;
	accountId?: number | null;
	format?: string;
	wallTimeMs?: number;
}

const NRQL_PREFIX = /^\s*(SELECT|FROM|WITH)\b/i;

/** The CLI line shown above the query in the TUI. */
function nrqlCommand(accountId: number | null | undefined, format: string | undefined): string {
	const parts = ["newrelic nrql query"];
	if (accountId) parts.push(`--accountId ${accountId}`);
	if (format && format !== "JSON") parts.push(`--format ${format}`);
	return parts.join(" ");
}

interface ShellRenderer {
	renderCall(args: { command: string }, options: unknown, theme: unknown): unknown;
	renderResult(result: unknown, options: unknown, theme: unknown, args: { command: string }): unknown;
}

const factory: CustomToolFactory = (pi) => {
	// `createShellRenderer` is not exported by every omp build; without it we fall back to default rendering.
	const create: unknown = "createShellRenderer" in pi.pi ? pi.pi.createShellRenderer : undefined;
	const shell =
		typeof create === "function"
			? (create({ resolveTitle: () => "New Relic NRQL", resolveCommand: (args: { command?: string } | undefined) => args?.command }) as ShellRenderer)
			: undefined;
	return {
	name: "newrelic_nrql",
	label: "New Relic NRQL",
	description:
		"Run a read-only New Relic NRQL query via the `newrelic` CLI. " +
		"Only NRQL `SELECT` / `FROM` / `WITH` queries are accepted; no other " +
		"newrelic subcommands are reachable through this tool. Output is JSON " +
		"unless `format` is set. Uses the default CLI profile and its account " +
		"unless `accountId` is provided.",
	parameters: pi.zod.object({
		query: pi.zod
			.string()
			.min(1)
			.describe(
				"NRQL query string. Must begin with SELECT, FROM, or WITH. " +
					"Example: SELECT count(*) FROM Transaction SINCE 1 hour ago",
			),
		accountId: pi.zod
			.number()
			.int()
			.positive()
			.optional()
			.describe(
				"Optional New Relic account ID. Defaults to the CLI's default profile account.",
			),
		format: pi.zod
			.enum(["JSON", "Text", "YAML"])
			.optional()
			.describe("Output format (default JSON)."),
	}),

	async execute(_toolCallId, params, _onUpdate, _ctx, signal) {
		const { query, accountId, format } = params;

		if (!NRQL_PREFIX.test(query)) {
			return {
				content: [
					{
						type: "text",
						text:
							"Refused: NRQL query must start with SELECT, FROM, or WITH. " +
							"This tool only runs read-only NRQL queries.",
					},
				],
				isError: true,
			};
		}

		const args: string[] = ["nrql", "query", "--query", query];
		if (accountId !== undefined) {
			args.push("--accountId", String(accountId));
		}
		if (format) {
			args.push("--format", format);
		}

		const startedAt = performance.now();
		const result = await pi.exec("newrelic", args, { signal });
		const wallTimeMs = performance.now() - startedAt;

		const stdout = result.stdout?.trim() ?? "";
		const stderr = result.stderr?.trim() ?? "";
		const exitCode = result.code ?? 0;

		if (exitCode !== 0) {
			return {
				content: [
					{
						type: "text",
						text:
							`newrelic exited with code ${exitCode}\n` +
							(stderr ? `stderr:\n${stderr}\n` : "") +
							(stdout ? `stdout:\n${stdout}` : ""),
					},
				],
				isError: true,
				details: { exitCode, stderr, query, accountId: accountId ?? null, format: format ?? "JSON", wallTimeMs },
			};
		}

		return {
			content: [{ type: "text", text: stdout || "(empty result)" }],
			details: {
				query,
				accountId: accountId ?? null,
				format: format ?? "JSON",
				wallTimeMs,
			},
		};
	},

	...(shell && {
		renderCall(args: unknown, options: unknown, theme: unknown) {
			const { query, accountId, format } = args as { query: string; accountId?: number; format?: string };
			return shell.renderCall({ command: `${nrqlCommand(accountId, format)}\n${query}` }, options, theme);
		},
		renderResult(result: { details?: unknown }, options: unknown, theme: unknown) {
			const d = (result.details ?? {}) as NrqlRenderDetails;
			return shell.renderResult(result, options, theme, {
				command: `${nrqlCommand(d.accountId, d.format)}\n${d.query ?? ""}`,
			});
		},
	}),
	};
};

export default factory;
