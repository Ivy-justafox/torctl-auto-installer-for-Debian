#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Ensure running as root
if (( EUID != 0 )); then
  echo "This script must be run as root." >&2
  exit 1
fi

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo "Tor VPN 2.0 for Debian — starting installation"

# Update package lists and install packages
apt-get update
apt-get install -y --no-install-recommends tor macchanger secure-delete git

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$BUILD_DIR"

# Clone torctl and install files
git clone https://github.com/BlackArch/torctl ./

# Move service files to systemd and set permissions if present
if [ -d "service" ]; then
  install -d /etc/systemd/system
  for f in service/*; do
    install -m 644 "$f" /etc/systemd/system/ || true
  done
fi

# Install bash completion if present
if [ -d "bash-completion" ] && [ -f bash-completion/torctl ]; then
  install -d /usr/share/bash-completion/completions
  install -m 644 bash-completion/torctl /usr/share/bash-completion/completions/torctl
fi

# Patch torctl script safely and install
if [ -f torctl ]; then
  # remove or comment start_service iptables line if present
  sed -i.bak '/start_service iptables/ s/^/#/' torctl || true
  # adjust TOR_UID if needed
  sed -i.bak 's/TOR_UID="tor"/TOR_UID="debian-tor"/' torctl || true
  install -m 755 torctl /usr/local/bin/torctl
fi

# Reload systemd daemon so new units are recognized
systemctl daemon-reload || true

cat <<'EOF'

Installation complete.

Common commands:
  torctl --help                 # display list of commands
  torctl ip                     # find your IP address
  sudo torctl start             # start torctl and route traffic
  sudo torctl stop              # stop torctl
  torctl status                 # check torctl status
  sudo torctl chngid            # change Tor exit circuit
  sudo torctl chngmac           # change MAC address
  sudo torctl rvmac             # restore original MAC address
  sudo systemctl enable torctl-autostart.service   # start on boot
  sudo systemctl disable torctl-autostart.service  # remove from startup
  sudo systemctl enable torctl-autowipe.service    # enable auto memory wipe on shutdown
  sudo systemctl disable torctl-autowipe.service   # disable auto memory wipe

Notes:
- This script targets Debian-derived systems; do not use dnf on Debian.
- Review installed service units before enabling them.
EOF
