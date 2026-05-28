# Installation Guide - Arch Linux Workstation

Complete fresh installation guide for the workstation infrastructure.

## Prerequisites

- Clean Arch Linux installation media (latest ISO)
- Target system: ASUS laptop with NVIDIA GTX 1650 Mobile (or compatible)
- 1+ GiB free space (recommended: 50 GiB+)
- Internet connectivity (wired preferred for installation)

## Phase 1: Base Installation (Before Bootstrap)

### Partition Strategy

**Canonical (recommended):**
```bash
# Boot into Arch ISO
# Assuming target drive is nvme0n1

# Create EFI partition
fdisk /dev/nvme0n1
# n → p → default size → default → t → 1 (EFI)
# w

# Create BTRFS partition  
# n → p → default size → default → default → w

# Format
mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.btrfs /dev/nvme0n1p2
```

### BTRFS Subvolume Setup

```bash
mount /dev/nvme0n1p2 /mnt

# Create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots

umount /mnt
```

### Mount for Chroot

```bash
# Mount with compression
mount -o subvol=@,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,var/cache,var/log,.snapshots}

mount -o subvol=@home,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/home
mount -o subvol=@cache,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/var/cache
mount -o subvol=@log,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/var/log
mount -o subvol=@snapshots,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/.snapshots

mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

### Arch Installation

```bash
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# Inside chroot
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc

echo "archhost" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts

# Uncomment en_US.UTF-8 in /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Install bootloader
pacman -S systemd

bootctl install
```

### systemd-boot Configuration (Manual)

```bash
# Inside chroot, create /boot/loader/loader.conf
cat > /boot/loader/loader.conf <<'EOF'
default arch-zen
timeout 4
console-mode 0
EOF

# Get root PARTUUID
ROOT_UUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p2)

# Create entry
cat > /boot/loader/entries/arch-zen.conf <<EOF
title   Arch Linux (linux-zen)
linux   /vmlinuz-linux-zen
initrd  /intel-ucode.img
initrd  /initramfs-linux-zen.img
options root=PARTUUID=$ROOT_UUID rw rootfstype=btrfs rootflags=subvol=@ \\
        nvidia_drm.modeset=1 nvidia_drm.fbdev=1 \\
        quiet
EOF
```

### Exit Chroot

```bash
exit
umount -R /mnt
reboot
```

## Phase 2: Bootstrap Deployment (After First Boot)

### First Login

```bash
# Log in as root (if set up during install) or with user account

# Clone the repository
git clone https://github.com/yourusername/workstation ~/Codes/myWorkspace
cd ~/Codes/myWorkspace

# Run bootstrap
./bootstrap.sh
```

The bootstrap will handle all subsequent setup. Upon completion, reboot.

## Phase 3: Post-Installation Setup

### First Login to Hyprland

After reboot, you'll see:
1. TTY1 with auto-login prompt
2. Hyprland launches automatically
3. Waybar appears at top (minimal)
4. Wallpaper displays

### Manual Post-Install Steps

**Open Bitwarden (credentials):**
```bash
bitwarden
# Sync your vault
# Log in to critical accounts
```

**Open Steam (gaming):**
```bash
steam
# Login, sync library
```

**Install Proton-GE (gaming):**
```bash
ProtonUp-Qt
# Select and install latest Proton-GE
```

**Generate SSH keys (if needed):**
```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub
# Upload to GitHub/GitLab
```

## Dual-Boot Preservation (Alternative)

If Windows is on a separate NVMe and you want to keep it:

```bash
# On live USB, identify drives
lsblk
# Example: nvme0n1 = Linux (to be wiped), nvme1n1 = Windows (preserve)

# Partition nvme0n1 as above
# Windows EFI already exists on nvme1n1p1 (DO NOT TOUCH)

# Modify /boot/loader/loader.conf to reference Windows
cat >> /boot/loader/entries/windows.conf <<'EOF'
title Windows 11
efi /EFI/Microsoft/Boot/bootmgfw.efi
EOF
```

Windows boot entry will be preserved and bootable.

## Troubleshooting

**Can't mount /.snapshots:**
→ Verify @snapshots subvolume exists: `btrfs subvolume list /`

**No NVIDIA driver after first boot:**
→ Check `lspci | grep -i nvidia`; if no output, GPU not detected

**Hyprland won't start:**
→ Check logs: `journalctl -b -1 -e | grep hypr`

**Time/locale issues:**
→ Verify: `date`, `locale`, `timedatectl`

See `docs/recovery.md` for more.
