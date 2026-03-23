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
STOW_PACKAGES=(zsh tmux wezterm ghostty nvim aerospace yazi karabiner mise)

info "Creating symlinks with stow..."

# Check for conflicts first
CONFLICTS=()
for pkg in "${STOW_PACKAGES[@]}"; do
    # Dry-run — capture output; `|| true` prevents pipefail from aborting on stow's non-zero exit
    stow_output=$(stow -d "$DOTFILES" -t "$HOME" -n "$pkg" 2>&1 || true)

    if ! echo "$stow_output" | grep -q "WARNING\|ERROR"; then
        continue
    fi

    # Extract conflicting files from the captured output (two possible formats):
    # 1. "existing target is not owned by stow: .zshrc"
    # 2. "cannot stow X over existing target .p10k.zsh since ..."
    while IFS= read -r line; do
        if [[ "$line" =~ "existing target is not owned by stow: " ]]; then
            conflict=$(echo "$line" | awk -F': ' '{print $NF}' | xargs)
            CONFLICTS+=("$conflict")
        elif [[ "$line" =~ "over existing target" ]]; then
            conflict=$(echo "$line" | sed -E 's/.*over existing target ([^ ]+) since.*/\1/' | xargs)
            CONFLICTS+=("$conflict")
        fi
    done <<< "$stow_output"
done

# If conflicts exist, prompt user
if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
    warn "Found ${#CONFLICTS[@]} conflicting config file(s):"
    for conflict in "${CONFLICTS[@]}"; do
        echo "  - $conflict"
    done
    echo ""
    echo "Options:"
    echo "  1) Backup existing configs and use repo versions (recommended)"
    echo "  2) Keep existing configs and skip stow (you'll need to merge manually)"
    echo "  3) Abort installation"
    echo ""
    read -p "Choose [1/2/3]: " -n 1 -r choice
    echo ""

    case $choice in
        1)
            info "Backing up existing configs to $BACKUP_DIR..."
            mkdir -p "$BACKUP_DIR"
            for conflict in "${CONFLICTS[@]}"; do
                if [[ -e "$HOME/$conflict" ]] && [[ ! -L "$HOME/$conflict" ]]; then
                    backup_name="$(basename "$conflict")-$(date +%Y%m%d%H%M%S)"
                    cp -a "$HOME/$conflict" "$BACKUP_DIR/$backup_name"
                    warn "Backed up: $conflict → $BACKUP_DIR/$backup_name"
                    rm -f "$HOME/$conflict"
                fi
            done
            success "Backups created"
            ;;
        2)
            warn "Skipping stow - you'll need to manually merge configs"
            echo "Run 'stow -d $DOTFILES -t \$HOME <package>' when ready"
            exit 0
            ;;
        3)
            error "Installation aborted"
            exit 1
            ;;
        *)
            error "Invalid choice - aborting"
            exit 1
            ;;
    esac
fi

# Now stow packages (no --adopt needed, conflicts resolved)
for pkg in "${STOW_PACKAGES[@]}"; do
    info "Stowing $pkg..."
    stow -d "$DOTFILES" -t "$HOME" "$pkg"
done
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

# --- Step 5: GitHub CLI extensions ---
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

# --- Step 6: Tmux Plugin Manager ---
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    info "Installing tmux plugin manager (tpm)..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    success "tpm installed"
else
    success "tpm already installed"
fi

# --- Step 7: fzf-git.sh ---
FZF_GIT_DIR="$HOME/fzf-git.sh"
if [[ ! -d "$FZF_GIT_DIR" ]]; then
    info "Cloning fzf-git.sh..."
    git clone https://github.com/junegunn/fzf-git.sh "$FZF_GIT_DIR"
    success "fzf-git.sh installed"
else
    success "fzf-git.sh already present"
fi

# --- Step 8: .env.zsh template ---
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

# --- Step 9: Default shell ---
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
