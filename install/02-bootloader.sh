#!/usr/bin/env bash
# install/02-bootloader.sh - Configure systemd-boot with NVIDIA kernel parameters

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}[ERROR]${NC} $1"; }

# Ensure /boot is mounted
if ! mountpoint -q /boot; then
    log_error "/boot is not mounted. Cannot configure bootloader."
    exit 1
fi

log_info "Configuring systemd-boot..."

# Get root PARTUUID
ROOT_PARTUUID=$(lsblk -no PARTUUID / | head -1)
if [[ -z "$ROOT_PARTUUID" ]]; then
    log_error "Could not determine root PARTUUID."
    exit 1
fi
log_info "Root PARTUUID: $ROOT_PARTUUID"

# Create bootloader configuration directory if it doesn't exist
sudo mkdir -p /boot/loader/entries

# Write loader.conf (bootloader settings)
log_info "Writing /boot/loader/loader.conf..."
sudo tee /boot/loader/loader.conf > /dev/null <<EOF
default arch-zen
timeout 4
editor 0
console-mode 0
EOF

# Write Arch Linux (linux-zen) entry with NVIDIA parameters
log_info "Writing /boot/loader/entries/arch-zen.conf..."
sudo tee /boot/loader/entries/arch-zen.conf > /dev/null <<EOF
title   Arch Linux (linux-zen)
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /initramfs-linux-zen.img
options root=PARTUUID=$ROOT_PARTUUID rw rootfstype=btrfs rootflags=subvol=@ \\
        nvidia_drm.modeset=1 nvidia_drm.fbdev=1 \\
        quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3
EOF

# Write fallback entry (without quiet for debugging)
log_info "Writing /boot/loader/entries/arch-zen-fallback.conf..."
sudo tee /boot/loader/entries/arch-zen-fallback.conf > /dev/null <<EOF
title   Arch Linux (linux-zen) [FALLBACK]
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /initramfs-linux-zen-fallback.img
options root=PARTUUID=$ROOT_PARTUUID rw rootfstype=btrfs rootflags=subvol=@ \\
        nvidia_drm.modeset=1 nvidia_drm.fbdev=1 \\
        loglevel=3 systemd.show_status=auto
EOF

# Preserve Windows entry if it exists
if [[ -f /boot/loader/entries/windows.conf ]]; then
    log_info "✓ Preserving existing Windows boot entry"
else
    log_warn "Windows boot entry not found (expected if no dual-boot)"
fi

# Update systemd-boot
log_info "Updating systemd-boot..."
sudo bootctl update

# Verify configuration
log_info "Boot entries configured:"
ls -la /boot/loader/entries/ | grep "\.conf$" | sed 's/^/  /'

log_info "✓ Phase 02 complete: Bootloader configuration successful"
log_info "IMPORTANT: Kernel parameters set to:"
log_info "  - nvidia_drm.modeset=1 (NVIDIA DRM modesetting)"
log_info "  - nvidia_drm.fbdev=1 (NVIDIA framebuffer console)"
log_info "  - quiet (suppress boot messages)"
