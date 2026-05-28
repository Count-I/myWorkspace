#!/usr/bin/env bash
# Update script - creates snapshots around pacman/AUR updates

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }

log_info "Creating pre-update snapshot..."
PRE=$(sudo snapper -c root create --type pre --cleanup-algorithm number \
    --description "pre-update: $(date +%Y-%m-%d_%H:%M)" --print-number)

log_info "Running system update..."
sudo pacman -Syu

log_info "Creating post-update snapshot..."
sudo snapper -c root create --type post --pre-number "$PRE" \
    --description "post-update: $(date +%Y-%m-%d_%H:%M)"

log_info "Updating AUR packages..."
yay -Syu --aur

log_info "✓ Update complete. Snapshots created."
log_info "Run 'snapper -c root list' to view snapshots."

# Warn if kernel was updated
if ! pacman -Q linux-zen 2>/dev/null | grep -q "$(uname -r | sed 's/-zen//')"; then
    log_warn "Kernel was updated. Reboot is recommended."
fi
