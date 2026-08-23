# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
export ENABLE_LSP_TOOL=1
export ENABLE_TOOL_SEARCH=true
# export COMPOSE_PROJECT_NAME=mortgage-pos

# --- Mise (runtime/env manager) ---
# Installed via mise.run into ~/.local/bin (self-updating; not brew-managed).
# Activated early: fzf/eza/bat/zoxide below are mise-managed and must be on PATH.
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# don't exit the shell (and kill the tmux pane/session) on a stray Ctrl+D
setopt ignore_eof

# herdr: confirm before `exit` in a workspace's last pane — the process-exit
# path closes the whole workspace with no confirmation (herdr #1385, not planned
# upstream). Ctrl+D is already covered by ignore_eof above.
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

# completion using arrow keys (based on history)
# Use up-line-or-search instead of history-search-backward to allow multiline editing
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Edit command line in $EDITOR with Ctrl+X Ctrl+E
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ---- Eza (better ls) -----

alias ls="eza --icons=always -a"

# ---- FZF -----

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}



# Cursor cli neeeded
export PATH="$HOME/.local/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


# --- setup fzf theme ---
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# ----- Bat (better cat) -----

export BAT_THEME=tokyonight_night

source ~/fzf-git.sh/fzf-git.sh

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
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

# --- Alias ---
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

# Create worktree and launch claude with a prompt in its tmux session
# Usage: wtnc my-branch 'Fix the login bug'
wtnc() {
  local branch="$1"
  shift
  WT_SKIP_TMUX_SWITCH=1 WT_SKIP_SERVERS=1 WT_SKIP_CLAUDE=1 wt switch --create "$branch"
  tmux send-keys -t "${branch}:0.0" "claude '$*'" Enter
}

# Address PR review comments in an existing worktree's tmux session
# Usage: wtac 123
wtac() {
  local pr="$1"
  local branch
  branch="$(gh pr view "$pr" --json headRefName -q .headRefName)"
  WT_SKIP_TMUX_SWITCH=1 WT_SKIP_SERVERS=1 WT_SKIP_CLAUDE=1 wt switch "$branch"
  tmux send-keys -t "${branch}:0.0" "claude --model claude-sonnet-4-6 '/address-comments ${pr}'" Enter
}

# Source sensitive env vars and aliases
[[ -f "${HOME}/.dotfiles/home/.env.zsh" ]] && source "${HOME}/.dotfiles/home/.env.zsh"

# Silence powerlevel10k I/O Warning
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# --- Yazi Setup ---
export EDITOR="nvim"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

export PATH="/Users/cperaltarayon/.codeium/windsurf/bin:$PATH"

function chpwd() {
  if [[ -f .mise.toml || -f .tool-versions || -f .nvmrc || -f .node-version ]]; then
    mise install --quiet 2>/dev/null
  fi
}
unalias lg 2>/dev/null
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

lg() {
    # Per-instance cd-on-exit: lazygit writes ITS repo dir to this file.
    # (Reading the global state.yml races with other lazygit instances in
    # other herdr panes and can cd this shell into the wrong worktree.)
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

autoload -Uz compinit && compinit
if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi



# ---- Zsh Vi Mode Cursor Color + Shape ----
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    printf '\033[1 q'            # blinking block — normal mode
    printf '\033]12;#9ECE6A\007' # color: green
  else
    printf '\033[5 q'            # blinking bar — insert mode
    printf '\033]12;#bb9af7\007' # color: purple (default)
  fi
}
function zle-line-init {
  printf '\033[5 q'            # start each line in insert mode: blinking bar
  printf '\033]12;#bb9af7\007' # color: purple
}
zle -N zle-keymap-select
zle -N zle-line-init
# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"

alias cd="z"
