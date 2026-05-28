# ARCHITECTURE.md — Workstation System Design

## Executive Summary

This repository implements a **production-grade, reproducible Arch Linux workstation platform** for daily professional use. The system prioritizes **stability, recoverability, and reproducibility** over novelty. Every architectural decision is justified by operational necessity, not fashion.

**Target hardware:** ASUS laptop, Intel i5-10300H, NVIDIA GTX 1650 Mobile (Turing), 24 GB RAM, NVMe SSD.

**Primary operational goal:** After a clean Arch installation on BTRFS, running `./bootstrap.sh` deploys the full workstation automatically. The system survives monitor hotplugging, suspend/resume, kernel updates, NVIDIA driver updates, and system failure with rollback support.

---

## Design Principles

### 1. One Tool Per Responsibility

No overlapping daemons. No duplicate services. No redundant ecosystem layers.

| Responsibility | Tool | Why This Tool |
|---|---|---|
| **Network** | NetworkManager | Only officially supported network manager on Arch; handles dynamic switching (WiFi, ethernet, VPN); integrates with systemd; single responsibility. |
| **Audio** | PipeWire + WirePlumber | Modern audio server; replaces PulseAudio + JACK; low-latency; hardware acceleration capable; single audio stack. |
| **Bluetooth** | blueman | Lightweight GTK UI + daemon; no bloat; single BT manager. |
| **Containers** | Docker | Industry standard; single container runtime (not Podman). |
| **Shell plugins** | Manual `source` in .zshrc | Avoids framework complexity (oh-my-zsh, prezto). Explicit > implicit. |
| **Dotfile deployment** | GNU Stow | Minimal symlink manager; one deployment tool; no hidden generation. |
| **Wallpaper** | awww (swww) | Pure daemon; no framework; single responsibility. |
| **Screenshots** | grim + slurp | Minimal, composable tools (Unix philosophy). |
| **Idle/Lock** | hypridle + hyprlock | Hyprland native; single idle + single lock. |
| **Notifications** | mako | Minimal Wayland-native daemon; single notification system. |
| **Launcher** | walker | Minimal, fast TUI launcher; single entry point. |
| **Login** | TTY autologin (default) | No login manager complexity; direct kernel messages on failure; fewer moving parts. |

### 2. Stability Over Cleverness

- Proven, mature components only
- No experimental frameworks or ecosystem experiments
- No hidden automation magic
- All behavior is observable and debuggable
- Updates are explicit and manual (pre-snapshot, upgrade, post-snapshot)

### 3. Reproducibility

- Full specification in Git
- Idempotent install scripts
- No state outside the repo
- Clean Arch → full workstation in ~30 min via `bootstrap.sh`
- Hardware migration: clone repo, run on new hardware

### 4. Recoverability

- BTRFS snapshots (pre-update, manual)
- Clear rollback procedures documented in `docs/rollback.md`
- Emergency recovery via live USB → chroot (documented in `recovery/`)
- Persistent journald logs for debugging

### 5. Observability

- Direct TTY login (no login manager hiding failures)
- Explicit journald logging (persistent, 2GB limit)
- Useful shell aliases for log inspection
- Kernel messages visible on boot and failure
- Performance tools available: `btop`, `nvtop`, `lazygit`

---

## Filesystem Architecture

### BTRFS Layout (Canonical)

```
nvme0n1p1   1 GiB    FAT32  /boot     (EFI System Partition)
nvme0n1p2   rest     BTRFS  /         (5 subvolumes)
```

**Subvolumes:**
```
/                (subvol=@)              — root filesystem
/home            (subvol=@home)          — user home
/var/cache       (subvol=@cache)         — excluded from root snapshots
/var/log         (subvol=@log)           — excluded from root snapshots
/.snapshots      (subvol=@snapshots)     — snapper snapshot storage
```

**Mount options:**
```
rw,relatime,compress=zstd:3,space_cache=v2,subvol=@
```

