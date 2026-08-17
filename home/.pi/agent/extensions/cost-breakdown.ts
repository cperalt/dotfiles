/**
 * /cost command — shows session cost breakdown by model.
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("cost", {
    description: "Show session cost breakdown by model",
    handler: async (_args, ctx) => {
      type Stats = { cost: number; turns: number; tokens: number; provider: string };
      const costByModel = new Map<string, Stats>();
      let totalCost = 0;

      for (const entry of ctx.sessionManager.getBranch()) {
        if (entry.type === "message" && entry.message.role === "assistant") {
          const message = entry.message as AssistantMessage;
          const model = message.model ?? "unknown";
          const provider = message.provider ?? "";
          const cost = message.usage.cost.total;
          const tokens = message.usage.totalTokens;
          totalCost += cost;

          const existing = costByModel.get(model) ?? { cost: 0, turns: 0, tokens: 0, provider };
          existing.cost += cost;
          existing.turns += 1;
          existing.tokens += tokens;
          costByModel.set(model, existing);
        }
      }

      if (costByModel.size === 0) {
        ctx.ui.notify("No model usage in this session yet.", "info");
        return;
      }

      const usage = ctx.getContextUsage();
      const currentTokens = usage?.tokens ?? null;

      const sorted = [...costByModel.entries()].sort((a, b) => b[1].cost - a[1].cost);

      const lines: string[] = ["Session Cost Breakdown", ""];
      for (const [modelId, { cost, turns, tokens, provider }] of sorted) {
        const costPct = totalCost > 0 ? ((cost / totalCost) * 100).toFixed(0) : "0";
        const tokK = (tokens / 1000).toFixed(1);
        const rate = tokens > 0 ? ((cost / tokens) * 1000).toFixed(4) : "n/a";

        let ctxPart = "";
        if (currentTokens !== null) {
          const model = provider ? ctx.modelRegistry.find(provider, modelId) : undefined;
          const window = model?.contextWindow;
          if (window && window > 0) {
            const ctxPct = Math.round((currentTokens / window) * 100);
            const curK = (currentTokens / 1000).toFixed(1);
            const winK = Math.round(window / 1000);
            ctxPart = `  ctx ${ctxPct}% (${curK}k/${winK}k)`;
          } else {
            ctxPart = `  ctx n/a`;
          }
        }

        lines.push(`  ${modelId}  $${cost.toFixed(4)}  ${turns} turns  ${costPct}%  ${tokK}k tok  $${rate}/1k${ctxPart}`);
      }
      lines.push("");
      lines.push(`  Total: $${totalCost.toFixed(4)}`);

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });
}
