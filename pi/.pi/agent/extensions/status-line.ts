/**
 * Custom Status Footer
 *
 * Replaces the default footer with a Claude Code–style status line.
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { basename } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          let totalCost = 0;
          for (const entry of ctx.sessionManager.getBranch()) {
            if (entry.type === "message" && entry.message.role === "assistant") {
              const message = entry.message as AssistantMessage;
              totalCost += message.usage.cost.total;
            }
          }

          const contextUsage = ctx.getContextUsage();
          const contextPct = contextUsage?.percent ?? (contextUsage as { percentage?: number } | undefined)?.percentage ?? null;
          const thinking = pi.getThinkingLevel();
          const branch = footerData.getGitBranch() ?? "no-branch";
          const model = ctx.model?.id ?? "no-model";
          const cwd = basename(ctx.cwd);
          const statuses = Array.from(footerData.getExtensionStatuses().values()).join(" ");
          const sessionName = pi.getSessionName();

          const branchPart = theme.fg("accent", branch);
          const cwdPart = theme.fg("dim", cwd);
          const thinkingPart = theme.fg("muted", thinking);
          const modelPart = theme.fg("accent", model);
          const sessionPart = sessionName ? theme.fg("accent", sessionName) : "";

          const contextColor =
            contextPct === null
              ? "dim"
              : contextPct >= 90
                ? "error"
                : contextPct >= 70
                  ? "warning"
                  : "success";
          const contextPart = theme.fg(
            contextColor,
            contextPct === null ? "--%" : `${Math.round(contextPct)}%`,
          );
          const costPart = theme.fg("warning", `$${totalCost.toFixed(2)}`);

          const leftParts: string[] = [];
          if (sessionPart) leftParts.push(sessionPart);
          if (statuses !== "") leftParts.push(statuses);
          const left = leftParts.join(theme.fg("dim", " | "));
          const right = [
            branchPart,
            thinkingPart,
            modelPart,
            contextPart,
            costPart,
          ].join(theme.fg("dim", " | "));

          const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
          return [truncateToWidth(left + pad + right, width)];
        },
      };
    });
  });

}