- `compress=zstd:3` — level 3 is the best compression/CPU ratio for NVMe on modern CPUs
- `space_cache=v2` — stable, recommended free space cache
- No global `nodatacow` (CoW is desired for data integrity on root); only `chattr +C /var/lib/docker` for container layers

**Why separate @log and @cache?**
- These subvolumes are excluded from snapper's root snapshots by policy
- Prevents unbounded snapshot growth from log files
- Keeps snapshot size predictable

**Why separate @snapshots?**
- If snapshots lived inside @, snapper would snapshot snapshots recursively (infinite loop risk)
- Must be a real mounted subvolume, not a plain directory

### PARTUUID Stability

The systemd-boot entry uses `PARTUUID=...` (GPT partition identity), not filesystem UUID.

**Why this matters:** If the filesystem is reformatted with BTRFS later, the PARTUUID remains unchanged (it's the partition's identity in the GPT table). Only the filesystem UUID changes. Therefore:
- Boot entries survive filesystem reformat
- No manual boot entry updates after reformat
- Stable across hardware clones (same partition UUID on clone device)

---

## Boot & Kernel Strategy

### Bootloader: systemd-boot

**Why systemd-boot:**
- Minimal, part of systemd ecosystem
- EFI-native (no legacy boot complexity)
- Single responsibility: load kernel + initrd
- No GRUB complexity or bugs
- Easy to reason about

**Kernel: linux-zen**
- Optimized for desktop/gaming (scheduler optimizations)
- Lower latency than stock kernel
- Stable Arch package

**Kernel parameters (required):**
```
nvidia_drm.modeset=1 nvidia_drm.fbdev=1 quiet
```
- `nvidia_drm.modeset=1` — enable NVIDIA DRM modesetting (required for Wayland)
- `nvidia_drm.fbdev=1` — enable NVIDIA framebuffer console (required for TTY visibility post-Wayland exit, added in driver 545+)
- `quiet` — suppress boot messages (optional, but recommended for professional appearance)

---

## NVIDIA Architecture (Turing GPU)

### Hardware Setup

**GPU:** NVIDIA GTX 1650 Mobile / Max-Q (TU117M = Turing architecture)
**iGPU:** Intel UHD Graphics (CometLake-H)
**Hybrid mode:** Optimus (iGPU drives display, dGPU invoked per-app)

### Driver Decision: nvidia-open-dkms

**Why nvidia-open-dkms (not proprietary nvidia):**
- Turing+ is fully supported since driver 560
- Open kernel module integrates better with upstream DRM subsystem
- Survives kernel updates more reliably via DKMS
- Active upstream development (future-proof)
- Currently at version 595.71.05 (stable, mature)

**Why NOT optimus-manager:**
- No daemon complexity
- PRIME Render Offload is kernel-native
- Users invoke dGPU per-application via `prime-run` wrapper
- Simpler, fewer failure modes

### NVIDIA + Wayland Environment

**Kernel parameters:** (in systemd-boot entry)
```
nvidia_drm.modeset=1 nvidia_drm.fbdev=1
```

**modprobe.d (`/etc/modprobe.d/nvidia.conf`):**
```
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
```

**Why `NVreg_PreserveVideoMemoryAllocations=1`:**
Mandatory for suspend/resume on Wayland. Without it: black screen on wake. This is not optional.

**mkinitcpio MODULES:**
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

**Keep the kms hook:**
`nvidia-open-dkms` supports early KMS. Do NOT remove. This enables NVIDIA DRM from initramfs, allowing proper framebuffer console and mode setting.

**pacman hook for mkinitcpio:**
When `nvidia-open-dkms` or `linux-zen` updates, the initramfs must rebuild. The pacman hook at `/etc/pacman.d/hooks/nvidia.hook` triggers `mkinitcpio -P` automatically. Without this: kernel update + DKMS rebuild mismatch = unbootable system.

### PRIME Render Offload (No Daemon)

