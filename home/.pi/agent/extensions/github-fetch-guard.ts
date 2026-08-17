/**
 * GitHub Fetch Guard
 *
 * Blocks fetch_content for GitHub URLs so pi falls back to local bash + gh
 * for private/authenticated GitHub resources.
 *
 * After adding this file, re-stow the pi package so ~/.pi/agent/extensions/
 * gets the new symlink:
 *   stow -d ~/.dotfiles -t "$HOME" --no-folding -R pi
 *
 * Then restart pi or run /reload.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function isGitHubUrl(value: unknown): value is string {
  if (typeof value !== "string") return false;

  try {
    const url = new URL(value);
    return url.hostname === "github.com" || url.hostname === "api.github.com";
  } catch {
    return false;
  }
}

function getGitHubUrls(input: Record<string, unknown>): string[] {
  const matches: string[] = [];

  if (isGitHubUrl(input.url)) {
    matches.push(input.url);
  }

  if (Array.isArray(input.urls)) {
    for (const url of input.urls) {
      if (isGitHubUrl(url)) {
        matches.push(url);
      }
    }
  }

  return matches;
}

function mentionsGitHub(text: string): boolean {
  return /github|github\.com|pull request|\bpr\b|gh\s+/i.test(text);
}

export default function githubFetchGuard(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.notify("github-fetch-guard enabled: GitHub URLs will use bash + gh instead of fetch_content", "info");
  });

  pi.on("before_agent_start", async (event) => {
    if (!mentionsGitHub(event.prompt)) {
      return undefined;
    }

    return {
      systemPrompt:
        event.systemPrompt +
        `

IMPORTANT: When working with GitHub URLs, do not use fetch_content for github.com or api.github.com links.
Use local shell commands through bash with the authenticated GitHub CLI (gh) instead.
Prefer gh for private repos, pull requests, files, reviews, and metadata.
If you need PR details, prefer commands such as gh pr view, gh api, git fetch, and git diff.`,
    };
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "fetch_content") return undefined;

    const input = event.input as Record<string, unknown>;
    const githubUrls = getGitHubUrls(input);
    if (githubUrls.length === 0) return undefined;

    const lines = githubUrls.map((url) => `- ${url}`).join("\n");
    ctx.ui.notify("Blocked fetch_content for GitHub URL; use bash + gh instead.", "warning");

    return {
      block: true,
      reason:
        "Blocked fetch_content for GitHub URL(s). Use bash with authenticated GitHub CLI (gh) instead, e.g. gh pr view / gh api / git diff.\n" +
        lines,
    };
  });
}
