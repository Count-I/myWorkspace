#!/usr/bin/env bash
#
# bootstrap.sh - Main orchestrator for Arch workstation deployment
#
# This script runs all install phases in sequence.
# It must be executed after a fresh Arch install (with BTRFS subvolumes).
#
# Usage: ./bootstrap.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BOLD}${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${BOLD}${RED}[ERROR]${NC} $1"
}

log_phase() {
    echo ""
    echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
}

# Pre-flight checks
pre_flight() {
    log_phase "PRE-FLIGHT CHECKS"

    # Check we're on Arch
    if ! grep -q "^ID=arch$" /etc/os-release; then
        log_error "This script is designed for Arch Linux only."
        exit 1
    fi
    log_info "Running on Arch Linux ✓"

    # Check we're not root (scripts use sudo where needed)
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root. Use a regular user with sudo access."
        exit 1
    fi
    log_info "Running as unprivileged user ✓"

    # Check BTRFS subvolumes (informative only - 01-btrfs-verify.sh will validate)
    if [[ ! -d /.snapshots ]]; then
        log_warn "/.snapshots directory not found."
        log_warn "Phase 01 (BTRFS Verification) will validate your filesystem setup."
    else
        log_info "BTRFS /.snapshots subvolume detected ✓"
    fi

    # Check systemd-boot (informative only)
    if [[ ! -d /boot/loader ]]; then
        log_warn "/boot/loader not found. systemd-boot may not be configured."
    else
        log_info "systemd-boot directory found ✓"
    fi
}

# Run each install phase
run_phase() {
    local phase_script="$SCRIPT_DIR/install/$1"
    local phase_name="$2"

    if [[ ! -f "$phase_script" ]]; then
        log_error "Phase script not found: $phase_script"
        exit 1
    fi

    log_phase "$phase_name"

    # Make script executable
    chmod +x "$phase_script"

    # Run the phase
    if ! bash "$phase_script"; then
        log_error "Phase failed: $phase_name"
        log_error "Debug the issue, then run: bash $phase_script"
        exit 1
    fi

    log_info "Phase completed: $phase_name ✓"
}

# Main bootstrap sequence
main() {
    log_info "Welcome to Arch Workstation Bootstrap"
    log_info "Repository: $SCRIPT_DIR"
    echo ""

    # Pre-flight
    pre_flight

    # Run all phases in order
    run_phase "00-pre.sh" "Phase 00: Pre-flight Setup"
    run_phase "01-btrfs-verify.sh" "Phase 01: BTRFS Verification"
    run_phase "02-bootloader.sh" "Phase 02: Bootloader Configuration"
    run_phase "03-nvidia.sh" "Phase 03: NVIDIA Driver Setup"
    run_phase "04-packages-pacman.sh" "Phase 04: Pacman Packages"
    run_phase "05-packages-aur.sh" "Phase 05: AUR Packages"
    run_phase "06-snapper.sh" "Phase 06: Snapper Configuration"
    run_phase "07-services.sh" "Phase 07: Service Management"
    run_phase "08-stow.sh" "Phase 08: Dotfile Deployment"
    run_phase "09-gtk-theme.sh" "Phase 09: Theme Application"
    run_phase "10-docker.sh" "Phase 10: Docker Configuration"
    run_phase "11-fonts.sh" "Phase 11: Font Configuration"
    run_phase "99-post.sh" "Phase 99: Post-Install Setup"

    # Final summary
    log_phase "BOOTSTRAP COMPLETE"
    echo ""
    log_info "✓ Workstation deployment finished successfully!"
    echo ""
    log_warn "IMPORTANT: Reboot the system to complete the setup:"
    echo ""
    echo "    sudo reboot"
    echo ""
    log_info "After reboot:"
    echo "  • TTY autologin will launch Hyprland automatically on tty1"
    echo "  • Log in with your user credentials"
    echo "  • Manual setup steps are printed at the end of Phase 99"
    echo ""
}

# Run main
main "$@"