**Wrapper script:** `~/.local/bin/prime-run`
```bash
#!/bin/sh
__NV_PRIME_RENDER_OFFLOAD=1 \
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
exec "$@"
```

**Usage:**
```bash
prime-run steam                    # Launch Steam on dGPU
prime-run glxinfo | head -5        # Check dGPU rendering
```

**Steam integration:**
In Steam launch options for a game: `prime-run %command%`

### NVIDIA + Hyprland Environment Variables

In `configs/hypr/environment.conf`:
```
env = GBM_BACKEND,nvidia-drm              # Use NVIDIA's GBM implementation
env = __GLX_VENDOR_LIBRARY_NAME,nvidia    # GLX via NVIDIA library
env = LIBVA_DRIVER_NAME,nvidia            # VAAPI via NVIDIA driver (for Chrome)
env = NVD_BACKEND,direct                  # Nouveau backend disabled
```

These ensure Wayland rendering uses NVIDIA-native paths, not software fallbacks.

### Hardware Cursors (Default Enabled, Fallback Available)

**Default:** Hardware cursors enabled (Hyprland default behavior).

**Known issue:** On some NVIDIA + Wayland configurations, hardware cursor shape transitions (pointer → resize arrow) cause visible hitching.

**Fallback fix:** In `configs/hypr/appearance.conf`:
```ini
cursor {
    # Hardware cursors are enabled by default.
    # If you observe cursor flickering or hitching on NVIDIA, uncomment:
    # no_hardware_cursors = true
}
```

**Policy:** Users enable the fallback only if they observe the symptom. Newer nvidia-open-dkms versions have improved hardware cursor behavior. Forcing software cursors globally (when not needed) adds unnecessary latency.

---

## Audio Architecture: PipeWire + WirePlumber

**Why PipeWire:**
- Modern audio server (replacement for PulseAudio + JACK)
- Low-latency capable
- Hardware acceleration support
- Active Arch ecosystem (full stack integration)

**Stack:**
```
Applications (kitty, Firefox, games, etc.)
    ↓
PipeWire (audio server)
    ↓
WirePlumber (policy/routing manager)
    ↓
Hardware (ALSA drivers)
```

**Services (user-level):**
- `pipewire` — the server
- `pipewire-pulse` — PulseAudio compatibility layer (for apps expecting PulseAudio)
- `wireplumber` — policy manager (routing, switching, profile management)

**Why user-level NOT system-level:**
PipeWire's architecture is per-user. Enabling it system-wide causes conflicts. Systemd socket activation handles startup automatically when a user logs in.

**Verification:**
```bash
systemctl --user status pipewire
systemctl --user status wireplumber
pactl info | grep Server          # Should show "Server: PulseAudio (via PipeWire)"
```

---

## Desktop: Hyprland (Vanilla, No Framework)

### Architecture

**Hyprland** is the only window manager. NOT HyDE, NOT Hyde, NOT Hyprdots.

**Why vanilla Hyprland:**
- Upstream is fast-moving, stable
- No framework cruft or generated configs
- Direct control, observable behavior
- Community support is upstream, not framework-specific

### Configuration Modularization

Root file: `~/.config/hypr/hyprland.conf`

**Sourcing order (matters for variable availability):**
```
source = ~/.config/hypr/environment.conf   # FIRST — defines $mainMod, $TERMINAL
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/appearance.conf
source = ~/.config/hypr/keybinds.conf
source = ~/.config/hypr/rules.conf
source = ~/.config/hypr/autostart.conf     # LAST — uses all above vars
```

### Environment Variables

`environment.conf` declares:
```
$mainMod = SUPER
$TERMINAL = kitty
$BROWSER = google-chrome-stable
$EDITOR = code
$FILEMANAGER = thunar
```

Plus NVIDIA-specific vars (GBM_BACKEND, etc.) and Wayland session vars (XDG_SESSION_TYPE, etc.).

### Autostart Complexity: XDG Portal Race Condition

