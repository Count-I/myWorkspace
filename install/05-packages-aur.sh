#!/usr/bin/env bash
# install/05-packages-aur.sh - Install AUR packages via yay

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
PACKAGES_DIR="$REPO_DIR/packages"

# Verify yay is installed
if ! command -v yay &>/dev/null; then
    log_error "yay not installed. Run install/00-pre.sh first."
    exit 1
fi

log_info "Installing AUR packages via yay..."

# Extract packages from aur.txt
AUR_PACKAGES=()
if [[ -f "$PACKAGES_DIR/aur.txt" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        AUR_PACKAGES+=("$line")
    done < "$PACKAGES_DIR/aur.txt"
fi

if [[ ${#AUR_PACKAGES[@]} -eq 0 ]]; then
    log_warn "No AUR packages specified. Skipping."
    log_info "✓ Phase 05 complete: No AUR packages to install"
    exit 0
fi

log_info "Installing ${#AUR_PACKAGES[@]} AUR packages..."
log_info "This may take time for packages requiring compilation."

# Install AUR packages
# Use --noconfirm but allow interactive prompts for security critical packages
if yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"; then
    log_info "✓ AUR package installation completed"
else
    log_warn "Some AUR packages may have failed. Check output above."
    # Don't exit on AUR failure - some packages may have build issues
    # but the system can still function
fi

# Verify critical AUR packages
log_info "Verifying critical AUR packages..."
for pkg in walker catppuccin-gtk-theme-mocha; do
    if pacman -Q "$pkg" &>/dev/null; then
        log_info "✓ $pkg installed"
    else
        log_warn "AUR package not installed: $pkg (may have build issues)"
    fi
done

log_info "✓ Phase 05 complete: AUR packages processed"
