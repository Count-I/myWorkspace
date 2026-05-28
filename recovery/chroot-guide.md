# Chroot Recovery Guide

Exact commands to chroot into a broken Arch installation for repair.

## Mount Everything

```bash
# From live USB
mount -o subvol=@,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt
mount -o subvol=@home,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/home
mount -o subvol=@cache,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/var/cache
mount -o subvol=@log,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/var/log
mount -o subvol=@snapshots,compress=zstd:3,space_cache=v2 /dev/nvme0n1p2 /mnt/.snapshots

mount /dev/nvme0n1p1 /mnt/boot

# Additional mounts
mount -t proc /proc /mnt/proc
mount -t sysfs /sys /mnt/sys
mount -B /dev /mnt/dev
mount -B /run /mnt/run
```

## Chroot

```bash
arch-chroot /mnt
```

## Common Recovery Tasks

**Rebuild initramfs:**
```bash
mkinitcpio -P
```

**Reinstall kernel:**
```bash
pacman -S linux-zen
```

**Fix pacman database:**
```bash
pacman -Syu
pacman-db-upgrade
```

**Check NVIDIA driver:**
```bash
lspci | grep -i nvidia
pacman -Q nvidia-open-dkms
```

## Exit Chroot

```bash
exit
umount -R /mnt
reboot
```

## Rollback via Snapshot (Alternative)

Instead of fixing in chroot, rollback to a known-good snapshot:

```bash
# From live USB, list snapshots
mount /dev/nvme0n1p2 /mnt
btrfs subvolume list /mnt
ls /mnt/.snapshots/

# Set a snapshot as the new root
btrfs subvolume set-default /.snapshots/1/snapshot /mnt

umount /mnt
reboot
```

See docs/rollback.md for full snapshot procedures.
