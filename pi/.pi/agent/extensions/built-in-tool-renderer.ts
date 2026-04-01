/**
 * Compact renderer overrides for search-style built-in tools.
 *
 * Keeps the default UI for mutating tools like edit/write, while compacting
 * tools that often dump a lot of text: read, grep, find, and ls.
 */

import type {
  ExtensionAPI,
  FindToolDetails,
  GrepToolDetails,
  LsToolDetails,
  ReadToolDetails,
} from "@mariozechner/pi-coding-agent";
import {
  createFindTool,
  createGrepTool,
  createLsTool,
  createReadTool,
} from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

function countNonEmptyLines(text: string) {
  return text.split("\n").filter((line) => line.trim().length > 0).length;
}

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();

  // --- Read tool: show path and line count ---
  const originalRead = createReadTool(cwd);
  pi.registerTool({
    name: "read",
    label: "read",
    description: originalRead.description,
    parameters: originalRead.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalRead.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      let text = theme.fg("toolTitle", theme.bold("read "));
      text += theme.fg("accent", args.path);
      if (args.offset || args.limit) {
        const parts: string[] = [];
        if (args.offset) parts.push(`offset=${args.offset}`);
        if (args.limit) parts.push(`limit=${args.limit}`);
        text += theme.fg("dim", ` (${parts.join(", ")})`);
      }
      return new Text(text, 0, 0);
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

  // --- Grep tool: compact match count ---
  const originalGrep = createGrepTool(cwd);
  pi.registerTool({
    name: "grep",
    label: "grep",
    description: originalGrep.description,
    parameters: originalGrep.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalGrep.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      let text = theme.fg("toolTitle", theme.bold("grep "));
      text += theme.fg("accent", args.pattern);
      if (args.path) {
        text += theme.fg("dim", ` in ${args.path}`);
      }
      if (args.glob) {
        text += theme.fg("dim", ` (${args.glob})`);
      }
      return new Text(text, 0, 0);
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

  // --- Find tool: compact result count ---
  const originalFind = createFindTool(cwd);
  pi.registerTool({
    name: "find",
    label: "find",
    description: originalFind.description,
    parameters: originalFind.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalFind.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      let text = theme.fg("toolTitle", theme.bold("find "));
      text += theme.fg("accent", args.pattern);
      if (args.path) {
        text += theme.fg("dim", ` in ${args.path}`);
      }
      return new Text(text, 0, 0);
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

  // --- Ls tool: compact entry count ---
  const originalLs = createLsTool(cwd);
  pi.registerTool({
    name: "ls",
    label: "ls",
    description: originalLs.description,
    parameters: originalLs.parameters,

    async execute(toolCallId, params, signal, onUpdate) {
      return originalLs.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      let text = theme.fg("toolTitle", theme.bold("ls "));
      text += theme.fg("accent", args.path);
      if (args.limit) {
        text += theme.fg("dim", ` (limit=${args.limit})`);
      }
      return new Text(text, 0, 0);
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
}
