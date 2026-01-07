#!/bin/bash
# Install x-link-watcher as a systemd service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_USER="${1:-obsidian}"
VAULT_DIR="${2:-/home/$SERVICE_USER/automation-vault}"

echo "Installing x-link-watcher..."
echo "  User: $SERVICE_USER"
echo "  Vault: $VAULT_DIR"

# Check dependencies
if ! command -v inotifywait &> /dev/null; then
    echo "Installing inotify-tools..."
    sudo apt-get update && sudo apt-get install -y inotify-tools
fi

# Make script executable
chmod +x "$SCRIPT_DIR/x-link-watcher.sh"

# Create systemd service
sudo tee /etc/systemd/system/x-link-watcher.service > /dev/null << EOF
[Unit]
Description=X Link Watcher for Obsidian
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Environment=VAULT_DIR=$VAULT_DIR
ExecStart=$SCRIPT_DIR/x-link-watcher.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable x-link-watcher
sudo systemctl start x-link-watcher

echo ""
echo "✓ Installed and started x-link-watcher service"
echo ""
echo "Commands:"
echo "  sudo systemctl status x-link-watcher   # Check status"
echo "  sudo journalctl -u x-link-watcher -f   # View logs"
echo "  sudo systemctl restart x-link-watcher  # Restart"
