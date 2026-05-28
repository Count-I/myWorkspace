# BTRFS Filesystem Layout

## Canonical Layout

```
/dev/nvme0n1p1 (1 GiB FAT32) → /boot (EFI)
/dev/nvme0n1p2 (rest BTRFS) → 5 subvolumes:
  @ → /
  @home → /home
  @cache → /var/cache
  @log → /var/log
  @snapshots → /.snapshots
```

## Mount Options

All BTRFS subvolumes mounted with:
```
rw,relatime,compress=zstd:3,space_cache=v2
```

## Subvolume Purposes

- **@**: Root filesystem (snapshotted by snapper)
- **@home**: User home directory
- **@cache**: Package cache (excluded from snapshots, temporary)
- **@log**: System logs (excluded from snapshots, temporary)
- **@snapshots**: Snapper snapshot storage (must be separate subvolume)

## Docker Configuration

Disable copy-on-write for container layers:
```bash
sudo chattr +C /var/lib/docker
```

See ARCHITECTURE.md for rationale.
