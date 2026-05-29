# Ultra-Autonomous Arch Linux Installation Guide

This guide provides a complete, automated Arch Linux workstation setup from bootable ISO.

---

## Overview

The installation is split into **two stages**:

### Stage 1: `arch-install.sh` (from Arch ISO)
- Detects and partitions disk
- Creates BTRFS subvolumes
- Installs base Arch system
- Configures bootloader and services
- **Requires:** Arch ISO, internet, ~10 minutes

### Stage 2: `bootstrap.sh` (from installed system)
- Installs NVIDIA drivers
- Installs workstation packages (Hyprland, waybar, kitty, etc.)
- Configures Snapper snapshots
- Deploys dotfiles via Stow
- Installs and configures Docker
- **Requires:** ~20 minutes, internet

---

## Prerequisites

- Arch Linux ISO (latest from https://archlinux.org/download/)
- Internet connectivity
- Target disk with at least 50 GB free space
- **WARNING:** The target disk will be completely wiped

---

## Stage 1: Base System Installation

### Step 1: Boot Arch ISO

Create bootable USB and boot into Arch ISO:

```bash
# From another machine, write ISO to USB:
sudo dd if=archlinux-*.iso of=/dev/sdX bs=4M status=progress
# Replace sdX with your USB drive (e.g., sdb, sdc)
```

Boot the target machine from USB.

### Step 2: Connect to Internet

**WIRED connection (automatic):**
```bash
# Usually works automatically
ping archlinux.org
```

**WIRELESS connection:**
```bash
iwctl
# > device list
# > station <device> scan
# > station <device> get-networks
# > station <device> connect <SSID>
```

### Step 3: Clone the Repository

```bash
cd /tmp
git clone https://github.com/yourusername/myWorkspace.git
cd myWorkspace
```

### Step 4: Run the Installer

```bash
sudo bash arch-install.sh
```

The script will:

1. **Detect disks** — Shows all available disks with size/model
2. **Ask for selection** — You choose which disk to use
3. **Confirm wipe** — You must type a confirmation string (prevents accidents)
4. **Partition** — Creates EFI (512M) + BTRFS root partition
5. **Create subvolumes** — `@`, `@home`, `@cache`, `@log`, `@snapshots`
6. **Install base** — Runs pacstrap with linux-zen, git, curl, etc.
7. **Configure system** — Locale, timezone, hostname, user account
8. **Setup bootloader** — systemd-boot with NVIDIA kernel parameters
9. **Enable services** — NetworkManager auto-start

**Typical output:**
```
[INFO] Welcome to Arch Linux Installer
[INFO] Available disks:
  [1] /dev/sda | 1T | Samsung 870 EVO
  [2] /dev/nvme0n1 | 500G | WDC_PC SN850X

Select disk number (1-2): 1
[WARN] YOU ARE ABOUT TO WIPE: /dev/sda (1T)
Type 'wipe sda' to confirm: wipe sda
[INFO] Proceeding with installation on /dev/sda
...
[INFO] BASE SYSTEM INSTALLATION FINISHED
```

### Step 5: Reboot

```bash
sudo reboot
```

The system will reboot and autologin to the user you created (no login prompt).

---

## Stage 2: Workstation Configuration

After reboot, you're logged into a minimal Arch system. Now install the workstation environment.

### Step 1: Clone Repository Again

(If you didn't preserve /tmp)

```bash
cd /tmp
git clone https://github.com/yourusername/myWorkspace.git
cd myWorkspace
```

### Step 2: Run Bootstrap

```bash
./bootstrap.sh
```

The script will run 13 installation phases in sequence:

| Phase | Task |
|-------|------|
| 00 | Pre-flight setup (yay, base-devel, Chaotic-AUR keyring) |
| 01 | BTRFS verification |
| 02 | Bootloader verification |
| 03 | NVIDIA driver installation |
| 04 | Pacman packages (Hyprland, waybar, kitty, Chrome, etc.) |
| 05 | AUR packages (yay packages like walker, hyprland-git) |
| 06 | Snapper configuration |
| 07 | Service enablement (NetworkManager, PipeWire, Docker) |
| 08 | Dotfiles deployment via Stow |
| 09 | GTK theme application (Catppuccin Mocha) |
| 10 | Docker post-configuration |
| 11 | Font installation |
| 99 | Post-install checks |

**Typical duration:** 20-30 minutes (slower on first run, faster if packages cached)

### Step 3: Reboot for Hyprland

```bash
sudo reboot
```

On next reboot, the TTY autologin service will automatically launch Hyprland.

---

## Verification Checklist

After reboot, verify the installation:

```bash
# Check system is running on Hyprland
echo $XDG_SESSION_TYPE  # Should print "wayland"

# Check BTRFS subvolumes
findmnt -t btrfs  # Should show @, @home, @cache, @log, @snapshots

# Check services
systemctl --user status pipewire  # Should be active
systemctl status NetworkManager   # Should be active

# Check snapper
snapper -c root list   # Should show snapshots

# Check Hyprland config
hyprctl version  # Should print version info

# Test launcher
SUPER+D  # Should open walker launcher

# Test terminal
SUPER+ENTER  # Should open kitty terminal

# Test Chrome on Wayland
google-chrome &
# Visit chrome://gpu → should show "Window Protocol: wayland"
```

---

## Troubleshooting

### Installation fails during pacstrap

**Symptom:** Error downloading packages, checksum failures

**Solution:**
1. Check internet: `ping archlinux.org`
2. Update pacman keys: `sudo pacman-key --refresh-keys`
3. Try again: `sudo bash arch-install.sh`

### arch-install.sh doesn't detect disks

**Symptom:** "No disks detected" error

**Solution:**
1. The ISO may be running in UEFI mode but target requires BIOS
2. Try booting ISO in BIOS mode instead of UEFI
3. Or use a different ISO

### Bootstrap fails at phase 03 (NVIDIA)

**Symptom:** "NVIDIA driver installation failed"

**Solution:**
1. If not using NVIDIA, the script will warn but continue
2. Manually install later: `yay -S nvidia-open-dkms`
3. Run bootstrap again: `./bootstrap.sh`

### Hyprland won't start after reboot

**Symptom:** Stuck at login prompt or black screen

**Solution:**
```bash
# SSH into the machine from another system
ssh username@<ip-address>

# Check Hyprland startup
DISPLAY=:0 hyprctl version

# Check systemd-boot and kernel params
systemd-boot -p

# Verify root filesystem is BTRFS
df /
```

### Can't connect to WiFi after reboot

**Symptom:** NetworkManager not showing networks

**Solution:**
```bash
# Check NetworkManager is active
systemctl status NetworkManager

# Scan networks
nmcli dev wifi list

# Connect
nmcli dev wifi connect "SSID" password "PASSWORD"
```

### Snapper not creating snapshots

**Symptom:** `snapper -c root list` is empty

**Solution:**
```bash
# Check snapper configs exist
ls -la /etc/snapper/configs/

# Check snap-pac hook exists
cat /etc/pacman.d/hooks/snap-pac.hook

# Create manual snapshot
sudo snapper -c root create -d "manual test"

# Check again
sudo snapper -c root list
```

---

## What Gets Installed

### Base System (arch-install.sh)
- `linux-zen` kernel + `linux-firmware`
- `btrfs-progs` for filesystem tools
- `git`, `curl`, `wget`, `sudo`, `zsh`
- `NetworkManager` (enabled)
- `systemd-boot` bootloader

### Workstation (bootstrap.sh)

**Window Manager & Desktop:**
- `hyprland` (Wayland compositor)
- `waybar` (status bar)
- `mako` (notification daemon)
- `hypridle` + `hyprlock` (idle/lock)

**Terminal & Shells:**
- `kitty` (GPU-accelerated terminal)
- `zsh` (default shell)
- `starship` (prompt)

**Applications:**
- `google-chrome` (with Wayland + VAAPI)
- `neovim` (text editor)
- `thunar` (file manager)
- `okular` (PDF viewer)
- `mpv` (video player)

**Development:**
- `docker` (containerization)
- `git` (version control)
- `base-devel` (build tools)

**System Tools:**
- `snapper` + `snap-pac` (snapshots on pacman)
- `pipewire` + `wireplumber` (audio)
- `iwd` (WiFi)
- `nm-connection-editor` (network config)
- `gnome-system-monitor` (system stats)

**Theme & Fonts:**
- Catppuccin Mocha (colors)
- Noto Sans, Noto Color Emoji (fonts)
- Nerd Fonts (programming fonts)

---

## Daily Usage

### Update System

```bash
~/.local/bin/update.sh
```

This script:
1. Creates pre-update snapshot
2. Runs `pacman -Syu`
3. Updates AUR via yay
4. Creates post-update snapshot

### Take Snapshots

```bash
# Manual snapshot
sudo snapper -c root create -d "before big change"

# List snapshots
snapper -c root list

# Rollback to snapshot (if needed)
sudo btrfs subvolume snapshot -r /.snapshots/10/snapshot / /mnt/snapshot-restore
```

### Launch Games (NVIDIA)

```bash
# Run game with NVIDIA GPU
prime-run steam
# In Steam launch options: prime-run %command%
```

### Rebuild Hyprland Config

```bash
# Non-destructive reload
hyprctl reload

# Verify config changes took effect
hyprctl -j getoption general:border_size
```

---

## Advanced: Clean Reinstall

If you need to reinstall without losing data:

```bash
# On a running system, backup critical data
rsync -av /home/username /mnt/backup/

# Reboot to Arch ISO
sudo reboot

# Boot into ISO (you're still connected to internet)
cd /tmp
git clone https://github.com/yourusername/myWorkspace.git
cd myWorkspace

# Run arch-install.sh (it will wipe the disk)
sudo bash arch-install.sh

# After reboot, restore data
rsync -av /mnt/backup/username /home/
```

---

## Documentation

For detailed information:

- **CLAUDE.md** — AI maintenance guidelines
- **ARCHITECTURE.md** — System architecture
- **docs/nvidia.md** — NVIDIA-specific setup
- **docs/snapper.md** — Snapshot management
- **docs/gaming.md** — Gaming setup
- **configs/** — Dotfiles (mirror of home directory)
