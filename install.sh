#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

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

# --- Step 4: Symlinks via GNU Stow ---
STOW_PACKAGES=(zsh tmux wezterm nvim aerospace yazi karabiner mise)

info "Creating symlinks with stow..."
for pkg in "${STOW_PACKAGES[@]}"; do
    info "Stowing $pkg..."
    stow -d "$DOTFILES" -t "$HOME" --adopt "$pkg"
done
# Reset any adopted files back to the repo version
git -C "$DOTFILES" checkout -- .
success "Stow packages linked"

# lazygit targets ~/Library/Application Support/ instead of $HOME, so link manually
LAZYGIT_DEST="$HOME/Library/Application Support/lazygit/config.yml"
LAZYGIT_SRC="$DOTFILES/lazygit/config.yml"
mkdir -p "$(dirname "$LAZYGIT_DEST")"
if [[ -L "$LAZYGIT_DEST" ]] && [[ "$(readlink "$LAZYGIT_DEST")" == "$LAZYGIT_SRC" ]]; then
    success "Already linked: $LAZYGIT_DEST"
else
    if [[ -e "$LAZYGIT_DEST" ]] && [[ ! -L "$LAZYGIT_DEST" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$LAZYGIT_DEST" "$BACKUP_DIR/lazygit-config.yml-$(date +%Y%m%d%H%M%S)"
        warn "Backed up existing lazygit config"
    fi
    ln -sf "$LAZYGIT_SRC" "$LAZYGIT_DEST"
    success "Linked: $LAZYGIT_DEST -> $LAZYGIT_SRC"
fi

# --- Step 5: Tmux Plugin Manager ---
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    info "Installing tmux plugin manager (tpm)..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "tpm installed"
else
    success "tpm already installed"
fi

# --- Step 6: fzf-git.sh ---
FZF_GIT_DIR="$HOME/fzf-git.sh"
if [[ ! -d "$FZF_GIT_DIR" ]]; then
    info "Cloning fzf-git.sh..."
    git clone https://github.com/junegunn/fzf-git.sh "$FZF_GIT_DIR"
    success "fzf-git.sh installed"
else
    success "fzf-git.sh already present"
fi

# --- Step 7: .env.zsh template ---
ENV_FILE="$DOTFILES/zsh/.env.zsh"
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

# --- Step 8: Default shell ---
ZSH_PATH="$(brew --prefix)/bin/zsh"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
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
echo "  3. Fill in $DOTFILES/zsh/.env.zsh with your sensitive values (if new machine)"
echo "  4. Restart your terminal or run: source ~/.zshrc"
