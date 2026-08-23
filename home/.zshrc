# === Powerlevel10k instant prompt — must stay at the very top ===
# Anything needing console input (passwords, [y/n]) goes above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# === PATH ===
# mise-managed tools (fzf/eza/bat/zoxide/bun/wt) must be on PATH before
# anything below invokes them directly.
export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH" # brew openssl, for native builds
export PATH="$HOME/.local/bin:$PATH"                   # mise + Cursor CLI

# bun (mise-managed runtime; global packages still land in ~/.bun/bin)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# export COMPOSE_PROJECT_NAME=mortgage-pos

# === Mise (runtime/env manager) — must run before fzf/eza/bat/zoxide ===
eval "$(mise activate zsh)"

# === Powerlevel10k theme ===
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh # p10k configure / edit ~/.p10k.zsh
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet # silence instant-prompt warning

# === History ===
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# don't exit the shell (and kill the tmux pane/session) on a stray Ctrl+D
setopt ignore_eof

# herdr: confirm before `exit` in a workspace's last pane — process-exit
# closes the whole workspace with no confirmation (herdr #1385).
if [[ -n "$HERDR_ENV" && -n "$HERDR_WORKSPACE_ID" ]]; then
  exit() {
    local info
    info=$(herdr api snapshot 2>/dev/null | jq -r --arg ws "$HERDR_WORKSPACE_ID" \
      '.result.snapshot.workspaces[] | select(.workspace_id == $ws) | "\(.pane_count)\t\(.label)"' 2>/dev/null)
    if [[ "${info%%$'\t'*}" == "1" ]]; then
      local reply
      read -q "reply?Last pane in herdr workspace '${info#*$'\t'}' — exiting closes the workspace. Exit anyway? [y/N] "
      print
      [[ "$reply" == "y" ]] || return 1
    fi
    builtin exit "$@"
  }
fi

# === Key bindings & line editing ===
bindkey '^[[A' up-line-or-search # arrow-key history search, multiline-safe
bindkey '^[[B' down-line-or-search

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

autoload -Uz edit-command-line # Ctrl+X Ctrl+E: edit command line in $EDITOR
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# vi-mode cursor: block/green in normal mode, bar/purple in insert
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    printf '\033[1 q'
    printf '\033]12;#9ECE6A\007'
  else
    printf '\033[5 q'
    printf '\033]12;#bb9af7\007'
  fi
}
function zle-line-init {
  printf '\033[5 q'
  printf '\033]12;#bb9af7\007'
}
zle -N zle-keymap-select
zle -N zle-line-init

autoload -Uz compinit && compinit

# === Zoxide (better cd) ===
eval "$(zoxide init zsh)"
alias cd="z"

# auto-install mise tool versions on cd into a directory that declares them
function chpwd() {
  if [[ -f .mise.toml || -f .tool-versions || -f .nvmrc || -f .node-version ]]; then
    mise install --quiet 2>/dev/null
  fi
}

# === Eza (better ls) ===
alias ls="eza --icons=always -a"

# === FZF ===
eval "$(fzf --zsh)" # key bindings + fuzzy completion

# use fd instead of the default find-based commands
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# theme colors
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"
export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

source ~/fzf-git.sh/fzf-git.sh

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# per-command fzf preview (cd/export/unset/ssh get custom previews)
_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# === Bat (better cat) ===
export BAT_THEME=tokyonight_night

# === Editor ===
export EDITOR="nvim"

# === Yazi — `y` opens yazi, cd's shell to its exit dir ===
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# === Lazygit ===
unalias lg 2>/dev/null
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

lg() {
    # per-instance cd-on-exit: avoids racing other lazygit instances (other
    # herdr panes) reading/writing the global state.yml
    local dir_file
    dir_file=$(mktemp -t lazygit-newdir) || { lazygit "$@"; return }

    LAZYGIT_NEW_DIR_FILE="$dir_file" lazygit "$@"

    if [[ -s "$dir_file" ]]; then
        local new_dir
        new_dir=$(<"$dir_file")
        if [[ -d "$new_dir" && "$new_dir" != "$PWD" ]]; then
            cd "$new_dir"
        fi
    fi
    rm -f "$dir_file"
}

# === wt (worktrunk) shell integration ===
if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

# === Aliases ===
alias wtn="WT_SKIP_SERVERS=1 wt switch --create"
alias wtr="wt remove --force -D"
alias wtl="wt list"
alias wts="wt switch"
alias zsh="nvim ~/.zshrc"
alias zshr="source ~/.zshrc"
alias boo="nvim ~/.config/ghostty/config"
alias tmx="nvim ~/.tmux.conf"
alias tma="tmux attach-session"
alias her="herdr"
alias hdx="nvim ~/.config/herdr/config.toml"
alias gs="git status"
alias nrd="npm run dev"
alias nrl="npm run dev:live"
alias ghd="gh dash"
alias dot="cd ~/.dotfiles"
alias cc="claude"
alias ccc="claude --continue"
alias nv="nvim"
alias dfa="mise bootstrap dotfiles apply"
alias c='printf "\e[H\e[2J"' # clear screen but keep scrollback (no E3 \e[3J)
alias q="exit"

# === Worktree + Claude helper functions ===

# create worktree, launch claude with a prompt in its tmux session
# usage: wtnc my-branch 'Fix the login bug'
wtnc() {
  local branch="$1"
  shift
  WT_SKIP_TMUX_SWITCH=1 WT_SKIP_SERVERS=1 WT_SKIP_CLAUDE=1 wt switch --create "$branch"
  tmux send-keys -t "${branch}:0.0" "claude '$*'" Enter
}

# address PR review comments in an existing worktree's tmux session
# usage: wtac 123
wtac() {
  local pr="$1"
  local branch
  branch="$(gh pr view "$pr" --json headRefName -q .headRefName)"
  WT_SKIP_TMUX_SWITCH=1 WT_SKIP_SERVERS=1 WT_SKIP_CLAUDE=1 wt switch "$branch"
  tmux send-keys -t "${branch}:0.0" "claude --model claude-sonnet-4-6 '/address-comments ${pr}'" Enter
}

# === Sensitive env vars / local overrides — sourced last so it can override
# anything above ===
[[ -f "${HOME}/.dotfiles/home/.env.zsh" ]] && source "${HOME}/.dotfiles/home/.env.zsh"
