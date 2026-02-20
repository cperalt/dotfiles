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

# --- Step 4: Symlinks ---
backup_and_link() {
    local src="$1"
    local dest="$2"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    # Already the correct symlink
    if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
        success "Already linked: $dest"
        return
    fi

    # Back up existing file/directory/symlink
    if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_name
        backup_name="$(basename "$dest")-$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$BACKUP_DIR/$backup_name"
        warn "Backed up existing $dest to $BACKUP_DIR/$backup_name"
    fi

    ln -s "$src" "$dest"
    success "Linked: $dest -> $src"
}

info "Creating symlinks..."

# Home directory dotfiles
backup_and_link "$DOTFILES/zsh/.zshrc"           "$HOME/.zshrc"
backup_and_link "$DOTFILES/zsh/.p10k.zsh"        "$HOME/.p10k.zsh"
backup_and_link "$DOTFILES/tmux/.tmux.conf"      "$HOME/.tmux.conf"
backup_and_link "$DOTFILES/wezterm/.wezterm.lua"  "$HOME/.wezterm.lua"

# .config directory symlinks
backup_and_link "$DOTFILES/nvim/.config/nvim"           "$HOME/.config/nvim"
backup_and_link "$DOTFILES/aerospace/.config/aerospace"  "$HOME/.config/aerospace"
backup_and_link "$DOTFILES/yazi/.config/yazi"            "$HOME/.config/yazi"
backup_and_link "$DOTFILES/karabiner/.config/karabiner"  "$HOME/.config/karabiner"
backup_and_link "$DOTFILES/mise/.config/mise"              "$HOME/.config/mise"

# Application Support symlinks (file-level to avoid symlinking runtime state)
backup_and_link "$DOTFILES/lazygit/config.yml"  "$HOME/Library/Application Support/lazygit/config.yml"

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
