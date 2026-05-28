# Arch Linux Workstation Infrastructure

Production-grade, reproducible Arch Linux workstation platform for daily professional use.

**After a clean Arch Linux installation, `./bootstrap.sh` deploys the full workstation automatically.**

---

## What This Is

- **Production infrastructure**, not a "rice"
- **TTY autologin + vanilla Hyprland**, no login manager by default
- **BTRFS with snapshots**, automatic pre-update snapshots + rollback
- **NVIDIA Turing GPU** with PRIME Render Offload
- **GNOME-integrated theming** (Catppuccin Mocha, static)
- **Minimal, observable deployment** — every tool has one responsibility
- **Fully documented** — recovery procedures, debugging, configuration

---

## Quick Start

### On Fresh Arch Installation

```bash
# Clone the repository
git clone https://github.com/user/workstation ~/Codes/myWorkspace
cd ~/Codes/myWorkspace

# Run the bootstrap script
./bootstrap.sh

# Reboot
reboot

# First login: TTY autologin → Hyprland launches automatically
```

**Installation time:** ~30 minutes (depending on network + AUR compile time).

### What bootstrap.sh Does

1. Verifies Arch Linux + installs yay (AUR helper)
2. Checks BTRFS subvolumes are present
3. Configures systemd-boot with NVIDIA kernel parameters
4. Installs NVIDIA drivers + mkinitcpio configuration
5. Installs all packages (pacman + AUR)
6. Configures snapper (BTRFS snapshots)
7. Enables system services (NetworkManager, PipeWire, Docker, etc.)
8. Deploys dotfiles via GNU Stow
9. Applies Catppuccin Mocha theme
10. Configures Docker, fonts, TTY autologin

---

## System Requirements

- **Arch Linux** (fresh or existing)
- **BTRFS filesystem** with subvolumes `@`, `@home`, `@cache`, `@log`, `@snapshots`
- **systemd-boot** bootloader (GRUB not supported)
- **NVIDIA GPU** (Turing or newer; GTX 1650 Mobile tested)
- **Intel iGPU** (for hybrid display configuration)

**Tested hardware:** ASUS laptop, Intel i5-10300H, NVIDIA GTX 1650 Mobile, 24 GB RAM, NVMe SSD

---

## Directory Structure

```
myWorkspace/
├── CLAUDE.md                 # AI maintenance rules
├── AGENTS.md                 # Multi-agent coordination
├── ARCHITECTURE.md           # System design rationale
├── README.md
├── bootstrap.sh              # Main deployment script
├── install/                  # Phase scripts (00-99)
├── packages/                 # Package manifests
├── configs/                  # Stow packages (dotfiles)
├── docs/                     # Deployment + recovery guides
├── gaming/                   # GameMode, MangoHUD configs
├── recovery/                 # Emergency procedures
└── backups/                  # Local snapshot storage
```

See `ARCHITECTURE.md` for the full design philosophy.

---

## Key Features

### Desktop Environment

- **Hyprland** (vanilla, no frameworks)
- **TTY autologin** (no login manager by default)
- **Dynamic workspaces** (SUPER+[1-9] switch, SUPER+SHIFT+[1-9] move window)
- **Workspace overview** (SUPER+SHIFT+S)
- **Floating windows**, tiling, pseudo-tiling, split layouts

### System Features

- **BTRFS snapshots** — pre-update automatic, manual, rollback-enabled
- **TTY fallback** — direct kernel messages on failure
- **PipeWire audio** — low-latency, hardware acceleration
- **NetworkManager** — dynamic network switching
- **Docker** — containerization with BTRFS nodatacow configured
- **Gaming support** — Steam, Proton-GE, GameMode, MangoHUD

### NVIDIA Integration

- **nvidia-open-dkms** — open kernel module (Turing+)
- **PRIME Render Offload** — per-app dGPU via `prime-run`
- **VAAPI video decode** — Chrome hardware acceleration
- **Suspend/resume support** — `NVreg_PreserveVideoMemoryAllocations=1`

### Terminal

- **kitty** — modern GPU-accelerated terminal
- **zsh** — with manual plugins (no oh-my-zsh)
- **starship** — minimal, fast prompt
- **Tools:** btop, nvtop, lazygit, fastfetch, eza, bat, ripgrep, fd

### Theme

- **Catppuccin Mocha** — cohesive, static, hard-coded colors
- **JetBrainsMono Nerd Font** — single font stack
- **Minimal wallpaper system** — user-managed, awww daemon

---

## Core Principles

### One Tool Per Responsibility

No overlapping daemons, duplicate services, or redundant frameworks:

| Responsibility | Tool |
|---|---|
| Network | NetworkManager |
| Audio | PipeWire + WirePlumber |
| Bluetooth | blueman |
| Containers | Docker |
| Dotfiles | GNU Stow |
| Wallpaper | awww (swww) |
| Notifications | mako |
| Launcher | walker |
| Shell plugins | Manual source (no oh-my-zsh) |

