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

const GHOSTTY_LOGO_FRAME = [
  "                                      <span class=\"b\">+++==*%%%%%%%%%%%%*==+++</span>                                      ",
  "                                  <span class=\"b\">++****++</span>                <span class=\"b\">++****++</span>                                  ",
  "                              <span class=\"b\">++**++</span>                            <span class=\"b\">++**++</span>                              ",
  "                          <span class=\"b\">xx**+=</span>          o+*%$@@@@@@$%*+o          <span class=\"b\">=+**xx</span>                          ",
  "                        <span class=\"b\">xx**oo</span>      \u00b7=$@@@@@@@$$$$$$$$@@@@@@@$=\u00b7      <span class=\"b\">oo**xx</span>                        ",
  "                      <span class=\"b\">xx**</span>       x$@@@$$$$$$$$$$$$$$$$$$$$$$$$@@@$x       <span class=\"b\">**xx</span>                      ",
  "                    <span class=\"b\">ox**</span>      \u00b7$@@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@@$\u00b7      <span class=\"b\">**xo</span>                    ",
  "                    <span class=\"b\">==+~</span>    ~@@@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@@@~    <span class=\"b\">~+==</span>                    ",
  "                  <span class=\"b\">x+++</span>     $@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@$     <span class=\"b\">+++x</span>                  ",
  "                  <span class=\"b\">==</span>     \u00b7@@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@@\u00b7     <span class=\"b\">==</span>                  ",
  "                <span class=\"b\">ox++</span>    ~@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@~    <span class=\"b\">++xo</span>                ",
  "                <span class=\"b\">+++~</span>    @$$$$$@@@@@@@@@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@    <span class=\"b\">~+++</span>                ",
  "                <span class=\"b\">==</span>     $$$$$@@%%%%%%$$$$$$$@@@@@$$$@@@@@@@@@@@@@@@@@@@@$$$$$$     <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>     @$$$$*                  $$$$%                  =$$$$$@     <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7$$$$@                   x@$@                    @$$$$$\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$%                 \u00b7$$$$%                  *$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$@@$%%$$$$$$@@@@@@@@$$$$@@@@@@@@@@@@@@@@@@@@$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$@@@@@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    \u00b7@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@\u00b7    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>    ~$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$~    <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==</span>     @@$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$@@     <span class=\"b\">==</span>                ",
  "                <span class=\"b\">==x\u00b7</span>    $@@$$$$$$$$$@@@@@@@@@@$$$$$$$$@@@@@@@@@@$$$$$$$$$@@$    <span class=\"b\">\u00b7+==</span>                ",
  "                <span class=\"b\">++++</span>      =@@@@@@@@@*       x$@@@@@@@@$x       *@@@@@@@@@=      <span class=\"b\">++++</span>                ",
  "                <span class=\"b\">xx==++</span>                                                        <span class=\"b\">++==oo</span>                ",
  "                  <span class=\"b\">++===+</span>              <span class=\"b\">++%%+o</span>            <span class=\"b\">o+%%++</span>              <span class=\"b\">+===++</span>                  ",
  "                    <span class=\"b\">++=====%+=++++*=*========***++++***========*=*++++=+%=====++</span>                    ",
  "                      <span class=\"b\">xx++==******====++</span>  <span class=\"b\">++==********==++</span>  <span class=\"b\">++====******==++xx</span>                      ",
  "                              <span class=\"b\">++++</span>              <span class=\"b\">++++</span>              <span class=\"b\">++++</span>                              "
];

const GHOSTTY_BLUE_HEX = "#89b4fa";
const GHOSTTY_WHITE_HEX = "#cdd6f4";

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

function hexFg(hex: string, text: string): string {
  const match = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  if (!match) return text;
  const [, r, g, b] = match;
  return `\u001b[38;2;${parseInt(r!, 16)};${parseInt(g!, 16)};${parseInt(b!, 16)}m${text}\u001b[39m`;
}

type GhosttyCell = { char: string; color: "blue" | "white" | null };

function parseGhosttyLine(line: string): GhosttyCell[] {
  const cells: GhosttyCell[] = [];
  let inBlueSpan = false;

  for (let i = 0; i < line.length; ) {
    if (line.startsWith('<span class="b">', i)) {
      inBlueSpan = true;
      i += '<span class="b">'.length;
      continue;
    }

    if (line.startsWith('</span>', i)) {
      inBlueSpan = false;
      i += '</span>'.length;
      continue;
    }

    const char = line[i] ?? " ";
    cells.push({ char, color: char === " " ? null : inBlueSpan ? "blue" : "white" });
    i++;
  }

  return cells;
}

function sampleCells(cells: GhosttyCell[], step: number): GhosttyCell[] {
  if (step <= 1) return cells;
  const out: GhosttyCell[] = [];
  for (let i = 0; i < cells.length; i += step) out.push(cells[i] ?? { char: " ", color: null });
  return out;
}

function renderGhosttyLine(line: string, columnStep: number): string {
  const cells = sampleCells(parseGhosttyLine(line), columnStep);
  let out = "";

  for (const { char, color } of cells) {
    if (!color) {
      out += " ";
    } else {
      out += hexFg(color === "blue" ? GHOSTTY_BLUE_HEX : GHOSTTY_WHITE_HEX, char);
    }
  }

  return out;
}

function renderLogo(_theme: Theme, width: number): string[] {
  // Keep the logo in the terminal-friendly aspect ratio used on narrower screens.
  // Rendering every source column on fullscreen terminals makes the static frame look too wide,
  // and it also exaggerates the empty gap between the blue shell and white ghost.
  const rowStep = 2;
  const columnStep = 2;

  return GHOSTTY_LOGO_FRAME
    .filter((_, index) => index % rowStep === 0)
    .map((line) => center(renderGhosttyLine(line, columnStep), width));
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
