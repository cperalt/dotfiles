#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"

info() { printf "\033[1;34m[info]\033[0m %s\n" "$1"; }
success() { printf "\033[1;32m[ok]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[error]\033[0m %s\n" "$1"; }

# --- Step 1: Homebrew ---
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    success "Homebrew installed"
else
    success "Homebrew already installed"
fi

# --- Step 2: Clone dotfiles ---
if [[ ! -d "$DOTFILES" ]]; then
    info "Cloning dotfiles..."
    git clone git@github.com:cperalt/dotfiles.git "$DOTFILES"
    success "Dotfiles cloned to $DOTFILES"
else
    success "Dotfiles already present at $DOTFILES"
fi

# --- Step 3: Homebrew packages ---
info "Installing Homebrew packages from Brewfile..."
brew bundle --file="$DOTFILES/Brewfile"
success "Homebrew packages installed"

# --- Step 4: mise (via mise.run, not brew — enables `mise self-update`) ---
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise &>/dev/null; then
    info "Installing mise via mise.run..."
    curl -fsSL https://mise.run | sh
    success "mise installed to ~/.local/bin"
else
    success "mise already installed"
fi

# --- Step 5: Dotfiles via mise ---
# The global mise config normally lives at ~/.config/mise/config.toml, but that
# symlink is itself created by the apply below — so bootstrap by pointing mise
# at the repo copy explicitly for this one invocation.
# symlink-each targets need existing parent dirs (clear stale dangling symlinks first)
for dir in "$HOME/.config/gh-dash" "$HOME/.config/herdr" "$HOME/.pi/agent" "$HOME/.omp/agent"; do
    [[ -L "$dir" && ! -e "$dir" ]] && rm "$dir"
    mkdir -p "$dir"
done
info "Applying dotfiles with mise..."
MISE_GLOBAL_CONFIG_FILE="$DOTFILES/home/.config/mise/config.toml" \
    mise bootstrap dotfiles apply --yes
success "Dotfiles applied"

# --- Step 6: GitHub CLI extensions ---
info "Installing gh extensions..."
if command -v gh &>/dev/null; then
    if ! gh extension list 2>/dev/null | grep -q "dlvhdr/gh-dash"; then
        gh extension install dlvhdr/gh-dash
        success "gh-dash installed"
    else
        success "gh-dash already installed"
    fi
else
    warn "gh not installed or not authenticated — skipping gh-dash"
fi

# --- Step 6b: herdr plugins ---
HERDR_PLUGIN="paulbkim-dev/vim-herdr-navigation"
if command -v herdr &>/dev/null; then
    if ! herdr plugin list 2>/dev/null | grep -q "vim-herdr-navigation"; then
        info "Installing herdr plugin: $HERDR_PLUGIN"
        herdr plugin install "$HERDR_PLUGIN" -y
        success "vim-herdr-navigation installed"
    else
        success "vim-herdr-navigation already installed"
    fi
else
    warn "herdr not installed — skipping vim-herdr-navigation"
fi

# --- Step 7: Tmux Plugin Manager ---
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    info "Installing tmux plugin manager (tpm)..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "tpm installed"
else
    success "tpm already installed"
fi

# --- Step 8: fzf-git.sh ---
FZF_GIT_DIR="$HOME/fzf-git.sh"
if [[ ! -d "$FZF_GIT_DIR" ]]; then
    info "Cloning fzf-git.sh..."
    git clone https://github.com/junegunn/fzf-git.sh "$FZF_GIT_DIR"
    success "fzf-git.sh installed"
else
    success "fzf-git.sh already present"
fi

# --- Step 9: Mise tools & runtimes ---
if command -v mise &>/dev/null; then
    info "Installing mise runtimes..."
    mise install
    success "Mise runtimes installed"
else
    warn "mise not found — skipping runtime install"
fi

# --- Step 9b: omp (oh-my-pi) ---
# bun is mise-managed; global packages still land in ~/.bun/bin
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if ! command -v omp &>/dev/null; then
    info "Installing omp (oh-my-pi)..."
    curl -fsSL https://omp.sh/install | mise exec -- sh
    success "omp installed"
else
    success "omp already installed"
fi

# --- Step 10: .env.zsh template ---
ENV_FILE="$DOTFILES/home/.env.zsh"
if [[ ! -f "$ENV_FILE" ]]; then
    info "Creating .env.zsh template..."
    cat > "$ENV_FILE" << 'ENVEOF'
# Sensitive values - DO NOT commit this file
# Fill in your actual values below

# GitHub
export HOMEBREW_GITHUB_API_TOKEN=""

ENVEOF
    warn ".env.zsh template created at $ENV_FILE — fill in your sensitive values"
else
    success ".env.zsh already exists"
fi

# --- Step 11: Default shell ---
ZSH_PATH="$(brew --prefix)/bin/zsh"
if [[ ! -f "$ZSH_PATH" ]]; then
    warn "Homebrew zsh not found at $ZSH_PATH — skipping shell change"
elif [[ "$SHELL" != "$ZSH_PATH" ]]; then
    if ! grep -qF "$ZSH_PATH" /etc/shells; then
        info "Adding Homebrew zsh to /etc/shells (requires sudo)..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    info "Changing default shell to zsh..."
    chsh -s "$ZSH_PATH"
    success "Default shell set to $ZSH_PATH"
else
    success "Default shell is already zsh"
fi

echo ""
success "Setup complete!"
info "Remaining manual steps:"
echo "  1. Open tmux and press prefix + I to install tmux plugins"
echo "  2. Open Neovim — Lazy will auto-install plugins on first launch"
echo "  3. Fill in $DOTFILES/home/.env.zsh with your sensitive values (if new machine)"
echo "  4. Restart your terminal or run: source ~/.zshrc"