`autostart.conf` has intentional `sleep` delays:
```
exec-once = sleep 1 && /usr/lib/xdg-desktop-portal-hyprland &
exec-once = sleep 2 && /usr/lib/xdg-desktop-portal &
```

**Why the sleeps exist:**
Both portals starting simultaneously races. The Hyprland-specific portal must establish before the generic portal queries it. Without the sleeps: screen sharing is broken on first login.

**Why not use systemd socket activation instead?**
It requires the Hyprland session to properly register with systemd (via `systemctl --user import-environment`), which happens AFTER Hyprland is fully running. The sleeps are pragmatic and reliable.

---

## Login Flow: TTY Autologin (Default)

### Architecture

**Canonical (default) login:** TTY autologin on `tty1`

1. **Boot → getty on tty1**
2. **getty spawns autologin shell** (via systemd drop-in at `/etc/systemd/system/getty@tty1.service.d/autologin.conf`)
3. **User's zsh `.zprofile` executes**
4. **`.zprofile` checks:** `if [[ $(tty) == /dev/tty1 ]]; then exec Hyprland; fi`
5. **Hyprland launches directly into Wayland session**

**systemd drop-in:**
```ini
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I $TERM
```

**zsh `.zprofile`:**
```zsh
if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]]; then
    exec Hyprland
fi
```

### Why TTY Autologin (Canonical)

**Fewer moving parts:**
- No login manager (SDDM, GDM, LightDM) to configure, debug, or theme
- Direct kernel messages on failure (visible immediately)
- Simple shell logic (easy to understand, debug, modify)

**Better observability:**
- If system fails to boot, kernel messages are visible on TTY
- Login manager failure = no output, hard to debug
- Aligns with "production infrastructure" philosophy

**Alignment with philosophy:**
- Minimal, intentional, observable
- No hidden state in login manager
- Direct control via shell profile

### Optional Alternative: SDDM

For users who prefer a graphical login:

1. Install: `pacman -S sddm`
2. Enable: `sudo systemctl enable sddm`
3. Remove TTY autologin: comment out the getty drop-in
4. Edit `.zprofile` to not auto-launch Hyprland

Full instructions in `docs/installation.md`.

---

## Snapshot Strategy: Pre-Update + Manual

### Why NOT Automatic Timeline Snapshots

**Timeline snapshots = automatic hourly snapshots** via `snapper-timeline.timer`

**Problems:**
- Generate snapshot noise (too many, hard to manage)
- Consume storage (filesystem fills up unpredictably)
- Give false sense of security (snapshots are for rollback, not backup)

**Better approach:**
- **Pre-update snapshots only** (explicit, intentional)
- **Manual snapshots** for experimenting (before major changes)
- **No automatic timeline**

### Snapshot Policy

`/etc/snapper/configs/root`:
```ini
TIMELINE_CREATE="no"
TIMELINE_CLEANUP="no"
NUMBER_CLEANUP="yes"
NUMBER_LIMIT="20"
```

- `TIMELINE_CREATE="no"` — no automatic hourly snapshots
- `NUMBER_CLEANUP="yes"` — cleanup old snapshots by count
- `NUMBER_LIMIT="20"` — keep max 20 snapshots before removing oldest

### Update Workflow

Users run `~/.local/bin/update.sh` (NOT raw `pacman -Syu`):

1. `snapper create --type pre --description "pre-update: ..."`
2. `sudo pacman -Syu`
3. `snapper create --type post --pre-number <N>` (links to pre-update)
4. `yay -Syu --aur` (AUR packages)
5. Print: "Done. Run 'snapper -c root list' to view snapshots."

**snap-pac integration:**
The `snap-pac` pacman hooks ALSO fire during `pacman -Syu`, creating additional pre/post snapshots. This is intentional — dual snapshots provide redundancy. Do NOT disable snap-pac to avoid duplication; storage cost is trivial.

### Rollback Procedure

If a package breaks the system:

1. `snapper -c root list` — identify the post-update snapshot
2. Reboot, press spacebar in bootloader to edit kernel params
3. Change `subvol=@` to `subvol=@/.snapshots/<N>/snapshot` (replace N with snapshot number)
4. Boot into the snapshot (read-only)
5. Diagnose the problem
6. If rollback is needed:
   ```bash
   sudo btrfs subvolume set-default /.snapshots/<N>/snapshot /
   sudo reboot
   ```

Full procedure in `docs/rollback.md`.

---

## Package Management

### pacman (Official Arch Repos)

**Philosophy:** Lean base system, add only what's needed.

**Categories:**
- **Base/Kernel:** linux-zen, intel-ucode, base-devel
- **NVIDIA:** nvidia-open-dkms, nvidia-utils, libva-nvidia-driver
- **Desktop:** hyprland, xdg-portal-hyprland, wayland-utils
- **Audio:** pipewire, pipewire-alsa, wireplumber, pavucontrol
- **Terminal:** kitty, zsh, zsh-autosuggestions, zsh-syntax-highlighting, starship
- **Applications:** nano, code, google-chrome, bitwarden, age, thunar, yazi, etc.
- **Tools:** btop, nvtop, lazygit, fastfetch, duf, dust, bat, jq, ripgrep, fd, eza
- **Gaming:** steam, gamemode, mangohud, lib32-gamemode, lib32-mangohud
- **BTRFS:** btrfs-progs, snapper

### AUR (via yay)

**Philosophy:** Use AUR only for packages not in official repos.

**Packages:**
- **walker** — application launcher (AUR-only)
- **catppuccin-gtk-theme-mocha** — GTK theme (can also come from chaotic-aur)
- **proton-ge-custom-bin** — ProtonGE (via chaotic-aur)

### Chaotic-AUR Integration

The system assumes Chaotic-AUR is enabled in `pacman.conf` (already present on this system).

Some packages (like `proton-ge-custom-bin`) are sourced from chaotic-aur, which provides pre-built binaries and faster install than compiling from source.

---

## Theme: Catppuccin Mocha (Static)

### Why Catppuccin Mocha

- **Cohesive, professional aesthetic** — not garish
- **Available across all components** (GTK, Hyprland, kitty, starship, waybar, mako, etc.)
- **Static, hard-coded colors** — no runtime wallbash or dynamic generation
- **Aligned with philosophy** — one, clear choice; not a decision burden

### Color Policy

All colors are **hard-coded** in each component's config. No runtime wallbash, no dynamic color extraction from wallpaper.

**Deployed via:**
- GTK3/GTK4 theme package: `catppuccin-mocha-standard-blue-dark`
- Hyprland: rgba values in `appearance.conf`
- Waybar: CSS `@define-color` variables
- kitty: color block in `kitty.conf`
- Starship: Catppuccin Mocha preset
- etc.

### Consistency

All components use the same Catppuccin Mocha palette:
```
Foreground:   #CDD6F4
Background:   #1E1E2E
Accent:       #CBA6F7 (Mauve) / #89B4FA (Blue)
Surface:      #313244
```

---

## Secrets & Encryption

### Strategy

1. **Bitwarden** — password manager (local vault encrypted, synced to Bitwarden servers)
2. **age** — lightweight encryption tool for sensitive files

**Policy:**
- Passwords live in Bitwarden (not in dotfiles, not in configs)
- Sensitive shell scripts (if any) encrypted with age + key stored in Bitwarden
- SSH keys generated locally (not distributed)

### Git

Dotfiles repo contains NO secrets:
- No `.env` files with API keys
- No SSH keys
- No encrypted Bitwarden exports
- No credentials of any kind

Users manage their own secrets outside the dotfiles repo.

---

## Observability & Debugging

### journald Logging

Persistent logs enabled in `/etc/systemd/journald.conf.d/99-persistent.conf`:
```ini
[Journal]
Storage=persistent
SystemMaxUse=2G
SystemKeepFree=500M
```

