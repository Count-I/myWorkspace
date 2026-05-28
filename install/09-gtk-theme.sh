#!/usr/bin/env bash
# install/09-gtk-theme.sh - Apply Catppuccin Mocha theme globally

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

log_info "Applying Catppuccin Mocha theme..."

# Verify theme packages are installed
if ! pacman -Q catppuccin-gtk-theme-mocha &>/dev/null; then
    log_warn "catppuccin-gtk-theme-mocha not installed. Attempting install..."
    yay -S --needed --noconfirm catppuccin-gtk-theme-mocha || {
        log_warn "Could not install theme package. Continuing without it."
    }
fi

if ! pacman -Q papirus-icon-theme &>/dev/null; then
    log_warn "papirus-icon-theme not installed. Attempting install..."
    sudo pacman -S --needed --noconfirm papirus-icon-theme || {
        log_warn "Could not install icon theme. Continuing without it."
    }
fi

# Apply GTK3 theme via gsettings
log_info "Applying GTK theme via gsettings..."
gsettings set org.gnome.desktop.interface gtk-theme "catppuccin-mocha-standard-blue-dark" 2>/dev/null || \
    log_warn "Could not set GTK theme (gsettings may not be available in TTY autologin)"

# Apply icon theme
log_info "Applying icon theme..."
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || \
    log_warn "Could not set icon theme"

# Apply cursor theme
log_info "Applying cursor theme..."
if pacman -Q catppuccin-cursors-mocha &>/dev/null; then
    gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-dark-cursors" 2>/dev/null || \
        log_warn "Could not set cursor theme"
else
    log_warn "catppuccin-cursors-mocha not installed"
fi

# Export XDG_CURRENT_DESKTOP for proper theme detection
export XDG_CURRENT_DESKTOP=Hyprland

# Set font
log_info "Applying font settings..."
gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 10" 2>/dev/null || \
    log_warn "Could not set font"

log_info "✓ Phase 09 complete: Theme applied"
log_info "Note: Full theme application may require a desktop session restart"
