#!/usr/bin/env bash
# install/07-services.sh - Enable system and user services

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

log_info "Enabling system and user services..."

# System-level services (require sudo)
log_info "Enabling system-level services..."

# Check for conflicting services and warn
if systemctl is-active --quiet pulseaudio; then
    log_warn "PulseAudio is running. This conflicts with PipeWire. Disabling..."
    sudo systemctl disable --now pulseaudio.service pulseaudio.socket 2>/dev/null || true
fi

# Enable required system services
SYSTEM_SERVICES=(
    "NetworkManager"
    "bluetooth"
    "docker"
    "fstrim.timer"
    "snapper-cleanup.timer"
)

for service in "${SYSTEM_SERVICES[@]}"; do
    if sudo systemctl enable "$service" &>/dev/null; then
        log_info "✓ Enabled: $service"
    else
        log_error "Failed to enable: $service"
        exit 1
    fi
done

# Do NOT enable snapper-timeline.timer (automatic snapshots disabled by policy)
log_info "✓ snapper-timeline.timer NOT enabled (manual snapshots only by policy)"

# User-level services (no sudo, run as current user)
log_info "Enabling user-level services..."

USERSERVICES=(
    "pipewire.service"
    "pipewire-pulse.service"
    "wireplumber.service"
)

for service in "${USERSERVICES[@]}"; do
    if systemctl --user enable "$service" &>/dev/null; then
        log_info "✓ Enabled (user): $service"
    else
        log_error "Failed to enable (user): $service"
        exit 1
    fi
done

# Start user services immediately
log_info "Starting user services..."
for service in "${USERSERVICES[@]}"; do
    systemctl --user start "$service"
done

# Verify services
log_info "Verifying service status..."

log_info "System services:"
for service in "${SYSTEM_SERVICES[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        log_info "  ✓ $service (enabled)"
    fi
done

log_info "User services:"
systemctl --user status --no-pager "${USERSERVICES[@]}" 2>&1 | grep "Active:" | sed 's/^/  /'

# Check audio
log_info "Verifying audio stack..."
if pactl info | grep -q "Server Name:.*PipeWire"; then
    log_info "✓ PipeWire is active"
else
    log_warn "PipeWire may not be active. It will start on next login."
fi

log_info "✓ Phase 07 complete: Services enabled and started"
log_info "Note: User services (PipeWire, WirePlumber) will restart on next login"
