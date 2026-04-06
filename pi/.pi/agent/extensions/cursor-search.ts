import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { resolve } from "node:path";

function normalizeWorkspace(workspace: string | undefined, cwd: string): string {
  const raw = (workspace ?? ".").trim();
  const withoutAt = raw.startsWith("@") ? raw.slice(1) : raw;
  return resolve(cwd, withoutAt || ".");
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "semantic_search",
    label: "Semantic Search",
    description:
      "Semantic search over the current codebase using Cursor's composer-2 index via cursor-agent.",
    promptSnippet:
      "Use semantic_search for broad natural-language codebase questions before exact file verification.",
    promptGuidelines: [
      "Use semantic_search first for broad, exploratory, or concept-level codebase questions when you do not yet know the exact file or symbol.",
      "After semantic_search returns, verify concrete claims by reading files or using grep for exact symbols, imports, or call sites.",
      "Do not use semantic_search for trivial exact-string lookups when grep/read is clearly sufficient.",
    ],
    parameters: Type.Object({
      query: Type.String({
        description: "Natural-language question about the codebase",
      }),
      workspace: Type.Optional(
        Type.String({
          description:
            'Workspace root to search. Defaults to the current project cwd. Leading "@" is allowed.',
        }),
      ),
    }),

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const workspace = normalizeWorkspace(params.workspace, ctx.cwd);
      const prompt = [
        "You are a codebase search tool. Your job is to find where things live in the codebase.",
        "For every query, return file paths with line numbers when possible, key function/class/type names, and a one-line description of each file's role.",
        "Be concise. Do not deeply explain how the code works; focus on mapping where relevant code lives.",
        "Prefer breadth over depth. Surface all relevant files instead of over-analyzing only one.",
        "Group results by layer when helpful (services, handlers, models, UI, utils, config).",
        "",
        `Query: ${params.query}`,
      ].join("\n");

      const result = await pi.exec(
        "cursor-agent",
        [
          "--print",
          "--model",
          "composer-2-fast",
          "--trust",
          "--workspace",
          workspace,
          prompt,
        ],
        { signal, timeout: 90_000 },
      );

      if (result.killed) {
        return {
          content: [{ type: "text", text: "semantic_search was cancelled." }],
          details: { workspace, cancelled: true },
          isError: true,
        };
      }

      if (result.code !== 0) {
        return {
          content: [
            {
              type: "text",
              text:
                `cursor-agent exited ${result.code}.` +
                (result.stderr ? `\n\n${result.stderr}` : result.stdout ? `\n\n${result.stdout}` : ""),
            },
          ],
          details: { workspace, exitCode: result.code },
          isError: true,
        };
      }

      const output = result.stdout?.trim() || result.stderr?.trim() || "(no output)";
      return {
        content: [{ type: "text", text: output }],
        details: { workspace, model: "composer-2-fast" },
      };
    },
  });
}
