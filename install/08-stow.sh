#!/usr/bin/env bash
# install/08-stow.sh - Deploy dotfiles via GNU Stow

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGS_DIR="$REPO_DIR/configs"

# Verify stow is installed
if ! command -v stow &>/dev/null; then
    log_error "stow not installed. Run install/04-packages-pacman.sh first."
    exit 1
fi

log_info "Deploying dotfiles via GNU Stow..."
log_info "Repository: $REPO_DIR"

# Create required directories in home
mkdir -p ~/.config
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications

# Get list of stow packages (subdirectories in configs/)
STOW_PACKAGES=($(ls -d "$CONFIGS_DIR"/*/ | xargs -n 1 basename))

if [[ ${#STOW_PACKAGES[@]} -eq 0 ]]; then
    log_error "No stow packages found in $CONFIGS_DIR"
    exit 1
fi

log_info "Stow packages to deploy: ${STOW_PACKAGES[*]}"

# Deploy each package
for package in "${STOW_PACKAGES[@]}"; do
    log_info "Deploying: $package"

    # Use --adopt to pull existing files into the repo, then restore canonical version
    # This resolves conflicts on first run
    if stow --adopt -t ~ "configs/$package" 2>/dev/null; then
        # Restore canonical content (discard any local changes that were adopted)
        git checkout -- . 2>/dev/null || true
        log_info "  ✓ Deployed: $package"
    else
        log_error "Failed to deploy: $package"
        log_error "Run: stow -t ~ configs/$package (to see detailed errors)"
        exit 1
    fi
done

# Make scripts executable
if [[ -d ~/.local/bin ]]; then
    chmod +x ~/.local/bin/* 2>/dev/null || true
    log_info "✓ Made scripts executable"
fi

# Verify key files are in place
log_info "Verifying deployed files..."
KEY_FILES=(
    ~/.config/hypr/hyprland.conf
    ~/.config/zsh/.zshrc
    ~/.config/waybar/config.jsonc
    ~/.local/bin/update.sh
    ~/.local/bin/cheatsheet.sh
)

for file in "${KEY_FILES[@]}"; do
    if [[ -L "$file" ]]; then
        log_info "  ✓ $(basename $(dirname $file))/$(basename $file) (symlinked)"
    elif [[ -f "$file" ]]; then
        log_info "  ✓ $(basename $(dirname $file))/$(basename $file)"
    else
        log_warn "  ✗ $(basename $(dirname $file))/$(basename $file) NOT FOUND"
    fi
done

log_info "✓ Phase 08 complete: Dotfiles deployed"
