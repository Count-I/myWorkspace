#!/usr/bin/env bash
# install/01-btrfs-verify.sh - Verify BTRFS subvolumes are present

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}[ERROR]${NC} $1"; }

# Check if root filesystem is BTRFS
ROOTFS=$(df / | tail -1 | awk '{print $1}')
log_info "Root filesystem: $ROOTFS"

if ! btrfs filesystem show "$ROOTFS" &>/dev/null; then
    log_error "Root filesystem is not BTRFS. This system requires BTRFS."
    log_error "You must re-partition and install Arch with BTRFS before running bootstrap."
    exit 1
fi
log_info "✓ Root filesystem is BTRFS"

# Check required subvolumes
log_info "Verifying required BTRFS subvolumes..."
REQUIRED_SUBVOLS=("@" "@home" "@cache" "@log" "@snapshots")
MISSING_SUBVOLS=()

for subvol in "${REQUIRED_SUBVOLS[@]}"; do
    if ! btrfs subvolume list / | grep -q "path $subvol$"; then
        log_warn "Missing subvolume: $subvol"
        MISSING_SUBVOLS+=("$subvol")
    else
        log_info "✓ Subvolume present: $subvol"
    fi
done

if [[ ${#MISSING_SUBVOLS[@]} -gt 0 ]]; then
    log_error "Missing subvolumes: ${MISSING_SUBVOLS[*]}"
    log_error "These should have been created by arch-install.sh."
    log_error "If running manually, refer to docs/installation.md for BTRFS setup procedure."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Aborting. Please run arch-install.sh or manually create subvolumes."
        exit 1
    fi
fi

# Verify /.snapshots is mounted
if ! mountpoint -q /.snapshots; then
    log_error "/.snapshots is not mounted. Check /etc/fstab for the @snapshots subvolume."
    exit 1
fi
log_info "✓ /.snapshots is mounted"

# Check filesystem is using zstd compression
MOUNTOPTS=$(findmnt -o OPTIONS -nr /)
if [[ ! "$MOUNTOPTS" =~ compress=zstd ]]; then
    log_warn "Root filesystem is not using zstd compression."
    log_warn "Consider re-mounting with compress=zstd:3 for better performance."
fi

# Summary
log_info "✓ Phase 01 complete: BTRFS subvolumes verified"
log_info "Subvolume structure:"
btrfs subvolume list / | grep "path @" | sed 's/^/  /'
