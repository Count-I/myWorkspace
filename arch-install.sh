#!/usr/bin/env bash
#
# arch-install.sh - Ultra-autonomous Arch Linux installer
#
# This script performs a COMPLETE Arch installation from ISO:
# 1. Detects and lets user choose target disk
# 2. Partitions and creates BTRFS subvolumes
# 3. Installs base system
# 4. Configures bootloader and services
# 5. Calls bootstrap.sh for workstation setup
#
# Usage: sudo arch-install.sh
#
# REQUIREMENTS:
# - Running from Arch ISO (in live environment)
# - Internet connectivity
# - Target disk will be WIPED
#

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}[ERROR]${NC} $1"; }
log_phase() {
    echo ""
    echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
}

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
fi

# Verify we're on Arch ISO
if ! grep -q "Arch" /etc/os-release 2>/dev/null; then
    log_error "This script must run from Arch ISO."
    exit 1
fi

log_phase "ARCH LINUX INSTALLER"
echo ""
log_info "Ultra-autonomous installation for workstation deployment"
echo ""

# ============================================================================
# DISK SELECTION
# ============================================================================
log_phase "DISK DETECTION AND SELECTION"

# Get list of disks
mapfile -t DISKS < <(lsblk -nd -o NAME,SIZE,MODEL,TYPE | grep -E "^[a-z]" | grep -v "loop")

