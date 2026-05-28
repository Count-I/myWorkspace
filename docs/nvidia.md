# NVIDIA Configuration Guide

## Driver Decision: nvidia-open-dkms

**Why open kernel module (not proprietary):**
- GTX 1650 Mobile (TU117M) = Turing, fully supported since driver 560
- Better upstream DRM integration (required for Wayland)
- Survives kernel updates via DKMS (critical for stability)
- Active upstream development (no EOL risk)
- Current version: 595.71.05+ (stable, mature)

## Critical Configuration

### Kernel Parameters

systemd-boot entry requires BOTH:
```
nvidia_drm.modeset=1   # DRM modesetting (required for Wayland)
nvidia_drm.fbdev=1     # Framebuffer console (added 545+, required for TTY)
```

See `/boot/loader/entries/arch-zen.conf`.

### modprobe.d Configuration

`/etc/modprobe.d/nvidia.conf`:
```
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
```

**`NVreg_PreserveVideoMemoryAllocations=1` is mandatory** for suspend/resume. Without it: black screen on wake from suspend.

### mkinitcpio

`/etc/mkinitcpio.conf` must include:
```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```

And `kms` hook must remain (nvidia-open-dkms supports early KMS).

After any change: `sudo mkinitcpio -P`

### pacman Hook

`/etc/pacman.d/hooks/nvidia.hook` automatically rebuilds initramfs when NVIDIA or kernel updates.

**Without this hook:** kernel update before DKMS rebuild = unbootable system.

## PRIME Render Offload (No Daemon)

dGPU invocation without optimus-manager:

```bash
~/.local/bin/prime-run <application>
```

Example:
```bash
prime-run steam
prime-run nvidia-smi
```

**In Steam launch options:** `prime-run %command%`

## Wayland Environment Variables

See `configs/hypr/environment.conf`:
```
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = LIBVA_DRIVER_NAME,nvidia
env = NVD_BACKEND,direct
```

These ensure Wayland rendering uses NVIDIA-native paths.

## Hardware Cursor Issue (Known Fallback)

**Default:** Hardware cursors enabled (Hyprland default).

**Known issue on some NVIDIA+Wayland:** Cursor shape transitions (pointer → resize arrow) cause visible hitching.

**Fallback fix** (in `configs/hypr/appearance.conf`):
```ini
cursor {
    # Uncomment if you observe cursor hitching:
    # no_hardware_cursors = true
}
```

Enable only if you observe the symptom. Newer drivers have improved this.

## Chrome/Browser: VAAPI Hardware Decode

Chrome is deployed with:
```
--ozone-platform=wayland
--enable-features=VaapiVideoDecoder,VaapiVideoDecoderLinuxGL,VaapiIgnoreDriverChecks
--enable-accelerated-video-decode
--enable-gpu-rasterization
--ignore-gpu-blocklist
```

**Verify VAAPI is active:**
```bash
google-chrome-stable --version
# Then open chrome://gpu and check:
# - Window Protocol: should say "Wayland"
# - Video Decode: should show "Hardware accelerated"
# - Check for "VAAPI" in capabilities
```

## Troubleshooting

**NVIDIA GPU not visible:**
```bash
lspci | grep -i nvidia       # Should show GTX 1650
nvidia-smi                   # Should show GPU and driver version
```

**Black screen on wake from suspend:**
→ Verify `NVreg_PreserveVideoMemoryAllocations=1` in `/etc/modprobe.d/nvidia.conf`
→ Run `sudo modprobe -r nvidia && sudo modprobe nvidia` to reload

**Hyprland won't start with NVIDIA:**
→ Check journalctl: `journalctl -b -1 -e | grep -i nvidia`
→ Verify kernel parameters in boot entry

**dGPU stays active (high power draw):**
→ Verify iGPU is default: `echo 'PCI_POWER_CONTROL_EXPLICIT_PM=1' | sudo tee /etc/modprobe.d/nvidia-pm.conf`

**Chrome not using Wayland:**
→ Check ~/.local/share/applications/google-chrome.desktop has `--ozone-platform=wayland`
→ Verify Chrome was deployed via stow: `which google-chrome` should show symlink or path from dotfiles

## References

- NVIDIA Open Kernel Module: https://github.com/NVIDIA/open-gpu-kernel-modules
- Arch Wiki NVIDIA: https://wiki.archlinux.org/title/NVIDIA
- PRIME Render Offload: https://wiki.archlinux.org/title/NVIDIA#PRIME_Render_Offload
