#!/usr/bin/env bash
#
# install.sh - Ultra-autonomous Arch workstation installer
#
# One script. Complete installation from ISO to fully configured system.
# Zero intermediate steps. Zero manual interventions.
#
# Usage: sudo bash install.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Exit on any error with context
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# ============================================================================
# SANITY CHECKS
# ============================================================================

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
fi

if ! grep -q "Arch" /etc/os-release 2>/dev/null; then
    log_error "This script requires Arch Linux."
    exit 1
fi

# ============================================================================
# INSTALL PREREQUISITES
# ============================================================================
log_phase "VERIFYING TOOLS"

for tool in fdisk wipefs git; do
    if ! command -v "$tool" &>/dev/null; then
        log_info "Installing missing tool: $tool..."
        pacman -Sy --noconfirm "$(
            [[ "$tool" == "fdisk" ]] && echo "util-linux" || echo "$tool"
        )" > /dev/null
    fi
done

log_info "✓ All tools available"

# ============================================================================
# DISK SELECTION
# ============================================================================
log_phase "DISK SELECTION"

mapfile -t DISKS < <(lsblk -nd -o NAME,SIZE,MODEL,TYPE | grep -E "^[a-z]" | grep -v "loop")

if [[ ${#DISKS[@]} -eq 0 ]]; then
    log_error "No disks detected."
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

while true; do
    read -p "Select disk (1-${#DISKS[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DISKS[@]} )); then
        TARGET_DISK="/dev/$(echo "${DISKS[$((choice-1))]}" | awk '{print $1}')"
        break
    fi
    log_error "Invalid selection."
done

TARGET_SIZE=$(echo "${DISKS[$((choice-1))]}" | awk '{print $2}')
echo ""
log_warn "⚠️  DESTRUCTIVE OPERATION"
log_warn "Target disk: $TARGET_DISK ($TARGET_SIZE)"
log_warn "THIS WILL ERASE ALL DATA"
echo ""
read -p "Type 'format ${TARGET_DISK##*/}' to proceed: " confirm

if [[ "$confirm" != "format ${TARGET_DISK##*/}" ]]; then
    log_error "Cancelled."
    exit 1
fi

log_info "Proceeding with installation on $TARGET_DISK"

# ============================================================================
# PARTITION & FORMAT
# ============================================================================
log_phase "PARTITIONING DISK"

log_warn "Unmounting all partitions from target disk..."
# Find all mount points for partitions of this disk and unmount them
MOUNTED=$(mount | grep "$TARGET_DISK" | awk '{print $3}')
if [[ -n "$MOUNTED" ]]; then
    while IFS= read -r mount_point; do
        log_info "  Unmounting $mount_point..."
        umount -f "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
    done <<< "$MOUNTED"
fi
sleep 1

log_warn "Wiping disk..."
wipefs -af "$TARGET_DISK" 2>/dev/null || true
sleep 1

# Partition with fdisk
fdisk "$TARGET_DISK" << FDISK_EOF
g
n
1

+512M
t
1
1
n
2


w
FDISK_EOF

# Detect partition naming
if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
    EFI_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

log_info "EFI: $EFI_PART | Root: $ROOT_PART"

# Wait for partitions
sleep 2
for i in {1..10}; do
    [[ -e "$EFI_PART" ]] && [[ -e "$ROOT_PART" ]] && break
    sleep 1
done

log_phase "FORMATTING"

log_info "Formatting EFI (FAT32)..."
if ! mkfs.vfat -F 32 "$EFI_PART"; then
    log_error "Failed to format EFI partition"
    exit 1
fi

log_info "Formatting root (BTRFS)..."
if ! mkfs.btrfs -f "$ROOT_PART"; then
    log_error "Failed to format BTRFS partition"
    exit 1
fi

# ============================================================================
# BTRFS SETUP
# ============================================================================
log_phase "BTRFS SUBVOLUMES"

log_info "Mounting BTRFS..."
if ! mount "$ROOT_PART" /mnt; then
    log_error "Failed to mount BTRFS root"
    exit 1
fi

log_info "Creating subvolumes..."
for subvol in @ @home @cache @log @snapshots; do
    if ! btrfs subvolume create /mnt/"$subvol"; then
        log_error "Failed to create subvolume: $subvol"
        umount /mnt
        exit 1
    fi
    log_info "  ✓ $subvol"
done

log_info "Verifying subvolumes..."
if ! btrfs subvolume list /mnt | grep -q "@"; then
    log_error "Subvolumes were not created properly"
    umount /mnt
    exit 1
fi

umount /mnt

log_info "Mounting subvolumes..."
BTRFS_OPTS="rw,relatime,compress=zstd:3,space_cache=v2"

# Mount root
if ! mount -o "$BTRFS_OPTS,subvol=@" "$ROOT_PART" /mnt; then
    log_error "Failed to mount root subvolume"
    exit 1
fi
log_info "  ✓ Mounted /"

# Create directories
mkdir -p /mnt/{home,var/cache,var/log,.snapshots,boot}

# Mount subvolumes
MOUNTS=(
    "/mnt/home:@home"
    "/mnt/var/cache:@cache"
    "/mnt/var/log:@log"
    "/mnt/.snapshots:@snapshots"
)

for mount_point_subvol in "${MOUNTS[@]}"; do
    IFS=: read -r mount_point subvol <<< "$mount_point_subvol"
    if ! mount -o "$BTRFS_OPTS,subvol=$subvol" "$ROOT_PART" "$mount_point"; then
        log_error "Failed to mount $subvol at $mount_point"
        umount -R /mnt
        exit 1
    fi
    log_info "  ✓ Mounted ${mount_point##*/} ($subvol)"
done

# Mount EFI
if ! mount "$EFI_PART" /mnt/boot; then
    log_error "Failed to mount EFI partition"
    umount -R /mnt
    exit 1
fi
log_info "  ✓ Mounted /boot (EFI)"

log_info "✓ BTRFS ready"

# ============================================================================
# PACSTRAP
# ============================================================================
log_phase "SYSTEM INSTALLATION (5-10 min)"

pacman -Sy
pacstrap -K /mnt base linux-zen linux-firmware btrfs-progs git curl wget \
    networkmanager sudo zsh stow > /dev/null

log_info "✓ Base system installed"

# ============================================================================
# CHROOT SETUP
# ============================================================================
log_phase "SYSTEM CONFIGURATION"

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime
arch-chroot /mnt hwclock --systohc

arch-chroot /mnt sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt bash -c 'echo "LANG=en_US.UTF-8" >> /etc/locale.conf'

echo "arch-workstation" > /mnt/etc/hostname

log_info "Creating user account..."
read -sp "Password for user 'archuser': " USER_PASS
echo
arch-chroot /mnt useradd -m -G wheel,docker -s /bin/zsh archuser
echo "archuser:$USER_PASS" | arch-chroot /mnt chpasswd

arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ============================================================================
# BOOTLOADER
# ============================================================================
log_phase "BOOTLOADER SETUP"

arch-chroot /mnt bootctl install

ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
cat > /mnt/boot/loader/entries/arch.conf << EOF
title Arch Linux
linux /vmlinuz-linux-zen
initrd /initramfs-linux-zen.img
options root=PARTUUID=$ROOT_PARTUUID rootflags=subvol=@ rw
EOF

cat > /mnt/boot/loader/loader.conf << EOF
default arch.conf
timeout 3
EOF

log_info "✓ Bootloader configured"

# ============================================================================
# TTY AUTOLOGIN
# ============================================================================
log_phase "TTY AUTOLOGIN"

mkdir -p /mnt/etc/systemd/system/getty@tty1.service.d
cat > /mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --noclear --autologin archuser %I \$TERM
EOF

log_info "✓ TTY autologin configured for 'archuser'"

# ============================================================================
# ENABLE SERVICES
# ============================================================================
log_phase "SERVICES"

arch-chroot /mnt systemctl enable NetworkManager
log_info "✓ NetworkManager enabled"

# ============================================================================
# COPY DOTFILES REPO TO HOME
# ============================================================================
log_phase "DOTFILES SETUP"

log_info "Copying repository to /home/archuser..."
mkdir -p /mnt/home/archuser

if ! cp -r "$SCRIPT_DIR" /mnt/home/archuser/myWorkspace; then
    log_warn "Could not copy repository. You can clone it after reboot."
else
    # Set correct ownership
    arch-chroot /mnt chown -R archuser:archuser /home/archuser/myWorkspace || true
    log_info "Repository ready at /home/archuser/myWorkspace"
fi

log_info "✓ Repository copied (bootstrap runs after reboot)"

# ============================================================================
# CLEANUP & FINISH
# ============================================================================
log_phase "INSTALLATION COMPLETE"

umount -R /mnt

echo ""
log_info "✓ SYSTEM READY FOR REBOOT"
echo ""
echo -e "${BOLD}NEXT STEPS:${NC}"
echo ""
echo "  1. Reboot: ${BOLD}sudo reboot${NC}"
echo ""
echo "  2. Login: TTY autologin as ${BOLD}archuser${NC} (password you entered)"
echo ""
echo "  3. System will boot straight to terminal (tty1)"
echo ""
echo -e "${YELLOW}Remember to:${NC}"
echo "  • Update git clone URL in this script before running on another machine"
echo "  • First boot will be slow (first-time package setup)"
echo ""
