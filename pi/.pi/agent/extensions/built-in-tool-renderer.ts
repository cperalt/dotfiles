/**
 * Minimal renderer overrides for built-in tools.
 *
 * Goals:
 * - Claude Code-like compact tool headers
 * - Single status dot that changes with tool state
 * - Move result counts into the header line
 * - Keep built-in execution behavior
 */

import type {
  BashToolDetails,
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
import { Container, Text } from "@mariozechner/pi-tui";

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

function renderHeaderText(
  theme: any,
  context: any,
  label: string,
  detail: string,
  summary?: string,
) {
  let text = `${dot(theme, context)} `;
  text += theme.fg("toolTitle", label);
  if (detail) {
    text += theme.fg("muted", `(${detail})`);
  }
  if (summary) {
    text += theme.fg("dim", ` · ${summary}`);
  }
  return text;
}

function renderHeader(theme: any, context: any, label: string, detail: string, summary?: string) {
  let header = context.state?.header as Text | undefined;
  if (!header) {
    header = new Text("", 0, 0);
    context.state.header = header;
  }
  header.setText(renderHeaderText(theme, context, label, detail, summary));
  return header;
}

function updateHeader(theme: any, context: any, label: string, detail: string, summary?: string) {
  const header = context.state?.header as Text | undefined;
  if (header) {
    header.setText(renderHeaderText(theme, context, label, detail, summary));
  }
}

function emptyResult() {
  return new Container();
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
      context.state.detail = parts.join(", ");
      return renderHeader(theme, context, "Read", context.state.detail, context.state.summary);
    },

    renderResult(result, { expanded, isPartial }, theme, context) {
      if (isPartial) return new Text(theme.fg("warning", "Reading..."), 0, 0);

      const details = result.details as ReadToolDetails | undefined;
      const content = result.content[0];

      if (content?.type === "image") {
        context.state.summary = "image";
        updateHeader(theme, context, "Read", context.state.detail, context.state.summary);
        return emptyResult();
      }

      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No content"), 0, 0);
      }

      const lineCount = content.text.split("\n").length;
      let summary = `${lineCount} lines`;
      if (details?.truncation?.truncated) {
        summary += " [truncated]";
      }
      context.state.summary = summary;
      updateHeader(theme, context, "Read", context.state.detail, summary);

      if (!expanded) {
        return emptyResult();
      }

      let text = "";
      const lines = content.text.split("\n").slice(0, 15);
      for (const line of lines) {
        text += `\n${theme.fg("dim", line)}`;
      }
      if (lineCount > 15) {
        text += `\n${theme.fg("muted", `... ${lineCount - 15} more lines`)}`;
      }

      return new Text(text.trimStart(), 0, 0);
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
      context.state.detail = parts.join(", ");
      return renderHeader(theme, context, "Grep", context.state.detail, context.state.summary);
    },

    renderResult(result, { expanded, isPartial }, theme, context) {
      if (isPartial) return new Text(theme.fg("warning", "Searching..."), 0, 0);

      const details = result.details as GrepToolDetails | undefined;
      const content = result.content[0];
      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No matches"), 0, 0);
      }

      const matchCount = countNonEmptyLines(content.text);
      let summary = `${matchCount} matches`;
      if (details?.truncation?.truncated) {
        summary += " [truncated]";
      }
      context.state.summary = summary;
      updateHeader(theme, context, "Grep", context.state.detail, summary);

      if (!expanded) {
        return emptyResult();
      }

      let text = "";
      const lines = content.text.split("\n").slice(0, 20);
      for (const line of lines) {
        text += `\n${theme.fg("dim", line)}`;
      }
      if (matchCount > 20) {
        text += `\n${theme.fg("muted", "... more matches")}`;
      }

      return new Text(text.trimStart(), 0, 0);
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
      context.state.detail = parts.join(", ");
      return renderHeader(theme, context, "Find", context.state.detail, context.state.summary);
    },

    renderResult(result, { expanded, isPartial }, theme, context) {
      if (isPartial) return new Text(theme.fg("warning", "Finding..."), 0, 0);

      const details = result.details as FindToolDetails | undefined;
      const content = result.content[0];
      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No results"), 0, 0);
      }

      const fileCount = countNonEmptyLines(content.text);
      let summary = `${fileCount} files`;
      if (details?.truncation?.truncated) {
        summary += " [truncated]";
      }
      context.state.summary = summary;
      updateHeader(theme, context, "Find", context.state.detail, summary);

      if (!expanded) {
        return emptyResult();
      }

      let text = "";
      const lines = content.text.split("\n").slice(0, 20);
      for (const line of lines) {
        text += `\n${theme.fg("dim", line)}`;
      }
      if (fileCount > 20) {
        text += `\n${theme.fg("muted", "... more files")}`;
      }

      return new Text(text.trimStart(), 0, 0);
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
      context.state.detail = parts.join(", ");
      return renderHeader(theme, context, "Ls", context.state.detail, context.state.summary);
    },

    renderResult(result, { expanded, isPartial }, theme, context) {
      if (isPartial) return new Text(theme.fg("warning", "Listing..."), 0, 0);

      const details = result.details as LsToolDetails | undefined;
      const content = result.content[0];
      if (content?.type !== "text") {
        return new Text(theme.fg("error", "No entries"), 0, 0);
      }

      const entryCount = countNonEmptyLines(content.text);
      let summary = `${entryCount} entries`;
      if (details?.truncation?.truncated) {
        summary += " [truncated]";
      }
      context.state.summary = summary;
      updateHeader(theme, context, "Ls", context.state.detail, summary);

      if (!expanded) {
        return emptyResult();
      }

      let text = "";
      const lines = content.text.split("\n").slice(0, 20);
      for (const line of lines) {
        text += `\n${theme.fg("dim", line)}`;
      }
      if (entryCount > 20) {
        text += `\n${theme.fg("muted", "... more entries")}`;
      }

      return new Text(text.trimStart(), 0, 0);
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
      context.state.detail = truncate(args.command, 88);
      return renderHeader(theme, context, "Bash", context.state.detail, context.state.summary);
    },

    renderResult(result, _options, theme, context) {
      const content = result.content[0];
      const details = result.details as BashToolDetails | undefined;
      if (content?.type !== "text") return emptyResult();

      const lineCount = countNonEmptyLines(content.text);
      let summary = `${lineCount} lines`;
      if (details?.truncation?.truncated) {
        summary += " [truncated]";
      }
      context.state.summary = summary;
      updateHeader(theme, context, "Bash", context.state.detail, summary);

      const preview = firstNonEmptyLine(content.text);
      if (preview) {
        return new Text(theme.fg("dim", truncate(preview, 120)), 0, 0);
      }

      return emptyResult();
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

    // Intentionally no render overrides so Pi keeps the built-in diff renderer.
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

    // Intentionally no render overrides so Pi keeps the built-in detailed renderer.
  });
}
