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

# Verify we're on Arch Linux
if ! grep -q "Arch" /etc/os-release 2>/dev/null; then
    log_error "This script must run from Arch ISO."
    exit 1
fi

# Verify we're running from a live ISO, not from the target system
RUNNING_DISK=$(df -P / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
log_info "Script is running from: $RUNNING_DISK"

# Common ISO mount points: loop devices, sr0, iso9660
if [[ ! "$RUNNING_DISK" =~ (loop|sr|iso|ram|tmpfs) ]]; then
    log_error "WARNING: Script appears to be running from a persistent disk: $RUNNING_DISK"
    log_error ""
    log_error "This script MUST be executed from Arch ISO (live environment), not from"
    log_error "an already-installed system on the target disk."
    log_error ""
    log_error "If you're in a VM:"
    log_error "  1. Boot the Arch ISO as a live environment"
    log_error "  2. Ensure internet is available: ping archlinux.org"
    log_error "  3. Clone the repo: git clone ... && cd myWorkspace"
    log_error "  4. Run: sudo bash arch-install.sh"
    log_error ""
    log_error "Your running filesystem: $RUNNING_DISK"
    exit 1
fi

log_info "✓ Running from live ISO (not from target disk)"

log_phase "ARCH LINUX INSTALLER"
echo ""
log_info "Ultra-autonomous installation for workstation deployment"
echo ""

# ============================================================================
# VERIFY REQUIRED TOOLS
# ============================================================================
log_phase "VERIFYING REQUIRED TOOLS"

REQUIRED_TOOLS=("fdisk" "wipefs" "partprobe" "mkfs.vfat" "mkfs.btrfs" "btrfs" "git")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    log_warn "Missing tools: ${MISSING_TOOLS[*]}"
    log_info "Installing missing packages..."
    pacman -Sy --noconfirm dosfstools btrfs-progs util-linux git
fi

log_info "✓ All required tools available"
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

# Unmount any existing partitions on the target disk
log_info "Unmounting any existing filesystems on $TARGET_DISK..."
for partition in "${TARGET_DISK}"*; do
    if mountpoint -q "$partition" 2>/dev/null; then
        log_warn "Unmounting $partition..."
        umount -f "$partition" 2>/dev/null || umount -l "$partition" 2>/dev/null || true
    fi
done

# Give the system time to release the disk
sleep 1

# Close any LUKS or LVM volumes
log_info "Checking for encrypted or logical volumes..."
if command -v lvchange &>/dev/null; then
    lvchange -an 2>/dev/null || true
fi
if command -v dmsetup &>/dev/null; then
    dmsetup remove_all 2>/dev/null || true
fi

# Wipe the disk completely
log_warn "Wiping disk completely..."
if ! wipefs -af "$TARGET_DISK" 2>/dev/null; then
    log_warn "wipefs failed, attempting dd..."
    dd if=/dev/zero of="$TARGET_DISK" bs=1M count=10 2>/dev/null || true
fi

# Wait for the disk to stabilize
sleep 2

# Reload partition table
log_info "Reloading partition table..."
if command -v partprobe &>/dev/null; then
    partprobe "$TARGET_DISK" 2>/dev/null || true
fi
if command -v sfdisk &>/dev/null; then
    sfdisk -R "$TARGET_DISK" 2>/dev/null || true
fi

# Detect partition names (sda1/sda2 vs nvme0n1p1/nvme0n1p2)
if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
    EFI_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

log_info "Creating GPT partition table..."
# Use fdisk with heredoc for non-interactive partitioning
if ! fdisk "$TARGET_DISK" << FDISK_EOF
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
then
    log_error "Failed to create partitions with fdisk. Retrying with sgdisk..."
    if command -v sgdisk &>/dev/null; then
        sgdisk -Z "$TARGET_DISK" 2>/dev/null || true
        sgdisk -n 1:2048:+512M -t 1:EF00 -n 2:0:0 -t 2:8300 "$TARGET_DISK" || {
            log_error "sgdisk also failed. Aborting."
            exit 1
        }
    else
        log_error "fdisk failed and sgdisk not available. Install gptfdisk or check disk."
        exit 1
    fi
fi

log_info "EFI partition: $EFI_PART"
log_info "Root partition: $ROOT_PART"

# Wait for kernel to recognize new partitions
log_info "Waiting for kernel to recognize new partitions..."
for i in {1..10}; do
    if [[ -e "$EFI_PART" ]] && [[ -e "$ROOT_PART" ]]; then
        log_info "Partitions detected on attempt $i"
        break
    fi
    log_warn "Waiting for partitions... ($i/10)"
    sleep 1
    partprobe "$TARGET_DISK" 2>/dev/null || true
done

if [[ ! -e "$EFI_PART" ]] || [[ ! -e "$ROOT_PART" ]]; then
    log_error "Partitions not detected after 10 seconds. This may indicate a kernel issue."
    log_error "Try rebooting or checking dmesg for errors."
    exit 1
fi

# ============================================================================
# FILESYSTEM CREATION
# ============================================================================
log_phase "FILESYSTEM CREATION"

# Unmount if already mounted from previous attempt
for path in /mnt/.snapshots /mnt/var/log /mnt/var/cache /mnt/home /mnt/boot /mnt; do
    if mountpoint -q "$path" 2>/dev/null; then
        umount -R "$path" 2>/dev/null || true
    fi
done

# Format EFI partition with retry
log_info "Creating FAT32 for EFI..."
RETRY_COUNT=0
MAX_RETRIES=3

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if mkfs.vfat -F 32 -n "ARCH_EFI" "$EFI_PART" 2>/dev/null; then
        log_info "✓ EFI partition formatted"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
            log_warn "EFI format failed (attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep 1
            # Force clean with dd to clear any old filesystem signatures
            dd if=/dev/zero of="$EFI_PART" bs=1M count=1 2>/dev/null || true
            sleep 1
        fi
    fi
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    log_error "Could not format EFI partition after $MAX_RETRIES attempts."
    log_error ""
    log_error "Debugging:"
    log_error "  mkfs.vfat -F 32 $EFI_PART"
    mkfs.vfat -F 32 "$EFI_PART" 2>&1 || true
    log_error ""
    log_error "  blockdev --getro $EFI_PART (should be 0)"
    blockdev --getro "$EFI_PART" || true
    exit 1
fi

# Format root partition with retry
log_info "Creating BTRFS for root..."
RETRY_COUNT=0

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if mkfs.btrfs -f "$ROOT_PART" 2>&1 | tee /tmp/btrfs-format.log; then
        log_info "✓ BTRFS partition formatted"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        log_warn "BTRFS format failed (attempt $RETRY_COUNT/$MAX_RETRIES)"
        cat /tmp/btrfs-format.log
        if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
            sleep 1
            wipefs -af "$ROOT_PART" 2>/dev/null || true
            dd if=/dev/zero of="$ROOT_PART" bs=1M count=10 2>/dev/null || true
            sleep 1
        fi
    fi
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    log_error "Could not format BTRFS partition after $MAX_RETRIES attempts."
    exit 1
fi

# Create BTRFS subvolumes with error checking
log_info "Creating BTRFS subvolumes..."
if ! mount "$ROOT_PART" /mnt; then
    log_error "Failed to mount $ROOT_PART at /mnt"
    exit 1
fi

# Verify BTRFS is actually mounted
if ! btrfs filesystem show /mnt &>/dev/null; then
    log_error "BTRFS filesystem not properly mounted at /mnt"
    log_error "Debugging info:"
    btrfs filesystem show "$ROOT_PART" || true
    umount /mnt 2>/dev/null || true
    exit 1
fi
log_info "✓ BTRFS filesystem verified at /mnt"

SUBVOLS=("@" "@home" "@cache" "@log" "@snapshots")
for subvol in "${SUBVOLS[@]}"; do
    log_info "Creating subvolume: $subvol..."
    if ! btrfs subvolume create /mnt/"$subvol"; then
        log_error "Failed to create subvolume: $subvol"
        log_error "Error output above ↑"
        umount /mnt 2>/dev/null || true
        exit 1
    fi
    log_info "  ✓ Created subvolume: $subvol"
done

log_info "Verifying subvolumes were created..."
if ! btrfs subvolume list /mnt; then
    log_error "Could not list subvolumes. They may not have been created."
    umount /mnt 2>/dev/null || true
    exit 1
fi

umount /mnt

# Mount subvolumes with comprehensive error checking
log_info "Mounting subvolumes..."
BTRFS_OPTS="rw,relatime,compress=zstd:3,space_cache=v2"

# Create mount point if needed
mkdir -p /mnt

# Mount root
if ! mount -o "$BTRFS_OPTS,subvol=@" "$ROOT_PART" /mnt; then
    log_error "Failed to mount root BTRFS subvolume"
    exit 1
fi
log_info "  ✓ Mounted: / (@)"

# Create directories for other mounts
mkdir -p /mnt/{home,var/cache,var/log,.snapshots,boot}

# Mount subvolumes
declare -a MOUNT_POINTS=(
    "home:@home:/mnt/home"
    "var/cache:@cache:/mnt/var/cache"
    "var/log:@log:/mnt/var/log"
    ".snapshots:@snapshots:/mnt/.snapshots"
)

for mount_spec in "${MOUNT_POINTS[@]}"; do
    IFS=: read -r path subvol mountpoint <<< "$mount_spec"
    if ! mount -o "$BTRFS_OPTS,subvol=$subvol" "$ROOT_PART" "$mountpoint"; then
        log_error "Failed to mount $subvol at $mountpoint"
        umount -R /mnt
        exit 1
    fi
    log_info "  ✓ Mounted: $path ($subvol)"
done

# Mount EFI partition
if ! mount "$EFI_PART" /mnt/boot; then
    log_error "Failed to mount EFI partition at /mnt/boot"
    umount -R /mnt
    exit 1
fi
log_info "  ✓ Mounted: /boot (EFI)"

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
