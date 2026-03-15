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
| `lazygit/config.yml`            | `~/Library/Application Support/lazygit/`    |

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
