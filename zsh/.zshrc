# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

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
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Eza (better ls) -----

alias ls="eza --icons=always"

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"

alias cd="z"

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
# alias lg="lazygit"

# === Git (shortened git commands) ===== #
# alias gc= "git checkout"
alias gd= "git diff"
alias gs="git status"
alias gb="git branch"
alias ga="git add ."
alias gc='f() { git commit -m $1 };f'
# === SOMETHING USEFUL TO WORK ON ====== #
# alias gdelete="git branch -d `git branch --list 'FRONT-*'`"
alias glist='f() { git branch --list $2 };f'
alias gittree="git log --all --decorate --oneline --graph"

# === NPM (shortened npm commands) ===== #
alias nrd="npm run dev"
alias nrl="npm run dev:live"



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
unalias lg 2>/dev/null

lg() {
    local start_dir="$PWD"
    lazygit "$@"

    # Read the most recent repo from lazygit's state file
    local state_file="${HOME}/Library/Application Support/lazygit/state.yml"
    if [[ -f "$state_file" ]]; then
        # Extract the first entry under recentrepos (the last repo lazygit was in)
        local new_dir
        new_dir=$(awk '/^recentrepos:/{found=1; next} found && /^    - /{gsub(/^    - /,""); print; exit}' "$state_file")

        if [[ -n "$new_dir" && -d "$new_dir" && "$new_dir" != "$start_dir" ]]; then
            cd "$new_dir"
            /Applications/Cursor.app/Contents/Resources/app/bin/cursor -r .
        fi
    fi
}
