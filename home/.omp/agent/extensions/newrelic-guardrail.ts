/**
 * newrelic-guardrail — block direct `newrelic` CLI invocations from the bash tool.
 *
 * Rationale: the `newrelic_nrql` custom tool is the only sanctioned path to the
 * New Relic CLI (read-only NRQL only). Letting the model shell out to
 * `newrelic <subcommand>` bypasses that and exposes the full CLI surface
 * (profile management, install/uninstall, APM mutations, etc.).
 *
 * Scope: model-initiated bash tool calls only. User-typed `!newrelic …` shell
 * commands are not affected.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

// Matches `newrelic` only in *command position*: at start of line, after a
// shell statement separator (`;`, `&&`, `||`, `|`, `&`), inside command
// substitution (`` ` `` or `$(`), or after a subshell `(`. Each anchor allows
// optional whitespace before the token. Trailing `\b` rejects `newrelic-foo`.
// Note: this intentionally does NOT match `newrelic` appearing as an argument
// (e.g. `echo "newrelic"`, `grep newrelic file`). Edge cases like
// `sudo newrelic …` or `env X=1 newrelic …` slip through; that's an acceptable
// tradeoff for zero false positives on string/argument mentions.
const NEWRELIC_CMD = /(?:^|[;&|`(]|&&|\|\|)\s*newrelic\b/;

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (event.toolName !== "bash") return;
		const command =
			typeof (event.input as { command?: unknown })?.command === "string"
				? ((event.input as { command: string }).command)
				: "";
		if (!command) return;
		if (!NEWRELIC_CMD.test(command)) return;
		return {
			block: true,
			reason:
				"Direct `newrelic` CLI invocations are disabled. Use the " +
				"`newrelic_nrql` tool for read-only NRQL queries. The base CLI " +
				"exposes mutating subcommands (profiles, install, APM admin) and " +
				"is intentionally out of scope for the agent.",
		};
	});
}
