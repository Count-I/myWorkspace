# Emergency Boot Recovery

Use when system doesn't boot into Hyprland at all.

## Prerequisites

- Arch Linux live USB (latest ISO)
- BTRFS tools installed on live system
- Network connectivity (optional but helpful)

## Recovery Procedure

1. **Boot live USB** (Ctrl+Alt+Delete if system hangs)

2. **Mount BTRFS root:**
   ```bash
   mount -o subvol=@ /dev/nvme0n1p2 /mnt
   ```

3. **Mount EFI:**
   ```bash
   mount /dev/nvme0n1p1 /mnt/boot
   ```

4. **Chroot:**
   ```bash
   arch-chroot /mnt
   ```

5. **Check logs:**
   ```bash
   journalctl -b -1 -e | tail -50
   ```

6. **Common Fixes:**

   - NVIDIA kernel mismatch: `mkinitcpio -P`
   - Pacman lock file: `rm /var/lib/pacman/db.lck`
   - Broken package: `pacman -Syu` (from live USB internet)

7. **Exit and reboot:**
   ```bash
   exit
   umount -R /mnt
   reboot
   ```

See recovery/chroot-guide.md for advanced procedures.
