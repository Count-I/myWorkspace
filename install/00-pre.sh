#!/usr/bin/env bash
# install/00-pre.sh - Pre-flight setup and dependency verification

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}[ERROR]${NC} $1"; }

# Verify we're not root
if [[ $EUID -eq 0 ]]; then
    log_error "Do not run as root. Use a regular user with sudo access."
    exit 1
fi

log_info "Verifying Arch Linux installation..."
if ! grep -q "^ID=arch$" /etc/os-release; then
    log_error "Not running on Arch Linux. Aborting."
    exit 1
fi
log_info "✓ Arch Linux detected"

# Update pacman databases
log_info "Updating pacman databases..."
sudo pacman -Sy --noconfirm

# Install base-devel if not present
log_info "Ensuring base-devel is installed..."
sudo pacman -S --needed --noconfirm base-devel

# Install yay (AUR helper) if not present
if ! command -v yay &>/dev/null; then
    log_info "Installing yay (AUR helper)..."
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd /tmp
    rm -rf yay-bin
    log_info "✓ yay installed"
else
    log_info "✓ yay already installed"
fi

# Verify Chaotic-AUR keyring
log_info "Verifying Chaotic-AUR keyring..."
if ! pacman -Q chaotic-keyring &>/dev/null; then
    log_warn "chaotic-keyring not installed. Installing..."
    sudo pacman-key --recv-key 3056513887B78AEB
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -S --noconfirm chaotic-keyring chaotic-mirrorlist
    log_info "✓ Chaotic-AUR keyring configured"
else
    log_info "✓ chaotic-keyring already installed"
fi

# Set locale if needed
log_info "Checking locale configuration..."
if ! locale | grep -q "en_US.utf8"; then
    log_warn "en_US.UTF-8 locale not active. Configuring..."
    sudo sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    sudo locale-gen
    echo "LANG=en_US.UTF-8" | sudo tee -a /etc/locale.conf
    log_info "✓ Locale configured"
else
    log_info "✓ Locale already configured"
fi

# Verify essential tools
log_info "Verifying essential tools..."
for tool in git curl wget stow; do
    if ! command -v "$tool" &>/dev/null; then
        log_warn "Installing missing tool: $tool"
        sudo pacman -S --noconfirm "$tool"
    fi
done
log_info "✓ Essential tools verified"

log_info "✓ Phase 00 complete: Pre-flight setup successful"
