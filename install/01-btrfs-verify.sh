#!/usr/bin/env bash
# install/01-btrfs-verify.sh - Verify BTRFS subvolumes are present (non-blocking)

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_skip() { echo -e "${BOLD}${BLUE}[SKIP]${NC} $1"; }

# Check if BTRFS tools are available
if ! command -v btrfs &>/dev/null; then
    log_warn "btrfs-progs not installed. BTRFS verification skipped."
    log_warn "Phase 04 (pacman packages) will install btrfs-progs."
    exit 0
fi

# Get root filesystem info
ROOTFS=$(df / | tail -1 | awk '{print $1}')
FSTYPE=$(df -T / | tail -1 | awk '{print $2}')
log_info "Root filesystem: $ROOTFS (type: $FSTYPE)"

# Check if root is BTRFS (informative, not blocking)
if [[ "$FSTYPE" != "btrfs" ]]; then
    log_warn "Root filesystem is NOT BTRFS (it's $FSTYPE)"
    log_warn "This system is designed for BTRFS but can work without it."
    log_warn "Snapper snapshots and BTRFS-specific features will be skipped."
    log_info "Continuing bootstrap (BTRFS is optional)..."
    exit 0
fi

log_info "✓ Root filesystem is BTRFS"

# Check required subvolumes (informative)
log_info "Checking BTRFS subvolumes..."
REQUIRED_SUBVOLS=("@" "@home" "@cache" "@log" "@snapshots")
MISSING_SUBVOLS=()
FOUND_SUBVOLS=()

for subvol in "${REQUIRED_SUBVOLS[@]}"; do
    if ! btrfs subvolume list / 2>/dev/null | grep -q "path $subvol$"; then
        MISSING_SUBVOLS+=("$subvol")
        log_warn "  ✗ Missing: $subvol"
    else
        FOUND_SUBVOLS+=("$subvol")
        log_info "  ✓ Found: $subvol"
    fi
done

# If some subvolumes missing, inform user but don't block
if [[ ${#MISSING_SUBVOLS[@]} -gt 0 ]]; then
    log_warn ""
    log_warn "Missing subvolumes: ${MISSING_SUBVOLS[*]}"
    log_warn "These should have been created by arch-install.sh."
    log_warn "Some features may not work (snapshots, rollback)."
    log_warn "Bootstrap will continue with available subvolumes."
fi

# Check if /.snapshots is mounted (informative)
if mountpoint -q /.snapshots 2>/dev/null; then
    log_info "✓ /.snapshots is mounted"
else
    log_warn "/.snapshots is not mounted"
    log_warn "Snapshots will not be available, but bootstrap will continue."
fi

# Check compression (informative)
MOUNTOPTS=$(findmnt -o OPTIONS -nr / 2>/dev/null || echo "")
if [[ "$MOUNTOPTS" =~ compress=zstd ]]; then
    log_info "✓ Using zstd compression"
elif [[ "$MOUNTOPTS" =~ compress ]]; then
    log_warn "Using compression: $(echo $MOUNTOPTS | grep -o 'compress=[^ ,]*')"
else
    log_warn "Compression not enabled (performance may suffer)"
fi

# Summary
log_info ""
if [[ ${#FOUND_SUBVOLS[@]} -gt 0 ]]; then
    log_info "✓ Phase 01 complete: BTRFS configuration status"
    log_info "Found subvolumes: ${FOUND_SUBVOLS[*]}"
else
    log_skip "Phase 01 complete: BTRFS not available (optional)"
fi
exit 0
