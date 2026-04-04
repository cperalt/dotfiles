/**
 * Minimal renderer overrides for built-in tools.
 *
 * Goals:
 * - Claude Code-like compact tool headers
 * - Single status dot that changes with tool state
 * - Keep built-in execution behavior
 * - Keep built-in result renderers unless we intentionally compact them
 */

import type {
  BashToolDetails,
  EditToolDetails,
  ExtensionAPI,
  FindToolDetails,
  GrepToolDetails,
  LsToolDetails,
  ReadToolDetails,
} from "@mariozechner/pi-coding-agent";
import {
  createBashTool,
  createEditTool,
  createFindTool,
  createGrepTool,
  createLsTool,
  createReadTool,
  createWriteTool,
} from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

function countNonEmptyLines(text: string) {
  return text.split("\n").filter((line) => line.trim().length > 0).length;
}

function truncate(text: string, max = 80) {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function firstNonEmptyLine(text: string) {
  return text
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.length > 0);
}

function dot(theme: any, context: any) {
  if (!context.executionStarted || context.isPartial) {
    return theme.fg("text", "⏺");
  }
  return context.isError ? theme.fg("error", "⏺") : theme.fg("success", "⏺");
}

function renderHeader(theme: any, context: any, label: string, detail: string) {
  let text = `${dot(theme, context)} `;
  text += theme.fg("toolTitle", label);
  if (detail) {
    text += theme.fg("muted", `(${detail})`);
  }
  return new Text(text, 0, 0);
}

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();

  const originalRead = createReadTool(cwd);
  pi.registerTool({
    name: "read",
    label: "read",
    description: originalRead.description,
    parameters: originalRead.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalRead.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      const parts = [args.path];
      if (args.offset) parts.push(`offset=${args.offset}`);
      if (args.limit) parts.push(`limit=${args.limit}`);
      return renderHeader(theme, context, "Read", parts.join(", "));
    },

    renderResult(result, { expanded, isPartial }, theme, _context) {
      if (isPartial) return new Text(theme.fg("warning", "Reading..."), 0, 0);

      const details = result.details as ReadToolDetails | undefined;
      const content = result.content[0];

      if (content?.type === "image") {
        return new Text(theme.fg("success", "Image loaded"), 0, 0);
      }

      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No content"), 0, 0);
      }

      const lineCount = content.text.split("\n").length;
      let text = theme.fg("success", `${lineCount} lines`);

      if (details?.truncation?.truncated) {
        text += theme.fg(
          "warning",
          ` (truncated from ${details.truncation.totalLines})`,
        );
      }

      if (expanded) {
        const lines = content.text.split("\n").slice(0, 15);
        for (const line of lines) {
          text += `\n${theme.fg("dim", line)}`;
        }
        if (lineCount > 15) {
          text += `\n${theme.fg("muted", `... ${lineCount - 15} more lines`)}`;
        }
      }

      return new Text(text, 0, 0);
    },
  });

  const originalGrep = createGrepTool(cwd);
  pi.registerTool({
    name: "grep",
    label: "grep",
    description: originalGrep.description,
    parameters: originalGrep.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalGrep.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      const parts = [args.pattern];
      if (args.path) parts.push(`in ${args.path}`);
      if (args.glob) parts.push(args.glob);
      return renderHeader(theme, context, "Grep", parts.join(", "));
    },

    renderResult(result, { expanded, isPartial }, theme, _context) {
      if (isPartial) return new Text(theme.fg("warning", "Searching..."), 0, 0);

      const details = result.details as GrepToolDetails | undefined;
      const content = result.content[0];
      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No matches"), 0, 0);
      }

      const matchCount = countNonEmptyLines(content.text);
      let text = theme.fg("success", `${matchCount} matches`);
      if (details?.truncation?.truncated) {
        text += theme.fg("warning", " [truncated]");
      }

      if (expanded) {
        const lines = content.text.split("\n").slice(0, 20);
        for (const line of lines) {
          text += `\n${theme.fg("dim", line)}`;
        }
        if (countNonEmptyLines(content.text) > 20) {
          text += `\n${theme.fg("muted", "... more matches")}`;
        }
      }

      return new Text(text, 0, 0);
    },
  });

  const originalFind = createFindTool(cwd);
  pi.registerTool({
    name: "find",
    label: "find",
    description: originalFind.description,
    parameters: originalFind.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalFind.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      const parts = [args.pattern];
      if (args.path) parts.push(`in ${args.path}`);
      return renderHeader(theme, context, "Find", parts.join(", "));
    },

    renderResult(result, { expanded, isPartial }, theme, _context) {
      if (isPartial) return new Text(theme.fg("warning", "Finding..."), 0, 0);

      const details = result.details as FindToolDetails | undefined;
      const content = result.content[0];
      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No results"), 0, 0);
      }

      const fileCount = countNonEmptyLines(content.text);
      let text = theme.fg("success", `${fileCount} files`);
      if (details?.truncation?.truncated) {
        text += theme.fg("warning", " [truncated]");
      }

      if (expanded) {
        const lines = content.text.split("\n").slice(0, 20);
        for (const line of lines) {
          text += `\n${theme.fg("dim", line)}`;
        }
        if (countNonEmptyLines(content.text) > 20) {
          text += `\n${theme.fg("muted", "... more files")}`;
        }
      }

      return new Text(text, 0, 0);
    },
  });

  const originalLs = createLsTool(cwd);
  pi.registerTool({
    name: "ls",
    label: "ls",
    description: originalLs.description,
    parameters: originalLs.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalLs.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      const parts = [args.path ?? "."];
      if (args.limit) parts.push(`limit=${args.limit}`);
      return renderHeader(theme, context, "Ls", parts.join(", "));
    },

    renderResult(result, { expanded, isPartial }, theme, _context) {
      if (isPartial) return new Text(theme.fg("warning", "Listing..."), 0, 0);

      const details = result.details as LsToolDetails | undefined;
      const content = result.content[0];
      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No entries"), 0, 0);
      }

      const entryCount = countNonEmptyLines(content.text);
      let text = theme.fg("success", `${entryCount} entries`);
      if (details?.truncation?.truncated) {
        text += theme.fg("warning", " [truncated]");
      }

      if (expanded) {
        const lines = content.text.split("\n").slice(0, 20);
        for (const line of lines) {
          text += `\n${theme.fg("dim", line)}`;
        }
        if (countNonEmptyLines(content.text) > 20) {
          text += `\n${theme.fg("muted", "... more entries")}`;
        }
      }

      return new Text(text, 0, 0);
    },
  });

  const originalBash = createBashTool(cwd);
  pi.registerTool({
    name: "bash",
    label: "bash",
    description: originalBash.description,
    parameters: originalBash.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalBash.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      return renderHeader(theme, context, "Bash", truncate(args.command, 88));
    },

    renderResult(result, _options, theme, _context) {
      const content = result.content[0];
      const details = result.details as BashToolDetails | undefined;
      if (content?.type !== "text") return new Text("", 0, 0);

      const lineCount = countNonEmptyLines(content.text);
      let text = theme.fg("success", `${lineCount} lines`);
      if (details?.truncation?.truncated) {
        text += theme.fg("warning", " [truncated]");
      }

      const preview = firstNonEmptyLine(content.text);
      if (preview) {
        text += `\n${theme.fg("dim", truncate(preview, 120))}`;
      }

      return new Text(text, 0, 0);
    },
  });

  const originalEdit = createEditTool(cwd);
  pi.registerTool({
    name: "edit",
    label: "edit",
    description: originalEdit.description,
    parameters: originalEdit.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalEdit.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      const count = args.edits?.length ?? 0;
      return renderHeader(theme, context, "Edit", `${args.path}, ${count} change${count === 1 ? "" : "s"}`);
    },

    renderResult(result, _options, theme, _context) {
      const details = result.details as EditToolDetails | undefined;
      if (!details?.diff) {
        return new Text(theme.fg("success", "Applied"), 0, 0);
      }

      const added = details.diff.split("\n").filter((line) => line.startsWith("+") && !line.startsWith("+++"))
        .length;
      const removed = details.diff
        .split("\n")
        .filter((line) => line.startsWith("-") && !line.startsWith("---")).length;

      let text = theme.fg("success", "Applied");
      text += theme.fg("muted", ` (+${added} -${removed})`);
      return new Text(text, 0, 0);
    },
  });

  const originalWrite = createWriteTool(cwd);
  pi.registerTool({
    name: "write",
    label: "write",
    description: originalWrite.description,
    parameters: originalWrite.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalWrite.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, context) {
      const lines = args.content.split("\n").length;
      return renderHeader(theme, context, "Write", `${args.path}, ${lines} lines`);
    },
  });
}
