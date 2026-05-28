# Snapper Rollback Procedures

Complete guide to BTRFS snapshot rollback when updates break the system.

## Quick Reference

System broke after update → boot live USB → chroot → rollback.

```bash
# Inside chroot
snapper -c root list
# Find the problematic post-update snapshot number

# Boot into that snapshot (one-time)
# Modify kernel params: subvol=@/.snapshots/<N>/snapshot

# Or promote snapshot permanently:
btrfs subvolume set-default /.snapshots/<N>/snapshot /
reboot
```

## Detailed Steps

### 1. List Available Snapshots

```bash
snapper -c root list
```

Output example:
```
# | Type   | Pre # | Date               | User | Cleanup
--|--------|-------|-------------------|------|-------
0 | single |       | 2026-05-27 13:22  | root | timeline
1 | pre    |       | 2026-05-28 10:00  | root | number
2 | post   | 1     | 2026-05-28 10:05  | root | number   ← Problem
3 | pre    |       | 2026-05-28 11:15  | root | number
```

### 2. Identify the Problem Snapshot

Find the post-update snapshot that broke the system. It will have:
- `Type: post`
- Recent date
- Linked to a `pre` snapshot (Pre # column)

In the example above, snapshot `2` is the broken post-update snapshot.

### 3. Boot Into Snapshot (Non-Destructive Test)

**Option A: Temporary boot (one time, then back to current)**

On reboot, systemd-boot shows menu. Edit kernel params (press 'e'):

Change:
```
root=PARTUUID=... rootflags=subvol=@
```

To:
```
root=PARTUUID=... rootflags=subvol=@/.snapshots/2/snapshot
```

Press Ctrl+X to boot. Test the snapshot. On reboot, you're back to current.

### 4. Permanent Rollback

If the snapshot works and you want to keep it:

```bash
# Get the numeric snapshot ID from snapper list
# Example: rollback to snapshot 1 (pre-update, the "good" state)

# As root:
btrfs subvolume set-default /.snapshots/1/snapshot /
reboot
```

After reboot, you're running the snapshot as the new root (`@`).

### 5. Manual Verification After Rollback

```bash
# After rollback reboot
mount | grep " / "
# Should show: /dev/nvme0n1p2 on / type btrfs (...subvol=@/.snapshots/1/snapshot...)

ls /.snapshots/
# Snapshots are still visible and accessible

snapper -c root list
# Current snapshot shows as mounted
```

### 6. Undo Rollback (Return to Current)

If you rolled back and want to return to the newer version:

```bash
# List snapshots again
snapper -c root list

# Find the original root@ subvolume ID (usually 0 in btrfs)
btrfs subvolume list /
# Look for: ID 5 gen ... path @

# Set default back
btrfs subvolume set-default 5 /
reboot
```

## Advanced: Comparing Snapshots

```bash
# See what changed between two snapshots
snapper -c root diff 1..2

# Undo specific changes without full rollback
snapper -c root undochange 1..2 /etc/pacman.d/hooks
```

## What NOT to Do

❌ **Delete snapshots manually** — use `snapper delete`
❌ **Manually edit snapshot metadata** — use snapper commands
❌ **Move /.snapshots around** — it must be a BTRFS subvolume mount
❌ **Restore from a snapshot into @** — use `set-default` instead

## Emergency Recovery (System Won't Boot)

If the system doesn't boot at all:

1. Boot live USB (Arch ISO)
2. Mount BTRFS root: `mount /dev/nvme0n1p2 /mnt`
3. List snapshots: `btrfs subvolume list /mnt`
4. Set one as default: `btrfs subvolume set-default /.snapshots/1/snapshot /mnt`
5. Reboot (remove USB)

## Storage Impact

Each snapshot consumes storage only for **changed blocks**. With BTRFS CoW:
- Small snapshots: negligible (kilobytes for config changes)
- Typical package update: 100-500 MB
- snapper's `NUMBER_LIMIT=20` = keeps 20 snapshots max
- Auto-cleanup deletes oldest when limit reached

## Timeline Snapshots (Optional)

This system does NOT enable automatic timeline snapshots by default.

To enable hourly snapshots:
```bash
sudo systemctl enable snapper-timeline.timer
sudo systemctl start snapper-timeline.timer
```

Warning: This creates lots of snapshots and consumes storage. Only enable if needed.

## References

- Arch Wiki Snapper: https://wiki.archlinux.org/title/Snapper
- BTRFS Subvolume: https://wiki.archlinux.org/title/Btrfs#Subvolumes
