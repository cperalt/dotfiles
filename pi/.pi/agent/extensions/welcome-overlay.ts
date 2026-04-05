import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { visibleWidth } from "@mariozechner/pi-tui";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

type WelcomeHeaderSettings = {
  enabled: boolean;
  persistent: boolean;
  timeoutSeconds: number;
};

const DEFAULT_SETTINGS: WelcomeHeaderSettings = {
  enabled: true,
  persistent: true,
  timeoutSeconds: 12,
};

const NYAN_HEADER = [
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ███████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ███████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
  " ██████████████████████████████████████████████████████████████████████████████████████████████████████ ",
];

const NYAN_COLOR_MAP = [
  " WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWWWWWWWWWW ",
  " RRRRWWWWWWWWWWWWWWWWRRRRRRRRRRRRRRRRWWWWWWWWWWWWWWWWBBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPBBWWWWWWWWWWWW ",
  " RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRBBPPPPPPHHHHHHHHHHHHHHHHHHHHHHHHHHPPPPPPBBWWWWWWWWWW ",
  " RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRBBPPPPHHHHHHHHHHHHFFHHHHFFHHHHHHHHHHPPPPBBWWWWWWWWWW ",
  " OOOORRRRRRRRRRRRRRRROOOOOOOOOOOOOOOORRRRRRRRRRRRRRBBPPHHHHFFHHHHHHHHHHHHHHHHHHHHHHHHHHHHPPBBWWWWWWWWWW ",
  " OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOBBPPHHHHHHHHHHHHHHHHHHHHBBBBHHHHFFHHHHPPBBWWBBBBWWWW ",
  " OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOBBPPHHHHHHHHHHHHHHHHHHBBMMMMBBHHHHHHHHPPBBBBMMMMBBWW ",
  " YYYYOOOOOOOOOOOOOOOOYYYYYYYYYYYYYYYYOOBBBBBBBBOOOOBBPPHHHHHHHHHHHHFFHHHHBBMMMMMMBBHHHHHHPPBBMMMMMMBBWW ",
  " YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYBBMMMMBBBBOOBBPPHHHHHHHHHHHHHHHHHHBBMMMMMMMMBBBBBBBBMMMMMMMMBBWW ",
  " YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYBBBBMMMMBBBBBBPPHHHHHHFFHHHHHHHHHHBBMMMMMMMMMMMMMMMMMMMMMMMMBBWW ",
  " GGGGYYYYYYYYYYYYYYYYGGGGGGGGGGGGGGGGYYYYBBBBMMMMBBBBPPHHHHHHHHHHHHHHFFBBMMMMMMMMMMMMMMMMMMMMMMMMMMMMBB ",
  " GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBBMMMMBBPPHHFFHHHHHHHHHHHHBBMMMMMMCCBBMMMMMMMMMMCCBBMMMMBB ",
  " GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBBBBBBPPHHHHHHHHHHHHHHHHBBMMMMMMBBBBMMMMMMBBMMBBBBMMMMBB ",
  " UUUUGGGGGGGGGGGGGGGGUUUUUUUUUUUUUUUUGGGGGGGGGGGGBBBBPPHHHHHHHHHHFFHHHHBBMMrrrrMMMMMMMMMMMMMMMMrrrrBB   ",
  " UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUBBPPPPHHFFHHHHHHHHHHBBMMrrrrMMBBMMMMBBMMMMBBMMrrrrBB ",
  " UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUBBPPPPPPHHHHHHHHHHHHHHBBMMMMMMBBBBBBBBBBBBBBMMMMBBWW ",
  " VVVVUUUUUUUUUUUUUUUUVVVVVVVVVVVVVVVVUUUUUUUUUUUUBBBBBBPPPPPPPPPPPPPPPPPPPPBBMMMMMMMMMMMMMMMMMMMMBBWWWW ",
  " VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVBBMMMMMMBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBWWWWWW ",
  " VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVBBMMMMBBBBWWBBMMMMBBWWWWWWWWWWBBMMMMBBWWBBMMMMBBWWWWWWWW ",
  " WWWWVVVVVVVVVVVVVVVVWWWWWWWWWWWWWWWWVVVVVVVVVVBBBBBBBBWWWWBBBBBBWWWWWWWWWWWWWWBBBBBBWWWWBBBBWWWWWWWWWW ",
];

const CATPPUCCIN_MOCHA_HEX: Partial<Record<string, string>> = {
  C: "#cdd6f4",
  B: "#11111b",
  R: "#f38ba8",
  O: "#fab387",
  Y: "#f9e2af",
  G: "#a6e3a1",
  U: "#89b4fa",
  P: "#f9e2af",
  H: "#f5c2e7",
  F: "#f38ba8",
  M: "#6c7086",
  V: "#b4befe",
  r: "#f38ba8",
};

const TRANSPARENT_TOKENS = new Set(["W"]);

