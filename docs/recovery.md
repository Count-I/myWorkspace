# System Recovery Handbook

## System Won't Boot

**Symptom:** systemd-boot menu appears, but no entry boots successfully.

1. Boot Arch ISO
2. Mount BTRFS root: `mount -o subvol=@ /dev/nvme0n1p2 /mnt`
3. Mount EFI: `mount /dev/nvme0n1p1 /mnt/boot`
4. Chroot: `arch-chroot /mnt`
5. Check logs: `journalctl -b -1 -e`
6. Fix the issue (e.g., reinstall kernel)
7. Exit and reboot

See recovery/chroot-guide.md for full chroot procedures.

## System Mostly Works But One Thing Broke

**Symptom:** Hyprland starts but no GPU, or audio doesn't work.

Use snapper rollback to the previous good state:
1. Boot live USB
2. Run: `btrfs subvolume set-default /.snapshots/<N>/snapshot /` (where N is a good snapshot)
3. Reboot
4. Diagnose the issue from the working snapshot
5. Return to current if needed

See docs/rollback.md for complete procedures.

## NVIDIA Issues

See docs/nvidia.md for GPU troubleshooting.

## Audio Not Working

Check PipeWire:
```bash
systemctl --user status pipewire wireplumber
pactl info | grep Server
```

Should show "PipeWire (via PulseAudio)" as Server Name.

## Display Issues (Monitors Not Detected)

Check Hyprland logs:
```bash
journalctl -u hyprland -n 50
```

Hyprland auto-detects monitors. Disconnect/reconnect monitors without restart.

## Full System Failure Recovery

See recovery/emergency-boot.md.
