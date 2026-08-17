# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS dotfiles repo for a development environment. Configs are managed by [mise dotfiles](https://mise.jdx.dev/dotfiles.html): `home/` mirrors `$HOME`, and the `[dotfiles]` section of `home/.config/mise/config.toml` declares each target. Apply with `mise bootstrap dotfiles apply` (always the `bootstrap` subcommand — top-level `mise dotfiles` is deprecated).

## Setup

```bash
# Full bootstrap on a fresh machine
./install.sh

# Install/update Homebrew packages only
brew bundle --file=Brewfile
```

After install, manual steps: `prefix + I` in tmux for plugins, open Neovim for lazy.nvim auto-install.

## Homebrew Tap Trust

Homebrew 6.0+ requires explicit trust for third-party (non-official) taps before it will load them. `brew outdated` / `brew install` silently **skip** untrusted taps with a warning. Trust persists in `~/.config/homebrew/trust.json`.

- Trust a tap now: `brew trust <user/repo>` (e.g. `brew trust hashicorp/tap`).
- Reproducible alternative: mark taps `trusted: true` in the `Brewfile`; `brew bundle` then writes the same `trust.json`.
- The `Brewfile` edit alone changes nothing for `brew outdated` until `brew bundle` runs once — `brew outdated` reads `trust.json`, not the `Brewfile`.

## Dotfiles Map

`dotfiles.root = "~/.dotfiles/home"`, so entries with no explicit source mirror their home-relative path (e.g. `~/.config/nvim` → `home/.config/nvim`).

| Target                                        | Mode           | Notes                                              |
|-----------------------------------------------|----------------|----------------------------------------------------|
| `~/.zshrc`, `~/.p10k.zsh`                     | symlink        |                                                    |
| `~/.tmux.conf`, `~/.wezterm.lua`              | symlink        |                                                    |
| `~/.config/{mise,nvim,ghostty,aerospace,yazi,karabiner,sesh,worktrunk}` | symlink | whole-directory links            |
| `~/Library/Application Support/lazygit/config.yml` | symlink   | under `home/Library/Application Support/`          |
| `~/.config/herdr`, `~/.config/gh-dash`        | symlink-each   | target dirs hold unmanaged files                   |
| `~/.pi/agent`, `~/.omp/agent`                 | symlink-each   | target dirs hold unmanaged files                   |

Useful commands:

```bash
mise bootstrap dotfiles status     # applied / missing / differs
mise bootstrap dotfiles apply      # idempotent; `dfa` alias in .zshrc
mise bootstrap dotfiles add <path> # capture a live file into home/
```

## Neovim Architecture

Entry point: `nvim/.config/nvim/init.lua` — detects VSCode vs standalone Neovim. In VSCode mode, only keymaps load. In standalone mode, delegates to lazy.nvim.

Plugin structure:
- `lua/carlos/lazy.lua` — lazy.nvim bootstrap and plugin spec loader
- `lua/carlos/core/` — options and keymaps
- `lua/carlos/plugins/` — individual plugin configs (each file returns a lazy.nvim spec)
- `lua/carlos/plugins/lsp/` — LSP and Mason configs
- `lua/carlos/lsp.lua` — shared LSP configuration

Theme: Catppuccin Mocha (consistent across nvim, tmux, wezterm, yazi).

## Key Tool Choices

- **Terminal**: Ghostty (primary), WezTerm (fallback) — Maple Mono NF font
- **Shell**: zsh + Powerlevel10k + zsh-autosuggestions + zsh-syntax-highlighting
- **Tmux prefix**: `Ctrl-a` (vim-tmux-navigator for seamless pane/vim movement)
- **Window manager**: AeroSpace
- **Version manager**: mise
- **Git UI**: lazygit
- **File explorer**: yazi + nvim-tree

## Sensitive Files

`home/.env.zsh` is gitignored and holds secrets (API tokens). Template created by `install.sh`. It is sourced by `.zshrc` from its repo path — it is not a `[dotfiles]` entry.

## Scripts

`scripts/tmux-reload-zsh.sh` — reloads zsh config in all tmux panes.
`scripts/tmux-pane-status.sh` — outputs status info for the tmux status bar.

Scripts are **not managed dotfiles** — they are referenced by their full repo path (e.g. `~/.dotfiles/scripts/tmux-pane-status.sh`) and work in-place once the repo is cloned.

## Pi Mono (symlink-each)

The `~/.pi/agent` dotfiles entry manages `settings.json` and `extensions/` from `home/.pi/agent/`. It uses `mode = "symlink-each"` because the target directory contains unmanaged files (`auth.json`, `sessions/`, `git/`) that must not be touched.

**CLI install/update strategy:** pi itself should be managed by the `mise` npm backend, not by `npm install -g` under an active project Node version. Using `npm install -g @earendil-works/pi-coding-agent` inside a repo will install pi into that repo's active Node toolchain (for example Node 22), which causes `pi` to resolve differently across directories.

As of 0.74+, pi was relocated from `@mariozechner/pi-coding-agent` to `@earendil-works/pi-coding-agent` (the old scope is frozen at 0.73.1, so `mise upgrade` against it silently reports "up to date"). Always use the `@earendil-works` scope going forward.

Use these commands instead:

```bash
# Update pi itself via mise (stable across repos)
mise upgrade npm:@earendil-works/pi-coding-agent

# Verify
which pi
pi -v
```

One-time migration from the old scope:

```bash
mise uninstall --all npm:@mariozechner/pi-coding-agent
mise use -g npm:@earendil-works/pi-coding-agent@latest
```

Also update `~/.config/mise/config.toml` so the pinned tool is `npm:@earendil-works/pi-coding-agent`.

Avoid this for pi itself:

```bash
npm install -g @earendil-works/pi-coding-agent
```

**Pi packages** (such as `pi-web-access`, `pi-subagents`, `pi-prompt-template-model`, `pi-markdown-preview`) should still be installed with pi itself, e.g.:

```bash
pi install npm:pi-markdown-preview
pi update
pi list
```

This repo pins pi's npm package-manager operations via `home/.pi/agent/settings.json`:

```json
"npmCommand": ["mise", "exec", "node@25.9.0", "--", "npm"]
```

That means pi package installs/updates use a stable npm context even when the current project activates a different Node version with mise. Existing pi packages do **not** need to be reinstalled just because pi itself was moved to mise management; `pi list` should confirm the current installed package locations.

**After adding or removing files in `home/.pi/agent/extensions/`**, re-apply for the new symlinks to appear at runtime:

```bash
mise bootstrap dotfiles apply   # or the `dfa` alias
```

Pi auto-discovers extensions from `~/.pi/agent/extensions/*.ts`. If a new extension file exists in the repo but hasn't been re-applied, pi won't see it. Deleting a source file removes its stale link on the next apply.

**Editing an existing symlinked extension file does not require re-applying** — changes are visible through the existing symlink. In that case, just restart Pi. Re-apply is only needed when files/directories are added, removed, or moved.

## install.sh Notes

- `install.sh` clones the repo via SSH (`git@github.com`). On a fresh machine, SSH keys must be configured before running the script, otherwise the clone step will fail. This is a known limitation — set up your SSH key first, or clone manually via HTTPS then run the rest of the script.
