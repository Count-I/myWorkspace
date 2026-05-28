#!/usr/bin/env bash
# install/03-nvidia.sh - NVIDIA driver configuration (CRITICAL for boot)

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}[ERROR]${NC} $1"; }

log_info "Configuring NVIDIA driver setup..."

# Verify NVIDIA packages are installed
log_info "Verifying NVIDIA packages..."
if ! pacman -Q nvidia-open-dkms &>/dev/null; then
    log_error "nvidia-open-dkms not installed. Run install/04-packages-pacman.sh first."
    exit 1
fi
log_info "✓ nvidia-open-dkms is installed"

# Create modprobe.d configuration
log_info "Writing /etc/modprobe.d/nvidia.conf..."
sudo tee /etc/modprobe.d/nvidia.conf > /dev/null <<'EOF'
# NVIDIA kernel module options
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

log_info "✓ modprobe.d configuration written"
log_info "  - nvidia_drm.modeset=1: Enable NVIDIA DRM modesetting (required for Wayland)"
log_info "  - nvidia_drm.fbdev=1: Enable framebuffer console (TTY visibility after Wayland)"
log_info "  - NVreg_PreserveVideoMemoryAllocations=1: Required for suspend/resume"

# Update mkinitcpio.conf to include NVIDIA modules
log_info "Updating /etc/mkinitcpio.conf..."

# Check if already updated
if grep -q "^MODULES=(nvidia" /etc/mkinitcpio.conf; then
    log_info "✓ NVIDIA modules already in mkinitcpio.conf"
else
    # Update the MODULES line
    sudo sed -i 's/^MODULES=($/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm/' /etc/mkinitcpio.conf
    log_info "✓ Added NVIDIA modules to mkinitcpio.conf"
fi

# Verify kms hook is present (do NOT remove)
if grep -q "kms" /etc/mkinitcpio.conf; then
    log_info "✓ kms hook is present (correct for nvidia-open-dkms)"
else
    log_warn "kms hook not found in mkinitcpio.conf. Adding..."
    sudo sed -i 's/HOOKS=(base/HOOKS=(base kms/' /etc/mkinitcpio.conf
fi

# Create pacman hook for automatic mkinitcpio rebuild on NVIDIA/kernel updates
log_info "Creating pacman hook for mkinitcpio rebuild..."
sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/nvidia.hook > /dev/null <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open-dkms
Target=linux-zen

[Action]
Description=Rebuild initramfs after NVIDIA/kernel update
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOF

log_info "✓ pacman hook created"
log_info "  This hook will automatically rebuild the initramfs when:"
log_info "    - nvidia-open-dkms is updated"
log_info "    - linux-zen kernel is updated"
log_info "  Without this, kernel updates without DKMS rebuilds = unbootable system"

# Rebuild initramfs now
log_info "Rebuilding initramfs with NVIDIA modules..."
sudo mkinitcpio -P

# Verify nvidia-open-dkms is loaded
log_info "Verifying NVIDIA module status..."
if lsmod | grep -q nvidia; then
    log_info "✓ NVIDIA modules are currently loaded"
    nvidia-smi --query-gpu=name --format=csv,noheader | sed 's/^/  GPU: /'
else
    log_warn "NVIDIA modules not currently loaded (will load after reboot)"
fi

log_info "✓ Phase 03 complete: NVIDIA driver configuration successful"
log_info "CRITICAL: initramfs has been rebuilt with NVIDIA modules"
log_info "A reboot is required for these changes to take effect"
