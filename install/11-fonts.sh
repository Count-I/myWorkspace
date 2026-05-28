#!/usr/bin/env bash
# install/11-fonts.sh - Rebuild font cache

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

log_info "Rebuilding font cache..."

# Verify required fonts are installed
log_info "Verifying font packages..."
FONT_PACKAGES=("ttf-jetbrains-mono-nerd" "noto-fonts" "noto-fonts-emoji")

for font_pkg in "${FONT_PACKAGES[@]}"; do
    if pacman -Q "$font_pkg" &>/dev/null; then
        log_info "  ✓ $font_pkg installed"
    else
        log_warn "  ✗ $font_pkg not installed (may have failed in package installation)"
    fi
done

# Rebuild font cache
log_info "Rebuilding fontconfig cache..."
fc-cache -fv | tail -5 | sed 's/^/  /'

log_info "✓ Phase 11 complete: Font cache rebuilt"
