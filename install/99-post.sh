#!/usr/bin/env bash
# install/99-post.sh - Final post-install setup

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

log_info "Running final post-install setup..."

# Change default shell to zsh
log_info "Changing default shell to zsh..."
if sudo chsh -s /usr/bin/zsh "$USER"; then
    log_info "✓ Default shell changed to zsh (takes effect on next login)"
else
    log_error "Failed to change shell"
    exit 1
fi

# Configure TTY autologin
log_info "Setting up TTY autologin on tty1..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
EOF

log_info "✓ TTY autologin configured for user: $USER"
log_info "  After reboot, tty1 will auto-login and launch Hyprland"

# Create necessary directories
mkdir -p ~/.config/wallpapers
mkdir -p ~/.local/share/fonts
mkdir -p ~/Pictures/Screenshots

log_info "✓ Created config directories"

# Write journald persistent log configuration
log_info "Configuring persistent journald logging..."
sudo mkdir -p /etc/systemd/journald.conf.d

sudo tee /etc/systemd/journald.conf.d/99-persistent.conf > /dev/null <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=2G
SystemKeepFree=500M
EOF

log_info "✓ Persistent journald logging configured"

# Summary
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo -e "${BOLD}POST-INSTALL SETUP COMPLETE${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo ""

log_info "IMPORTANT: Reboot the system to complete setup:"
echo ""
echo "    sudo reboot"
echo ""

log_info "After reboot, complete these manual setup steps:"
echo ""
echo "  1. Login: TTY autologin will activate"
echo "     → Hyprland will launch automatically"
echo ""
echo "  2. Open Bitwarden:"
echo "     → Sync your password vault"
echo "     → Log in to your accounts"
echo ""
echo "  3. Open Steam (if you have games):"
echo "     → Login with your Steam account"
echo "     → Let it sync your library"
echo ""
echo "  4. Install Proton-GE (optional):"
echo "     → Run: ProtonUp-Qt"
echo "     → Select and install Proton-GE version"
echo ""
echo "  5. Generate SSH keys (if needed):"
echo "     → ssh-keygen -t ed25519 -C 'your.email@example.com'"
echo "     → Upload to GitHub/GitLab if needed"
echo ""

log_warn "KEYBOARD SHORTCUTS:"
echo "  SUPER + / : Show keybinding cheatsheet"
echo "  SUPER + Return : Open terminal (kitty)"
echo "  SUPER + Space : Open application launcher (walker)"
echo "  SUPER + Shift + S : System update (creates snapshot)"
echo ""

log_info "DEBUGGING COMMANDS:"
echo "  # System logs"
echo "  journalctl -b -e     # current boot errors"
echo "  journalctl -u hyprland -n 50  # Hyprland logs"
echo ""
echo "  # GPU/Performance"
echo "  nvidia-smi           # NVIDIA GPU status"
echo "  btop                 # Process monitor"
echo "  nvtop                # NVIDIA temperature"
echo ""
echo "  # Snapshots"
echo "  snapper -c root list # View snapshots"
echo "  ~/.local/bin/update.sh  # System update (with snapshot)"
echo ""

log_info "Full documentation available in:"
echo "  ~/Codes/myWorkspace/docs/"
echo ""

log_info "✓ Phase 99 complete: Post-install setup finished"
