# CLAUDE.md — AI Assistant Rules for Arch Workstation Dotfiles

## Overview

This repository contains production-grade Arch Linux workstation infrastructure. All code is intended for long-term daily professional use. Every decision prioritizes **stability, recoverability, and reproducibility** over novelty.

This file defines hard constraints for AI maintenance and future development.

---

## Fundamental Philosophy

**One tool per responsibility.** No overlapping daemons, duplicate services, or redundant ecosystem layers.

**No hidden automation magic.** All behavior is explicit, observable, and debuggable.

**Stability over cleverness.** Proven, mature components. No experimental frameworks or bleeding-edge ecosystem experiments.

---

## Critical Non-Negotiables

### DO NOT REINTRODUCE:
- **HyDE / Hyde / Hyprdots** — These were the previous framework. They are **completely removed** on fresh installs. References include: `$scrPath`, `hyde.conf`, `wallbash`, `hyde-launch.sh`, Hyde-specific Hyprland theme variables. If you find any of these, they are legacy and must be deleted.
- **oh-my-zsh, prezto, zinit, antigen** — Shell framework complexity is banned. zsh plugins source manually from `/usr/share/zsh/plugins/` in `.zshrc`.
- **GRUB bootloader** — systemd-boot is the only supported bootloader. Never suggest GRUB.
- **SDDM login manager (as default)** — TTY autologin (`getty@tty1.service.d/autologin.conf` + `~/.zprofile` exec Hyprland) is the canonical login flow. SDDM is documented as an optional alternative only.
- **ext4 filesystem** — BTRFS with subvolumes `@`, `@home`, `@cache`, `@log`, `@snapshots` is mandatory.
- **Automatic snapper timeline snapshots** — No `snapper-timeline.timer` enabled by default. Snapshots are pre-update (via `~/.local/bin/update.sh`) and manual only. The `snapper-cleanup.timer` is enabled to cap accumulated snapshots at `NUMBER_LIMIT=20`.
- **optimus-manager or bumblebee** — PRIME Render Offload only (no daemon). Binaries: `prime-run <app>`.
- **PulseAudio standalone or JACK standalone** — PipeWire + WirePlumber only. No two audio daemons.
- **Multiple network managers** — NetworkManager only. No wicd, connman, netctl, or wpa_supplicant standalone.
- **Multiple notification daemons** — mako only. (dunst exists in the current system — it is NOT part of this deployment and must not be re-enabled.)
- **swww package name** — Use `awww` (extra repo). The upstream project is github.com/LGFae/swww, but Arch renamed the package to `awww` to avoid conflicts. Binaries: `awww-daemon` and `awww img`. NOT `swww`.
- **Other launchers** — walker only (AUR). No rofi, wofi, bemenu, or other alternatives.
- **Other screenshot tools** — grim + slurp only. No flameshot, grimblast.
- **Other idle/lock tools** — hypridle + hyprlock only. No swayidle, waylock.
- **chezmoi, yadm, rcm** — GNU Stow only for config deployment.
- **NixOS, Home Manager** — None of these. Plain Arch + manual `pacman`/`yay` + Stow.

### Hardware Cursor Policy (NVIDIA):

**Default: Hardware cursors enabled.** (Hyprland default — no explicit override in `appearance.conf`).

**Known fallback issue:** On some NVIDIA + Wayland configurations, hardware cursor shape changes cause hitching (pointer → resize arrow). The fix is documented in `docs/nvidia.md`.

**In appearance.conf**, the cursor block is documented:
```ini
cursor {
    # Hardware cursors are enabled by default.
    # If you observe cursor flickering or hitching on NVIDIA, uncomment:
    # no_hardware_cursors = true
}
```

Do NOT hardcode `no_hardware_cursors = true` globally. Users enable it only if they observe the symptom.

### Google Chrome Configuration:

Chrome is the primary browser. It MUST run natively on Wayland with VAAPI hardware video decode enabled.

The `.desktop` file override is at `configs/chrome/.local/share/applications/google-chrome.desktop`. It includes:
```
--ozone-platform=wayland
--enable-features=VaapiVideoDecoder,VaapiVideoDecoderLinuxGL,VaapiIgnoreDriverChecks
--enable-accelerated-video-decode
--enable-gpu-rasterization
--ignore-gpu-blocklist
```

Verify Chrome is using Wayland + VAAPI by visiting `chrome://gpu` and checking:
- "Compositing: Enabled (and using GPU acceleration)"
- "Video Decode: Hardware accelerated"
- "VAAPI" present in capabilities list

### NVIDIA-Specific Rules (nvidia-open-dkms):

**Kernel parameters (systemd-boot entry, both required):**
```
nvidia_drm.modeset=1 nvidia_drm.fbdev=1
```

**modprobe.d (`/etc/modprobe.d/nvidia.conf`):**
```
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
```
`NVreg_PreserveVideoMemoryAllocations=1` is mandatory for suspend/resume. Without it: black screen on wake.

