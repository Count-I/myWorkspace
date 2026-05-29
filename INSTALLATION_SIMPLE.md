# Installation Guide

**One script. One command. Fully configured system.**

## Requirements

- Arch Linux ISO (bootable)
- Internet connection
- Target disk with 50 GB+ free space
- ~30-45 minutes

## Installation

### Step 1: Boot Arch ISO

**Physical Hardware:**
```bash
# Write ISO to USB
sudo dd if=archlinux-*.iso of=/dev/sdX bs=4M status=progress
```
Boot from USB.

**Virtual Machine (KVM/QEMU):**
```bash
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 8G \
  -cdrom archlinux-*.iso \
  -drive file=system.qcow2,format=qcow2 \
  -boot d
```

Wait for: `[root@archiso ~]#`

### Step 2: Connect to Internet

```bash
# Wired (automatic)
ping archlinux.org

# Wireless
iwctl
```

### Step 3: Run Installation

```bash
# Clone repo
cd /tmp
git clone https://github.com/user/myWorkspace.git
cd myWorkspace

# Start installation
sudo bash install.sh
```

The script will:
1. **Show available disks** → You choose target
2. **Ask for confirmation** → You confirm disk will be wiped
3. **Ask for password** → User account password
4. **Install everything** → No more prompts, just progress

### Step 4: Reboot

```bash
sudo reboot
```

System boots to TTY with autologin. Done.

## What Gets Installed

- **Arch Linux** with linux-zen kernel
- **BTRFS** with snapshots support
- **Base tools:** git, curl, wget, zsh, sudo
- **Networking:** NetworkManager
- **User account:** archuser (with sudo access)
- **Dotfiles:** Deployed via GNU Stow

After first reboot, you can optionally install:
- Hyprland (desktop environment)
- NVIDIA drivers
- Additional packages
- AUR packages

## Troubleshooting

### Script fails during installation

The script shows detailed error messages. Most common issues:
- Internet disconnected → reconnect with `iwctl` or `nmtui`
- Disk errors → try different disk
- Package download fails → wait and retry

If installation fails midway:
```bash
# Restart from beginning
sudo bash install.sh
```

The script cleans up previous attempts automatically.

### System won't boot after installation

1. Boot Arch ISO again
2. Mount filesystem: `mount /dev/vda2 /mnt && mount /dev/vda1 /mnt/boot`
3. Chroot: `arch-chroot /mnt`
4. Check bootloader: `bootctl status`
5. Rebuild if needed: `bootctl install`

### Forgot password

Boot Arch ISO, mount filesystem, use `arch-chroot` to reset password.

## Next Steps After Installation

Once system boots:

```bash
# Update everything
sudo pacman -Syu

# Install Hyprland (optional desktop)
sudo pacman -S hyprland waybar mako

# Clone your dotfiles if not already done
git clone <your-repo> ~/myWorkspace

# Deploy dotfiles
cd ~/myWorkspace
stow -t ~ configs/<package>

# Reboot to use new configuration
sudo reboot
```

## Notes

- TTY autologin is enabled (no login prompt on tty1)
- Default user: `archuser` (with sudo access)
- BTRFS compression enabled for performance
- Snapshots supported (install snapper for automatic snapshots)
- System is ready for development, gaming, production use

## Getting Help

- Check `/var/log/install.log` for detailed installation log
- Arch Wiki: https://wiki.archlinux.org/
- Community: Arch Linux IRC, forums
