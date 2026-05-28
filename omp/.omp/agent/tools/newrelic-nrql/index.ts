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

const NRQL_PREFIX = /^\s*(SELECT|FROM|WITH)\b/i;

const factory: CustomToolFactory = (pi) => ({
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

		const result = await pi.exec("newrelic", args, { signal });

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
				details: { exitCode, stderr },
			};
		}

		return {
			content: [{ type: "text", text: stdout || "(empty result)" }],
			details: {
				query,
				accountId: accountId ?? null,
				format: format ?? "JSON",
			},
		};
	},
});

export default factory;
