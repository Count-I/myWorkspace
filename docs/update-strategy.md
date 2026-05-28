# Update Strategy & Philosophy

## Why Manual Updates

This system uses **explicit, intentional updates** (not automatic).

Rationale:
- Every update is observable (pre-snapshot, change, post-snapshot)
- Failures can be rolled back immediately
- No surprise reboots mid-work
- Time zone doesn't affect update timing
- Clear causality (if broken, we know what changed)

## Update Procedure

```bash
~/.local/bin/update.sh
```

This script:
1. Creates pre-update snapshot
2. Runs `sudo pacman -Syu`
3. Creates post-update snapshot (linked to pre-update)
4. Updates AUR packages via `yay -Syu --aur`
5. Prints snapshot list

Total time: 5-30 minutes (depends on AUR compilation).

## snap-pac Integration

The `snap-pac` pacman hooks also create pre/post snapshots. You get dual snapshots:
- Manual snapshots from update.sh (with custom descriptions)
- Automatic snapshots from snap-pac (labeled with package names)

This is intentional redundancy. No duplication issues; storage cost is trivial.

## Kernel Updates

When `linux-zen` updates:
- Snapshot is created
- Kernel is installed
- DKMS rebuilds nvidia module
- Initramfs is rebuilt (via pacman hook)
- Snapshot is complete

If boot fails after kernel update:
- Boot live USB
- Rollback to pre-update snapshot
- Diagnose from snapshot
- Manually fix (e.g., rebuild initramfs)

## AUR Package Considerations

AUR packages may:
- Take time to compile
- Have build failures
- Require manual intervention

`yay -Syu --aur` will attempt to build and install all installed AUR packages.

If an AUR package breaks:
- Rollback to previous snapshot
- Uninstall the problematic package
- Try again with a fix

## Snapshot Retention Policy

Configured in `/etc/snapper/configs/root`:
```ini
NUMBER_CLEANUP="yes"
NUMBER_LIMIT="20"
NUMBER_LIMIT_IMPORTANT="5"
```

Keeps 20 recent snapshots, auto-deletes oldest when limit exceeded.
Prevents unbounded storage growth.

## Optional: Timeline Snapshots

To enable automatic hourly snapshots (NOT default):
```bash
sudo systemctl enable snapper-timeline.timer
```

Creates snapshots every hour automatically.

Disable (default):
```bash
sudo systemctl disable snapper-timeline.timer
```

## Monitoring Updates

After update, verify nothing broke:
```bash
# Check critical services
systemctl status NetworkManager docker
systemctl --user status pipewire

# Quick GPU check
nvidia-smi

# Launch Hyprland normally
# If something broke, rollback (see docs/rollback.md)
```

## Emergency: Downgrade a Package

If a specific package broke the system:
```bash
# Roll back via snapper first
# Then downgrade manually:
sudo pacman -U /var/cache/pacman/pkg/<package-oldversion>.pkg.tar.zst

# Or reinstall working version from snapshot
```

See Arch Wiki Downgrading Packages for details.
