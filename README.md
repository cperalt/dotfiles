# dotfiles

macOS dotfiles for a development environment, managed by [mise](https://mise.jdx.dev/). (`AGENTS.md` symlinks here — this file is also the agent guidance for this repo.)

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
| `~/.config/{mise,nvim,ghostty,aerospace,yazi,karabiner,sesh,worktrunk,lazygit}` | symlink | whole-directory links            |
| `~/.config/herdr`, `~/.config/gh-dash`        | symlink-each   | target dirs hold unmanaged files                   |
| `~/.pi/agent`, `~/.omp/agent`                 | symlink-each   | target dirs hold unmanaged files                   |

Useful commands:

```bash
mise bootstrap dotfiles status     # applied / missing / differs
mise bootstrap dotfiles apply      # idempotent; `dfa` alias in .zshrc
mise bootstrap dotfiles add <path> # capture a live file into home/
```

## Neovim Architecture

Entry point: `home/.config/nvim/init.lua` — detects VSCode vs standalone Neovim. In VSCode mode, only keymaps load. In standalone mode, delegates to lazy.nvim.

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
- **Multiplexer**: herdr (replaced tmux day-to-day; tmux config kept, prefix `Ctrl-a`)
- **Window manager**: AeroSpace
- **Version manager**: mise — installed via `mise.run` into `~/.local/bin` (self-updates with `mise self-update`; not brew-managed). Also installs the CLI tools `.zshrc`/configs depend on (`bat`, `eza`, `fd`, `fzf`, `jq`, `lazygit`, `ripgrep`, `worktrunk`, `yazi`, `zoxide`) via `[tools]` in `home/.config/mise/config.toml`; update with `mise outdated` / `mise upgrade`. Everything else (deps, services, GUI apps) stays in the `Brewfile`
- **Git UI**: lazygit — config at `~/.config/lazygit/config.yml` via `LG_CONFIG_FILE` exported in `.zshrc` (macOS default would be `~/Library/Application Support/`)
- **File explorer**: yazi + nvim-tree

## Sensitive Files

`home/.env.zsh` is gitignored and holds secrets (API tokens). Template created by `install.sh`. It is sourced by `.zshrc` from its repo path — it is not a `[dotfiles]` entry.

## install.sh Notes

- `install.sh` clones the repo via SSH (`git@github.com`). On a fresh machine, SSH keys must be configured before running the script, otherwise the clone step will fail. This is a known limitation — set up your SSH key first, or clone manually via HTTPS then run the rest of the script.
