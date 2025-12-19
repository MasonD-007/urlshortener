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
systemctl reload caddy

echo ""
echo "=========================================="
echo "Caddy Configuration Deployed!"
echo "=========================================="
echo ""
echo "Services:"
echo "  - url.masondrake.dev -> redirects + frontend"
echo "  - api.masondrake.dev -> OpenFaaS gateway"
echo ""
echo "Check status: systemctl status caddy"
echo "View logs: journalctl -u caddy -f"
echo ""