if [[ ${#DISKS[@]} -eq 0 ]]; then
    log_error "No disks detected. Aborting."
    exit 1
fi

echo ""
log_info "Available disks:"
echo ""
for i in "${!DISKS[@]}"; do
    IFS=' ' read -r name size model type <<< "${DISKS[$i]}"
    echo -e "  ${BLUE}[$((i+1))]${NC} /dev/$name | $size | $model"
done
echo ""

# Ask user to select disk
while true; do
    read -p "Select disk number (1-${#DISKS[@]}): " disk_choice

    if [[ "$disk_choice" =~ ^[0-9]+$ ]] && (( disk_choice >= 1 && disk_choice <= ${#DISKS[@]} )); then
        selected_disk_line="${DISKS[$((disk_choice-1))]}"
        TARGET_DISK="/dev/$(echo "$selected_disk_line" | awk '{print $1}')"
        TARGET_SIZE="$(echo "$selected_disk_line" | awk '{print $2}')"
        break
    else
        log_error "Invalid selection. Try again."
    fi
done

echo ""
log_warn "⚠️  YOU ARE ABOUT TO WIPE: $TARGET_DISK ($TARGET_SIZE)"
log_warn "All data on this disk will be PERMANENTLY DELETED."
echo ""
read -p "Type 'wipe ${TARGET_DISK##*/}' to confirm: " confirm

if [[ "$confirm" != "wipe ${TARGET_DISK##*/}" ]]; then
    log_error "Confirmation failed. Aborting."
    exit 1
fi

log_info "Proceeding with installation on $TARGET_DISK"
echo ""

# ============================================================================
# PARTITIONING
# ============================================================================
log_phase "DISK PARTITIONING"

log_warn "Wiping disk..."
wipefs -af "$TARGET_DISK"
partprobe "$TARGET_DISK" 2>/dev/null || true

log_info "Creating GPT partition table with fdisk..."
# Use fdisk with heredoc for non-interactive partitioning
fdisk "$TARGET_DISK" << FDISK_EOF
g
n
1

+512M
t
1
n
2


w
FDISK_EOF

# Set EFI partition type
fdisk "$TARGET_DISK" << FDISK_EOF
t
1
1
w
FDISK_EOF

# Detect partition names (sda1/sda2 vs nvme0n1p1/nvme0n1p2)
if [[ "$TARGET_DISK" == *"nvme"* ]]; then
    EFI_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

log_info "EFI partition: $EFI_PART"
log_info "Root partition: $ROOT_PART"

sleep 2
partprobe "$TARGET_DISK" 2>/dev/null || true

# ============================================================================
# FILESYSTEM CREATION
# ============================================================================
log_phase "FILESYSTEM CREATION"

log_info "Creating FAT32 for EFI..."
mkfs.fat -F 32 "$EFI_PART" > /dev/null

log_info "Creating BTRFS for root..."
mkfs.btrfs -f "$ROOT_PART" > /dev/null

log_info "Creating BTRFS subvolumes..."
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
umount /mnt

log_info "Mounting subvolumes..."
BTRFS_OPTS="rw,relatime,compress=zstd:3,space_cache=v2"

mount -o "$BTRFS_OPTS,subvol=@" "$ROOT_PART" /mnt
mkdir -p /mnt/{home,var/cache,var/log,.snapshots,boot}
mount -o "$BTRFS_OPTS,subvol=@home" "$ROOT_PART" /mnt/home
mount -o "$BTRFS_OPTS,subvol=@cache" "$ROOT_PART" /mnt/var/cache
mount -o "$BTRFS_OPTS,subvol=@log" "$ROOT_PART" /mnt/var/log
mount -o "$BTRFS_OPTS,subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots
mount "$EFI_PART" /mnt/boot

log_info "✓ Filesystem setup complete"

# ============================================================================
# PACSTRAP
# ============================================================================
log_phase "SYSTEM INSTALLATION"

log_info "Updating pacman databases..."
pacman -Sy

log_info "Installing base system (this may take 5-10 minutes)..."
pacstrap -K /mnt base linux-zen linux-firmware btrfs-progs git curl wget networkmanager sudo zsh

log_info "✓ Base system installed"

# ============================================================================
# FSTAB & CHROOT SETUP
# ============================================================================
log_phase "SYSTEM CONFIGURATION"

log_info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

log_info "Setting timezone..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime
arch-chroot /mnt hwclock --systohc

log_info "Configuring locale..."
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf

log_info "Setting hostname..."
echo "arch-workstation" > /mnt/etc/hostname

log_info "Creating user account..."
read -p "Username for regular user: " username
arch-chroot /mnt useradd -m -G wheel,docker -s /bin/zsh "$username"
log_info "Set password for $username:"
arch-chroot /mnt passwd "$username"

log_info "Configuring sudoers..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

# ============================================================================
# BOOTLOADER
# ============================================================================
log_phase "BOOTLOADER INSTALLATION"

log_info "Installing systemd-boot..."
arch-chroot /mnt bootctl install

# Get PARTUUID for root partition
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")

log_info "Creating boot entry (PARTUUID: $ROOT_PARTUUID)..."
cat > /mnt/boot/loader/entries/arch.conf << EOF
title Arch Linux
linux /vmlinuz-linux-zen
initrd /initramfs-linux-zen.img
options root=PARTUUID=$ROOT_PARTUUID rootflags=subvol=@ rw
EOF

log_info "Setting default boot entry..."
cat > /mnt/boot/loader/loader.conf << EOF
default arch.conf
timeout 3
EOF

log_info "✓ Bootloader configured"

# ============================================================================
# TTY AUTOLOGIN
# ============================================================================
log_phase "TTY AUTOLOGIN CONFIGURATION"

mkdir -p /mnt/etc/systemd/system/getty@tty1.service.d
cat > /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --noclear --autologin $username %I \$TERM
EOF

log_info "✓ TTY autologin configured for user: $username"

# ============================================================================
# SYSTEMD-INITRAMFS FOR NVIDIA
# ============================================================================
log_phase "KERNEL CONFIGURATION"

log_info "Configuring mkinitcpio for NVIDIA..."
cat > /mnt/etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /mnt/etc/mkinitcpio.conf

log_info "Rebuilding initramfs..."
arch-chroot /mnt mkinitcpio -P

log_info "✓ Kernel configuration complete"

# ============================================================================
# PACMAN HOOK FOR NVIDIA
# ============================================================================
log_phase "PACMAN HOOKS"

mkdir -p /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/nvidia.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-zen
Target = nvidia-open-dkms

[Action]
Description = Rebuilding initramfs after NVIDIA driver or kernel update...
When = PostTransaction
Exec = /usr/bin/mkinitcpio -P
NeedsTargets
EOF

log_info "✓ NVIDIA pacman hook installed"

# ============================================================================
# ENABLE NETWORKMANAGER
# ============================================================================
log_phase "SERVICE CONFIGURATION"

log_info "Enabling NetworkManager..."
arch-chroot /mnt systemctl enable NetworkManager

log_info "✓ Services configured"

# ============================================================================
# CLEANUP & UNMOUNT
# ============================================================================
log_phase "INSTALLATION COMPLETE"

log_info "Unmounting filesystems..."
umount -R /mnt

echo ""
log_info "✓ BASE SYSTEM INSTALLATION FINISHED"
echo ""
echo -e "${BOLD}NEXT STEPS:${NC}"
echo ""
echo "1. Reboot into the new system:"
echo "   sudo reboot"
echo ""
echo "2. After reboot (you will autologin to tty1), clone the dotfiles repo:"
echo "   cd /tmp"
echo "   git clone https://github.com/yourusername/myWorkspace.git"
echo "   cd myWorkspace"
echo ""
echo "3. Run the workstation bootstrap:"
echo "   ./bootstrap.sh"
echo ""
echo "4. After bootstrap completes, reboot again:"
echo "   sudo reboot"
echo ""
log_warn "The system will launch Hyprland automatically on next reboot."
echo ""
