# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS dotfiles repo for a development environment. Configs are symlinked to `$HOME` via GNU stow. Each top-level directory is a stow package whose internal structure mirrors `$HOME`. Exception: lazygit uses a manual symlink since its target is `~/Library/Application Support/`.

## Setup

```bash
# Full bootstrap on a fresh machine
./install.sh

# Install/update Homebrew packages only
brew bundle --file=Brewfile
```

After install, manual steps: `prefix + I` in tmux for plugins, open Neovim for lazy.nvim auto-install.

## Symlink Map

| Source (repo)                    | Target                                      |
|----------------------------------|---------------------------------------------|
| `zsh/.zshrc`, `zsh/.p10k.zsh`   | `$HOME/`                                    |
| `tmux/.tmux.conf`               | `$HOME/`                                    |
| `wezterm/.wezterm.lua`           | `$HOME/`                                    |
| `ghostty/.config/ghostty`       | `$HOME/.config/ghostty`                     |
| `nvim/.config/nvim`             | `$HOME/.config/nvim`                        |
| `aerospace/.config/aerospace`   | `$HOME/.config/aerospace`                   |
| `yazi/.config/yazi`             | `$HOME/.config/yazi`                        |
| `karabiner/.config/karabiner`   | `$HOME/.config/karabiner`                   |
| `mise/.config/mise`             | `$HOME/.config/mise`                        |
| `sesh/.config/sesh`             | `$HOME/.config/sesh`                        |
| `lazygit/config.yml`            | `~/Library/Application Support/lazygit/`    |
| `pi/.pi/agent/settings.json`   | `~/.pi/agent/settings.json`                 |
| `pi/.pi/agent/extensions/`     | `~/.pi/agent/extensions/`                   |

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

`zsh/.env.zsh` is gitignored and holds secrets (API tokens). Template created by `install.sh`.

## Scripts

`scripts/tmux-reload-zsh.sh` — reloads zsh config in all tmux panes.
`scripts/tmux-pane-status.sh` — outputs status info for the tmux status bar.

Scripts are **not a stow package** — they are referenced by their full repo path (e.g. `~/.dotfiles/scripts/tmux-pane-status.sh`) and work in-place once the repo is cloned.

## Pi Mono (Stow with `--no-folding`)

The `pi` stow package manages `~/.pi/agent/settings.json` and `~/.pi/agent/extensions/`. It uses `--no-folding` because the target directory contains unmanaged files (`auth.json`, `sessions/`, `git/`) that must not be touched.

**CLI install/update strategy:** pi itself should be managed by the `mise` npm backend, not by `npm install -g` under an active project Node version. Using `npm install -g @mariozechner/pi-coding-agent` inside a repo will install pi into that repo's active Node toolchain (for example Node 22), which causes `pi` to resolve differently across directories.

Use these commands instead:

```bash
# Install/update pi itself via mise (stable across repos)
mise install npm:@mariozechner/pi-coding-agent@latest
mise reshim

# Verify
which pi
pi -v
```

Avoid this for pi itself:

```bash
npm install -g @mariozechner/pi-coding-agent
```

**Pi packages** (such as `pi-web-access`, `pi-subagents`, `pi-prompt-template-model`, `pi-markdown-preview`) should still be installed with pi itself, e.g.:

```bash
pi install npm:pi-markdown-preview
pi update
pi list
```

This repo pins pi's npm package-manager operations via `pi/.pi/agent/settings.json`:

```json
"npmCommand": ["mise", "exec", "node@25.9.0", "--", "npm"]
```

That means pi package installs/updates use a stable npm context even when the current project activates a different Node version with mise. Existing pi packages do **not** need to be reinstalled just because pi itself was moved to mise management; `pi list` should confirm the current installed package locations.

**After adding or removing files in `pi/.pi/agent/extensions/`**, you must re-stow for the new symlinks to appear at runtime:

```bash
stow -d ~/.dotfiles -t "$HOME" --no-folding -R pi
```

Pi auto-discovers extensions from `~/.pi/agent/extensions/*.ts`. If a new extension file exists in the repo but hasn't been re-stowed, pi won't see it.

**Editing an existing symlinked extension file does not require re-stowing** — changes are visible through the existing symlink. In that case, just restart Pi. Re-stow is only needed when files/directories are added, removed, or moved.

## install.sh Notes

- `install.sh` clones the repo via SSH (`git@github.com`). On a fresh machine, SSH keys must be configured before running the script, otherwise the clone step will fail. This is a known limitation — set up your SSH key first, or clone manually via HTTPS then run the rest of the script.
