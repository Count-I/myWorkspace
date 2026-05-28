#!/usr/bin/env bash
# install/04-packages-pacman.sh - Install all packages from pacman manifests

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}[ERROR]${NC} $1"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="$REPO_DIR/packages"

# Verify packages directory exists
if [[ ! -d "$PACKAGES_DIR" ]]; then
    log_error "Packages directory not found: $PACKAGES_DIR"
    exit 1
fi

log_info "Installing packages from official Arch repositories..."

# Build package list from all manifests (except aur.txt)
PACKAGE_LIST=()
for manifest in "$PACKAGES_DIR"/{base,nvidia,desktop,audio,btrfs,apps,tools,gaming}.txt; do
    if [[ ! -f "$manifest" ]]; then
        log_warn "Manifest not found: $manifest"
        continue
    fi

    # Extract non-comment lines
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        PACKAGE_LIST+=("$line")
    done < "$manifest"
done

log_info "Installing ${#PACKAGE_LIST[@]} packages..."
log_info "This may take 30-60 minutes depending on network speed and AUR compilation."

# Install packages
if sudo pacman -S --needed --noconfirm "${PACKAGE_LIST[@]}"; then
    log_info "✓ Package installation completed successfully"
else
    log_error "Package installation failed. Check the output above for details."
    exit 1
fi

# Verify critical packages
log_info "Verifying critical packages..."
CRITICAL=("linux-zen" "hyprland" "pipewire" "wireplumber" "nvidia-open-dkms" "docker" "snapper")
for pkg in "${CRITICAL[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        log_info "✓ $pkg installed"
    else
        log_error "Critical package missing: $pkg"
        exit 1
    fi
done

log_info "✓ Phase 04 complete: All pacman packages installed"
log_info "Package count: $(pacman -Q | wc -l)"