function getSettingsPath(): string {
  return join(process.env.HOME || process.env.USERPROFILE || homedir(), ".pi", "agent", "settings.json");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readExtensionSettings(): WelcomeHeaderSettings {
  try {
    const path = getSettingsPath();
    if (!existsSync(path)) return DEFAULT_SETTINGS;
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    if (!isRecord(parsed)) return DEFAULT_SETTINGS;

    const raw = parsed.welcomeOverlay;
    if (!isRecord(raw)) return DEFAULT_SETTINGS;

    return {
      enabled: typeof raw.enabled === "boolean" ? raw.enabled : DEFAULT_SETTINGS.enabled,
      persistent: typeof raw.persistent === "boolean" ? raw.persistent : DEFAULT_SETTINGS.persistent,
      timeoutSeconds:
        typeof raw.timeoutSeconds === "number" && Number.isFinite(raw.timeoutSeconds)
          ? Math.max(1, Math.min(60, Math.round(raw.timeoutSeconds)))
          : DEFAULT_SETTINGS.timeoutSeconds,
    };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

function center(text: string, width: number): string {
  const visible = visibleWidth(text);
  if (visible >= width) return text;
  const left = Math.floor((width - visible) / 2);
  const right = width - visible - left;
  return " ".repeat(left) + text + " ".repeat(right);
}

function sampleLine(line: string, step: number): string {
  let out = "";
  for (let i = 0; i < line.length; i += step) out += line[i] ?? " ";
  return out;
}

function hexFg(hex: string, text: string): string {
  const match = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  if (!match) return text;
  const [, r, g, b] = match;
  return `\u001b[38;2;${parseInt(r!, 16)};${parseInt(g!, 16)};${parseInt(b!, 16)}m${text}\u001b[39m`;
}

function renderMappedLine(_theme: Theme, headerLine: string, colorLine: string): string {
  let out = "";

  for (let i = 0; i < headerLine.length; i++) {
    const char = headerLine[i] ?? " ";
    const colorKey = colorLine[i] ?? " ";
    const hex = CATPPUCCIN_MOCHA_HEX[colorKey];

    if (char === " " || TRANSPARENT_TOKENS.has(colorKey)) {
      out += " ";
    } else if (!hex) {
      out += char;
    } else {
      out += hexFg(hex, char);
    }
  }

  return out;
}

function renderLogo(theme: Theme, width: number): string[] {
  const compact = width < 108;
  const header = compact ? NYAN_HEADER.filter((_, index) => index % 2 === 0).map((line) => sampleLine(line, 2)) : NYAN_HEADER;
  const colors = compact ? NYAN_COLOR_MAP.filter((_, index) => index % 2 === 0).map((line) => sampleLine(line, 2)) : NYAN_COLOR_MAP;

  return header.map((line, index) => center(renderMappedLine(theme, line, colors[index] ?? ""), width));
}

class WelcomeHeaderComponent {
  private countdown: number | null;

  constructor(
    private readonly theme: Theme,
    private readonly modelName: string,
    private readonly providerName: string,
    timeoutSeconds: number | null,
    private readonly persistent: boolean,
  ) {
    this.countdown = timeoutSeconds;
  }

  setCountdown(value: number | null): void {
    this.countdown = value;
  }

  invalidate(): void {}

  render(width: number): string[] {
    if (width < 56) return [];

    const lines: string[] = [];
    const scope = `${this.providerName} / ${this.modelName}`;

    lines.push("");
    lines.push(center(this.theme.bold(this.theme.fg("accent", "pi")), width));
    lines.push(center(this.theme.fg("muted", scope), width));
    lines.push("");
    lines.push(...renderLogo(this.theme, width));

    if (!this.persistent && this.countdown !== null) {
      lines.push("");
      lines.push(center(this.theme.fg("dim", `press any key to continue • auto-hide in ${this.countdown}s`), width));
    }

    lines.push("");
    return lines;
  }
}

export default function welcomeOverlay(pi: ExtensionAPI) {
  let hideTimer: NodeJS.Timeout | null = null;
  let countdownTimer: NodeJS.Timeout | null = null;
  let active = false;
  let component: WelcomeHeaderComponent | null = null;
  let lastCtx: ExtensionContext | null = null;

  function clearTimers(): void {
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = null;
    }
    if (countdownTimer) {
      clearInterval(countdownTimer);
      countdownTimer = null;
    }
  }

  function hideHeader(ctx?: ExtensionContext | null): void {
    clearTimers();
    active = false;
    component = null;
    (ctx ?? lastCtx)?.ui.setHeader(undefined);
  }

  function showHeader(ctx: ExtensionContext, temporary: boolean): void {
    if (!ctx.hasUI) return;
    lastCtx = ctx;
    clearTimers();

    const settings = readExtensionSettings();
    const modelName = ctx.model?.name || ctx.model?.id || "No model selected";
    const providerName = ctx.model?.provider || "Unknown provider";
    const persistent = !temporary && settings.persistent;
    const timeoutSeconds = temporary ? settings.timeoutSeconds : null;

    ctx.ui.setHeader((_tui, theme) => {
      component = new WelcomeHeaderComponent(theme, modelName, providerName, timeoutSeconds, persistent);
      return component;
    });

    active = true;

    if (temporary && timeoutSeconds !== null) {
      let remaining = timeoutSeconds;
      countdownTimer = setInterval(() => {
        remaining -= 1;
        component?.setCountdown(Math.max(0, remaining));
        if (remaining <= 0) {
          hideHeader(ctx);
        }
      }, 1000);

      hideTimer = setTimeout(() => {
        hideHeader(ctx);
      }, timeoutSeconds * 1000);
    }
  }

  pi.on("session_start", async (event, ctx) => {
    lastCtx = ctx;
    const settings = readExtensionSettings();
    if (!settings.enabled || !ctx.hasUI) return;
    if (event.reason !== "startup") return;
    showHeader(ctx, !settings.persistent);
  });

  pi.on("input", async (_event, ctx) => {
    const settings = readExtensionSettings();
    if (active && !settings.persistent) hideHeader(ctx);
    return { action: "continue" as const };
  });

  pi.on("agent_start", async (_event, ctx) => {
    const settings = readExtensionSettings();
    if (active && !settings.persistent) hideHeader(ctx);
  });

  pi.on("session_shutdown", async () => {
    clearTimers();
    active = false;
    component = null;
    lastCtx = null;
  });
}