**Access logs:**
```bash
journalctl -b              # current boot
journalctl -b -1           # previous boot
journalctl -u hyprland     # specific service
journalctl -p err          # errors only
```

### Shell Aliases for Debugging

In `configs/zsh/aliases.zsh`:
```bash
alias logs='journalctl -n 50 -f'
alias logerr='journalctl -p err -n 50'
alias syslog='sudo journalctl -n 50 -f'
```

### Performance Tools

- `btop` — interactive process monitor (CPU, memory, disk)
- `nvtop` — NVIDIA GPU monitor
- `lazygit` — git TUI (status, diffs, logs)
- `fastfetch` — quick system info

---

## Reliability Features

### Update Rollback

Every `pacman -Syu` is wrapped in pre/post snapshots. If a package breaks the system:
- Users can rollback via btrfs snapshot boot (no re-install needed)
- Clear procedures documented in `docs/rollback.md`

### Monitor Hotplugging

Hyprland handles monitor hotplug events dynamically:
- Disconnect external → Hyprland reorganizes workspaces (no restart needed)
- Reconnect → Hyprland re-adds monitor (workspace preservation)

Configured via `monitors.conf` with `preferred` + `auto` positioning (not hardcoded resolution/position).

### Suspend/Resume

PipeWire + NVreg_PreserveVideoMemoryAllocations ensure:
- Audio resumes correctly
- NVIDIA GPU resumes correctly (no black screen)
- iGPU continues working

### TTY Fallback

If Hyprland crashes or needs reboot:
- User can switch to TTY (Ctrl+Alt+F2 or Ctrl+Alt+F3)
- Direct shell access for debugging
- Kernel messages visible on fallback TTY
- Can reboot from TTY if needed

---

## Installation Phases

1. **00-pre.sh** — Verify Arch, install yay, check Chaotic-AUR
2. **01-btrfs-verify.sh** — Verify subvolumes exist
3. **02-bootloader.sh** — systemd-boot entries + kernel params
4. **03-nvidia.sh** — modprobe.d, mkinitcpio, pacman hook
5. **04-packages-pacman.sh** — pacman -S from packages/*.txt
6. **05-packages-aur.sh** — yay -S AUR packages
7. **06-snapper.sh** — snapper configs + snap-pac (CRITICAL ORDER)
8. **07-services.sh** — systemctl enable
9. **08-stow.sh** — Deploy dotfiles via GNU Stow
10. **09-gtk-theme.sh** — Apply GTK/icon/cursor theme
11. **10-docker.sh** — Docker group + daemon.json
12. **11-fonts.sh** — fc-cache
13. **99-post.sh** — chsh, TTY autologin setup, manual next steps

All scripts have `set -euo pipefail` for early failure detection.

---

## Deployment After Fresh Install

```bash
# On live USB
archinstall --offline     # (or manual partitioning + pacstrap)
# ... (ensure BTRFS with subvolumes, EFI partition, etc.)

# After boot into fresh Arch
git clone https://github.com/user/workstation ~/Codes/myWorkspace
cd ~/Codes/myWorkspace
./bootstrap.sh
# ... ~30 min
reboot

# First login
# TTY autologin → Hyprland launches automatically
```

Full procedure in `docs/installation.md`.

---

## Hardware Migration

To move to a new laptop:

1. Clone the dotfiles repo to the new machine
2. Fresh Arch install with BTRFS + same subvolumes
3. Run `bootstrap.sh`
4. All configs deploy identically
5. No re-provisioning needed

---

## Conclusion

This system is designed as **production personal infrastructure**, not a Linux rice. Every choice is justified by operational necessity. The result is a workstation that is:

- **Stable** — proven, mature components; no experimental frameworks
- **Recoverable** — BTRFS snapshots, rollback procedures, emergency recovery docs
- **Reproducible** — full spec in Git; idempotent bootstrap
- **Observable** — direct TTY access; persistent logs; debugging tools
- **Maintainable** — minimal, clear code; one tool per responsibility; explicit automation