**mkinitcpio MODULES:**
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```
Keep `kms` hook. Do NOT remove. nvidia-open-dkms supports early KMS.

**After mkinitcpio.conf change:**
```bash
sudo mkinitcpio -P
```

**pacman hook** (`/etc/pacman.d/hooks/nvidia.hook`): Exists to rebuild initramfs when NVIDIA or linux-zen updates. Do NOT delete. It prevents unbootable systems after kernel updates.

**PRIME Render Offload wrapper** (`~/.local/bin/prime-run`):
```bash
#!/bin/sh
__NV_PRIME_RENDER_OFFLOAD=1 \
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
exec "$@"
```

Usage: `prime-run steam`, or in Steam launch options: `prime-run %command%`

---

## BTRFS-Specific Rules

**Filesystem requirement:** BTRFS with subvolumes `@`, `@home`, `@cache`, `@log`, `@snapshots`.

**Mount options:** `rw,relatime,compress=zstd:3,space_cache=v2,subvol=@<name>`

**Docker data root:** Run `chattr +C /var/lib/docker` AFTER /var/lib/docker is created. This disables CoW for container layers (prevents severe fragmentation).

**@snapshots subvolume:** Must be mounted at `/.snapshots` BEFORE snapper creates its first snapshot. If `/.snapshots` is a plain directory, snapper stores snapshots inside `@` recursively (wrong). Verify with `findmnt /.snapshots`.

**PARTUUID stability:** The systemd-boot entry uses `PARTUUID=...` (GPT partition identity), not filesystem UUID. PARTUUID survives a BTRFS reformat of the same partition. No need to update boot entry after reformatting the filesystem.

---

## Snapper Configuration

**Snapper config names:** `root` (for `/`) and `home` (for `/home`).

**Critical sequencing in install/06-snapper.sh:**
1. `pacman -S snapper`
2. `snapper -c root create-config /`
3. `snapper -c home create-config /home`
4. `pacman -S snap-pac`

If `snap-pac` is installed BEFORE the `root` snapper config exists, the pacman hooks fire but silently fail on every subsequent pacman transaction. This is a silent failure — the system appears to work, but pre-update snapshots never happen.

**Snapshot settings:**
```ini
TIMELINE_CREATE="no"
TIMELINE_CLEANUP="no"
NUMBER_CLEANUP="yes"
NUMBER_LIMIT="20"
NUMBER_LIMIT_IMPORTANT="5"
```

No timeline snapshots by default. Manual snapshots + pre-update snapshots only.

**Update workflow:** `~/.local/bin/update.sh` creates pre-update + post-update snapshots explicitly. `snapper-cleanup.timer` is enabled to cap accumulated snapshots.

---

## Repository Layout

```
myWorkspace/
├── CLAUDE.md, AGENTS.md, ARCHITECTURE.md, README.md   (AI-native docs)
├── bootstrap.sh                       (entry point orchestrator)
├── install/                           (install scripts in phase order)
├── packages/                          (package manifests by category)
├── configs/                           (stow packages — mirror home tree)
├── docs/                              (deployment, recovery, operations)
├── gaming/                            (gamemode, mangohud configs)
├── recovery/                          (emergency recovery procedures)
└── backups/                           (git-ignored, local snapshots)
```

## Stow Deployment

All dotfiles live under `configs/<package>/` mirroring the home directory exactly.

**Correct invocation:**
```bash
stow -t ~ configs/<package>
```

**WRONG invocation (do NOT use):**
```bash
stow -d configs <package>          # WRONG — stows INTO dotfiles dir, not home
```

First-run conflict resolution:
```bash
stow --adopt -t ~ configs/<package>    # pulls existing files into repo
git checkout -- .                      # restores canonical content
```

---

## Service Management

**System-level services to enable** (`sudo systemctl enable`):
- `NetworkManager`
- `bluetooth`
- `docker`
- `fstrim.timer`
- `snapper-cleanup.timer`

**NOT enabled by default:** `snapper-timeline.timer`

**User-level services** (`systemctl --user enable`):
- `pipewire`
- `pipewire-pulse`
- `wireplumber`

PipeWire is per-user by design. Do NOT enable system-wide — causes conflicts.

**Started by Hyprland exec-once (NOT systemd):**
- waybar
- mako
- hypridle

---

## Update Workflow

Users run `~/.local/bin/update.sh` (not raw `pacman -Syu`).

The script:
1. Creates pre-update snapshot with snapper
2. Runs `sudo pacman -Syu`
3. Creates post-update snapshot (linked to pre-update by pre-number)
4. Updates AUR via yay
5. Prints "Done. Run 'snapper -c root list' to view snapshots."

snap-pac hooks ALSO fire during pacman -Syu, creating additional snapshots. This is intentional — dual snapshots provide redundancy and are harmless. Do NOT disable snap-pac hooks to avoid duplication.

---

## Testing Changes

**Hyprland config changes:**
```bash
hyprctl reload          # non-destructive reload
hyprctl -j getoption general:border_size   # verify values took effect
```

**zsh config changes:**
```bash
zsh -i -c "exit"        # test startup in subshell
```

**systemd configs:**
```bash
sudo systemd-analyze verify /path/to/service.d/file.conf
```

---

## Safe Operations (No Approval Needed)

- Reading any file in the repo
- Running: `git status`, `git log`, `git diff`
- Read-only system checks: `pacman -Q`, `systemctl status`, `uname -r`, `/etc/fstab`
- Syntax validation: `hyprctl reload`, `zsh -i -c exit`

---

## Operations Requiring Explicit User Approval

- Editing `/etc/mkinitcpio.conf` and running `mkinitcpio -P` (system rebuild)
- Editing `/boot/loader/entries/` (bootloader)
- Creating/deleting snapper snapshots
- Running `docker` commands that modify containers or images
- Enabling/disabling any system-level services
- `pacman -S`, `yay -S` (package install)
- `pacman -R`, `yay -R` (package removal)
- `git push --force` or destructive git operations

---

## Forbidden Without Explicit User Command

- Deleting snapper snapshots
- Modifying `/boot/loader/entries/windows.conf` (Windows dual-boot entry)
- `pacman -Rns` or removing packages
- Changing BTRFS subvolume layout
- Enabling SDDM or any login manager (only TTY autologin by default)

---

## Git Commit Convention

Format: `<type>(<scope>): <description>`

**Types:** feat, fix, refactor, docs, chore

**Scope examples:** hypr, waybar, zsh, kitty, btrfs, nvidia, packages, theme, scripts, chrome

**Example:**
```
feat(hypr): add workspace overview keybind (SUPER+SHIFT+S)
feat(nvidia): enforce no_hardware_cursors fallback in appearance.conf
fix(zsh): ensure starship prompt is sourced last
docs(nvidia): document VAAPI verification for Chrome
```

---

## Theme System

**Theme:** Catppuccin Mocha

**Policy:** Static, hard-coded colors in each component. No runtime wallbash, no dynamic color extraction.

All colors are hex/rgba hard-coded in:
- `configs/hypr/appearance.conf` (borders, shadows)
- `configs/waybar/style.css` (CSS variables)
- `configs/kitty/kitty.conf` (color block)
- `configs/mako/config`
- `configs/starship/starship.toml`
- Plus GTK/Qt theme packages

---

## Troubleshooting Guide for AI

**System won't boot after kernel update:**
→ Check `/etc/pacman.d/hooks/nvidia.hook` exists and triggers on `linux-zen` update. Verify initramfs rebuilt. If not: boot live USB, chroot, run `sudo mkinitcpio -P`.

**PipeWire not working:**
→ Check `systemctl --user status pipewire` and `systemctl --user status wireplumber` are active. Check `/etc/systemd/user-default.target.wants/` symlinks exist. Check user XDG_RUNTIME_DIR is set. Never enable PipeWire system-wide.

**Screen sharing broken in Hyprland:**
→ Check `sleep 1` and `sleep 2` delays in `configs/hypr/autostart.conf` for portal startup. These sleeps are intentional (portal race condition workaround). Do NOT remove.

**Chrome not using Wayland:**
→ Check `chrome://gpu`: does it say "Wayland" under "Window Protocol"? Check `~/.local/share/applications/google-chrome.desktop` contains `--ozone-platform=wayland`. If not, the stow package didn't deploy correctly.

**NVIDIA black screen on wake from suspend:**
→ Check `NVreg_PreserveVideoMemoryAllocations=1` in `/etc/modprobe.d/nvidia.conf`. If missing: add and reload: `sudo modprobe -r nvidia && sudo modprobe nvidia`.

**Snapper not creating pre-update snapshots:**
→ Check `snapper -c root list` returns results. Check `~/.local/bin/update.sh` is executable. Check snap-pac hooks didn't swallow errors — verify `/etc/snapper/configs/root` exists BEFORE snap-pac was installed.

---

## AI Guardrails

When working on this repo, AI should:

1. **Always read AGENTS.md first.** It defines multi-agent coordination rules.
2. **Check CLAUDE.md against every change.** If a suggestion violates any rule here, reject it explicitly.
3. **Preserve git history.** Create new commits, never amend published commits. Create new branches for major work, never force-push.
4. **Test before committing.** Syntax-check configs, verify install scripts have `set -euo pipefail`, test shell configs in subshells.
5. **Document every decision.** If a non-obvious choice is made, add a comment to the code or a note in docs/.
6. **Avoid premature optimization.** Stability and readability > cleverness.
7. **When in doubt, ask the user.** Do not guess intent. Do not assume context.
