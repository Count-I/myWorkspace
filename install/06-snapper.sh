#!/usr/bin/env bash
# install/06-snapper.sh - Configure snapper for BTRFS snapshots
# CRITICAL: Order matters! snapper must be installed and config created BEFORE snap-pac

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

# Verify snapper is installed
if ! pacman -Q snapper &>/dev/null; then
    log_error "snapper not installed. Run install/04-packages-pacman.sh first."
    exit 1
fi

log_info "Configuring snapper for BTRFS snapshots..."

# Verify /.snapshots exists and is mounted
if ! mountpoint -q /.snapshots; then
    log_error "/.snapshots is not mounted. Check BTRFS setup in docs/installation.md"
    exit 1
fi
log_info "✓ /.snapshots is mounted"

# Create root snapshot config
log_info "Creating snapper config for root filesystem..."
if sudo snapper -c root create-config / 2>/dev/null || true; then
    log_info "✓ Root snapshot config created"
else
    log_warn "Root config may already exist. Continuing..."
fi

# Create home snapshot config
log_info "Creating snapper config for /home..."
if sudo snapper -c home create-config /home 2>/dev/null || true; then
    log_info "✓ Home snapshot config created"
else
    log_warn "Home config may already exist. Continuing..."
fi

# Update root config with production settings
log_info "Configuring snapshot retention policy..."
sudo tee /etc/snapper/configs/root > /dev/null <<'EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
TIMELINE_CREATE="no"
TIMELINE_CLEANUP="no"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="20"
NUMBER_LIMIT_IMPORTANT="5"
ALLOW_USERS="root"
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
EOF

log_info "✓ Snapshot retention policy configured"
log_info "  - No automatic timeline snapshots"
log_info "  - Manual snapshots + pre-update snapshots only"
log_info "  - Keep maximum 20 snapshots before cleanup"
log_info "  - Keep at least 5 important snapshots"

# Update home config similarly
sudo tee /etc/snapper/configs/home > /dev/null <<'EOF'
SUBVOLUME="/home"
FSTYPE="btrfs"
TIMELINE_CREATE="no"
TIMELINE_CLEANUP="no"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="3"
ALLOW_USERS="root"
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="no"
EOF

log_info "✓ Home snapshot config updated"

# Now install snap-pac (AFTER snapper configs exist)
log_info "Installing snap-pac (pacman hook for automatic pre/post snapshots)..."
sudo pacman -S --needed --noconfirm snap-pac

log_info "✓ snap-pac installed"
log_info "  The snap-pac hooks are now active:"
log_info "    /usr/share/libalpm/hooks/snap-pac-pre.hook"
log_info "    /usr/share/libalpm/hooks/snap-pac-post.hook"
log_info "  These will create pre/post snapshots automatically during pacman transactions"

# Test snapshot creation
log_info "Testing snapshot creation..."
if sudo snapper -c root create -d "bootstrap-test" 2>&1 | grep -q "created"; then
    log_info "✓ Snapshot creation successful"
    # Clean up test snapshot
    SNAP_NUM=$(sudo snapper -c root list | grep "bootstrap-test" | awk '{print $1}' | head -1)
    if [[ -n "$SNAP_NUM" ]]; then
        sudo snapper -c root delete "$SNAP_NUM"
    fi
else
    log_error "Snapshot creation test failed"
    exit 1
fi

log_info "✓ Phase 06 complete: Snapper configured"
log_info "Current snapshots:"
sudo snapper -c root list | head -5 | sed 's/^/  /'
