#!/usr/bin/env bash
# install/10-docker.sh - Configure Docker with BTRFS nodatacow

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BOLD}${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${BOLD}${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${BOLD}${RED}${NC} $1"; }

log_info "Configuring Docker..."

# Verify Docker is installed
if ! command -v docker &>/dev/null; then
    log_error "Docker not installed. Run install/04-packages-pacman.sh first."
    exit 1
fi

# Add user to docker group (for non-sudo docker commands)
log_info "Adding user to docker group..."
if id -nG "$USER" | grep -qw docker; then
    log_info "✓ User already in docker group"
else
    sudo usermod -aG docker "$USER"
    log_info "✓ User added to docker group"
    log_warn "Note: Group membership takes effect on next login"
fi

# Create Docker daemon configuration
log_info "Writing /etc/docker/daemon.json..."
sudo mkdir -p /etc/docker

# Check if daemon.json already exists
if [[ -f /etc/docker/daemon.json ]]; then
    log_warn "daemon.json already exists. Creating backup..."
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "insecure-registries": []
}
EOF

log_info "✓ Docker daemon configuration created"
log_info "  - Storage driver: overlay2 (recommended for BTRFS)"
log_info "  - Log driver: json-file (with rotation)"
log_info "  - Max log size: 10m per container"

# Disable CoW for Docker data directory (prevents fragmentation)
log_info "Disabling copy-on-write for Docker data directory..."
if [[ -d /var/lib/docker ]]; then
    if [[ $(stat -c %C /var/lib/docker | grep -c "\\+C") -gt 0 ]]; then
        log_info "✓ Docker data directory already has CoW disabled"
    else
        sudo chattr +C /var/lib/docker 2>/dev/null || \
            log_warn "Could not disable CoW (may not be BTRFS or insufficient permissions)"
    fi
else
    log_warn "Docker data directory does not exist yet (will be created on first Docker start)"
fi

# Restart Docker daemon to load new configuration
log_info "Restarting Docker daemon..."
sudo systemctl restart docker

# Wait for Docker to be ready
sleep 2

# Verify Docker is working
log_info "Verifying Docker installation..."
if docker run --rm hello-world > /dev/null 2>&1; then
    log_info "✓ Docker is functional"
else
    log_error "Docker test failed"
    exit 1
fi

log_info "✓ Phase 10 complete: Docker configured"
