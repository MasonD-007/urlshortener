#!/bin/bash
set -e

echo "=========================================="
echo "Caddy Configuration Deployment"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "Please run as root (use sudo)"
   exit 1
fi

# Variables
CADDYFILE_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Caddyfile"
CADDYFILE_DEST="/etc/caddy/Caddyfile"

# Check if Caddy is installed
echo "Checking if Caddy is installed..."
if ! command -v caddy &> /dev/null; then
    echo "❌ Caddy is not installed"
    echo ""
    echo "Installing Caddy..."
    apt-get update
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update
    apt-get install -y caddy
    echo "✓ Caddy installed"
else
    echo "✓ Caddy is already installed: $(caddy version)"
fi

# Create Caddy directory if it doesn't exist
echo "Setting up Caddy directories..."
mkdir -p /etc/caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy 2>/dev/null || chown -R www-data:www-data /var/log/caddy

echo "Backing up existing Caddyfile..."
if [ -f "$CADDYFILE_DEST" ]; then
    cp "$CADDYFILE_DEST" "$CADDYFILE_DEST.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✓ Backup created"
fi

echo "Installing new Caddyfile..."
cp "$CADDYFILE_SOURCE" "$CADDYFILE_DEST"

echo "Validating Caddy configuration..."
if caddy validate --config "$CADDYFILE_DEST"; then
    echo "✓ Configuration is valid"
else
    echo "❌ Configuration validation failed"
    echo "Restoring backup..."
    if [ -f "$CADDYFILE_DEST.backup."* ]; then
        cp "$CADDYFILE_DEST.backup."* "$CADDYFILE_DEST"
    fi
    exit 1
fi

echo "Reloading Caddy..."
if systemctl is-active --quiet caddy; then
    echo "Caddy is running, reloading configuration..."
    systemctl reload caddy || {
        echo "⚠ Reload failed, trying restart..."
        systemctl restart caddy
    }
else
    echo "Caddy is not running, starting it..."
    systemctl start caddy
fi

# Wait a moment for Caddy to start
sleep 2

# Check if Caddy started successfully
if systemctl is-active --quiet caddy; then
    echo "✓ Caddy is running"
else
    echo "❌ Caddy failed to start"
    echo ""
    echo "Checking logs..."
    journalctl -u caddy -n 20 --no-pager
    exit 1
fi

echo ""
echo "=========================================="
echo "Caddy Configuration Deployed!"
echo "=========================================="
echo ""
echo "Services:"
echo "  - url.masondrake.dev -> redirects + frontend"
echo "  - faas.masondrake.dev -> OpenFaaS gateway"
echo ""
echo "Check status: systemctl status caddy"
echo "View logs: journalctl -u caddy -f"
echo ""