### Stability Over Novelty

- Proven, mature components only
- No experimental frameworks
- Explicit, observable behavior
- Manual, intentional updates (pre-snapshot → upgrade → post-snapshot)

### Recoverability

- BTRFS snapshots with clear rollback procedures (`docs/rollback.md`)
- TTY fallback for debugging
- Emergency recovery via live USB (`recovery/chroot-guide.md`)
- Persistent journald logging

---

## Documentation

- **`docs/installation.md`** — Full fresh install walkthrough (BTRFS setup, dual-boot options)
- **`docs/nvidia.md`** — NVIDIA driver rationale, PRIME, Wayland configuration
- **`docs/recovery.md`** — Recovery handbook for common failures
- **`docs/rollback.md`** — Snapper rollback procedures (boot into snapshot, promote to default)
- **`docs/update-strategy.md`** — Update workflow, snapshot retention, AUR notes
- **`docs/btrfs-layout.md`** — Partition design, subvolume policy, mount options
- **`ARCHITECTURE.md`** — System design philosophy and technical decisions
- **`CLAUDE.md`** — AI maintenance rules (non-negotiables for future updates)

---

## First Run After Bootstrap

1. **Reboot** after bootstrap completes
2. **Login:** TTY autologin → Hyprland launches (no password needed on tty1)
3. **Manual setup:**
   - Open Bitwarden, sync vault
   - Open Steam, set up library
   - Run `ProtonUp-Qt` to install Proton-GE (optional)
   - Generate SSH keys if needed

---

## Updating the System

```bash
~/.local/bin/update.sh
```

This script:
1. Creates a pre-update snapshot
2. Runs `sudo pacman -Syu`
3. Creates a post-update snapshot (linked to pre-update)
4. Updates AUR packages
5. Prints snapshot list for reference

If something breaks after an update, rollback is documented in `docs/rollback.md`.

---

## Performance Tips

- **GPU temperatures:** Check in waybar (CPU temp, GPU temp via hwmon)
- **Monitor latency:** Use `btop` for process monitoring
- **Build optimization:** `makepkg.conf` can be tuned per user
- **Game optimization:** Enable GameMode with `gamemode` binary
- **GPU offloading:** Use `prime-run` for dGPU tasks (Steam, rendering apps)

---

## Troubleshooting

### System won't boot
→ Boot live USB, see `recovery/chroot-guide.md` for recovery procedures

### Hyprland won't start
→ Check `/var/log/Xorg.0.log` or journalctl: `journalctl -b -1 -e`

### NVIDIA GPU not visible
→ Run `nvidia-smi`; check `lspci | grep -i nvidia`

### Audio not working
→ Run `pactl info` to verify PipeWire; check `systemctl --user status wireplumber`

### Chrome not using Wayland
→ Visit `chrome://gpu` and check "Window Protocol" row; verify `.desktop` file has `--ozone-platform=wayland`

### WiFi drops after suspend
→ Likely kernel issue; check `journalctl -b -e` for mt7921e warnings; see `docs/recovery.md`

See **`docs/recovery.md`** for more troubleshooting.

---

## Contributing & Maintenance

This repository is meant to be **forked and modified** for your own hardware.

- **Before you change CLAUDE.md, AGENTS.md, or ARCHITECTURE.md**, understand the rationale (read the full sections)
- **Test configuration changes** in a subshell or VM before committing
- **Keep the design simple** — add tools only if they solve a specific problem
- **Document decisions** in commit messages and in `docs/`

### For AI Assistants

Read **CLAUDE.md** and **AGENTS.md** before making changes. These files define hard constraints for this system.

---

## License

Personal infrastructure repository. Modify freely for your own use.

---

## Acknowledgments

- **Arch Linux** community for excellent documentation
- **Hyprland** maintainers for a modern Wayland compositor
- **Catppuccin** project for the cohesive color theme
- **GNU Stow** for elegant symlink management

---

## Quick Command Reference

```bash
# System info
fastfetch
uname -r
pacman -Q | wc -l

# Snapshots
snapper -c root list
snapper -c root create -d "experiment: testing new theme"
snapper -c root undochange 42..44   # undo changes between snapshots

# Update
~/.local/bin/update.sh

# GPU status
nvidia-smi
prime-run glxinfo | grep "OpenGL"

# Audio
pactl info
systemctl --user status pipewire

# Monitor performance
btop
nvtop

# Cheatsheet
SUPER+/   # show keybindings

# Logs
journalctl -b -e        # current boot, last 10 lines
journalctl -p err -n 50 # errors, last 50
```

---

## Contact & Support

Refer to `docs/recovery.md` and `recovery/` directory for recovery procedures. For NVIDIA-specific issues, see `docs/nvidia.md`.

For AI-assisted maintenance, see `CLAUDE.md` for context and rules.
