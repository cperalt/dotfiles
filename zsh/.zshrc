# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
export ENABLE_LSP_TOOL=1

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

# thefuck alias
eval $(thefuck --alias)
eval $(thefuck --alias fk)

# --- Alias ---
alias wtn="WT_SKIP_SERVERS=1 wt switch --create"
alias wtr="wt remove --force -D"
alias wtl="wt list"
alias wts="wt switch"
alias zsh="nvim ~/.zshrc"
alias zshr="source ~/.zshrc"
alias boo="nvim ~/.dotfiles/ghostty/.config/ghostty/config"
alias tmx="nvim ~/.tmux.conf"
alias gs="git status"
alias nrd="npm run dev"
alias nrl="npm run dev:live"
alias ghd="gh dash"
alias dot="cd ~/.dotfiles"
alias cc="claude"
alias ccc="claude --continue"
alias nv="nvim"

# Create worktree and launch claude with a prompt in its tmux session
# Usage: wtnc my-branch 'Fix the login bug'
wtnc() {
  local branch="$1"
  shift
  WT_SKIP_TMUX_SWITCH=1 WT_SKIP_SERVERS=1 wt switch --create "$branch"
  tmux send-keys -t "mpos-${branch}" "claude '$*'" Enter
}

# Address PR review comments in an existing worktree's tmux session
# Usage: wtac 123
wtac() {
  local pr="$1"
  local branch
  branch="$(gh pr view "$pr" --json headRefName -q .headRefName)"
  WT_SKIP_TMUX_SWITCH=1 WT_SKIP_SERVERS=1 wt switch "$branch"
  tmux send-keys -t "mpos-${branch}" "claude --model claude-sonnet-4-6 '/address-comments ${pr}'" Enter
}

# Source sensitive env vars and aliases
[[ -f "${HOME}/.dotfiles/zsh/.env.zsh" ]] && source "${HOME}/.dotfiles/zsh/.env.zsh"

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

# Added by Windsurf
export PATH="/Users/cperaltarayon/.codeium/windsurf/bin:$PATH"
# --- Mise (runtime/env manager) ---
eval "$(mise activate zsh)"
unalias lg 2>/dev/null

lg() {
    local start_dir="$PWD"
    #
    # # Auto-pull the main worktree before launching lazygit
    # _lg_pull_main_worktree
    #
    lazygit "$@"

    # # Auto-pull main worktree again after exiting (picks up any remote changes)
    # _lg_pull_main_worktree
    #
    # Read the most recent repo from lazygit's state file
    local state_file="${HOME}/Library/Application Support/lazygit/state.yml"
    if [[ -f "$state_file" ]]; then
        # Extract the first entry under recentrepos (the last repo lazygit was in)
        local new_dir
        new_dir=$(awk '/^recentrepos:/{found=1; next} found && /^    - /{gsub(/^    - /,""); print; exit}' "$state_file")

        if [[ -n "$new_dir" && -d "$new_dir" && "$new_dir" != "$start_dir" ]]; then
            cd "$new_dir"
        fi
    fi
}

autoload -Uz compinit && compinit
if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

# To customize prompt, run `p10k configure` or edit ~/.dotfiles/zsh/.p10k.zsh.
[[ ! -f ~/.dotfiles/zsh/.p10k.zsh ]] || source ~/.dotfiles/zsh/.p10k.zsh


# ---- Zsh Vi Mode Cursor Color ----
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    printf '\033]12;#9ECE6A\007' # normal mode — green
  else
    printf '\033]12;#bb9af7\007' # insert mode — purple (default)
  fi
}
function zle-line-init {
  printf '\033]12;#bb9af7\007'   # start in insert mode color
}
zle -N zle-keymap-select
zle -N zle-line-init

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh --cmd cd)"
