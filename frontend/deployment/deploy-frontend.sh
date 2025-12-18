#!/bin/bash
set -e

echo "=========================================="
echo "URL Shortener Frontend Deployment"
echo "=========================================="

# Variables
DEPLOY_DIR="/var/www/urlshortener"
SERVICE_NAME="urlshortener-frontend"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "Please run as root (use sudo)"
   exit 1
fi

# Get the script directory and frontend directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"

# Install Node.js and npm if not present
echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js already installed: $(node --version)"
fi

# Create deployment directory
echo "Setting up deployment directory..."
mkdir -p "$DEPLOY_DIR"
rm -rf "$DEPLOY_DIR"/*

# Copy frontend files
echo "Copying frontend files from $FRONTEND_DIR..."
cp -r "$FRONTEND_DIR"/* "$DEPLOY_DIR/"
rm -rf "$DEPLOY_DIR/node_modules" "$DEPLOY_DIR/.next" "$DEPLOY_DIR/deployment"

# Change to deployment directory
cd "$DEPLOY_DIR"

# Install dependencies
echo "Installing dependencies..."
npm install

# Build the Next.js application
echo "Building Next.js application..."
npm run build

# Set ownership to www-data
echo "Setting ownership to www-data..."
chown -R www-data:www-data "$DEPLOY_DIR"

# Install systemd service
echo "Installing systemd service..."
cat > /etc/systemd/system/urlshortener-frontend.service << 'EOF'
[Unit]
Description=URL Shortener Frontend (Next.js)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/urlshortener
Environment="NODE_ENV=production"
Environment="PORT=3000"
Environment="NEXT_PUBLIC_API_GATEWAY=https://api.masondrake.dev"
Environment="NEXT_PUBLIC_QRCODE_FUNCTION=https://api.masondrake.dev/function/qrcode-wrapper"
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting $SERVICE_NAME service..."
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# Wait a moment for service to start
sleep 3

# Check service status
echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Service Status:"
systemctl status "$SERVICE_NAME" --no-pager --lines=10

echo ""
echo "Frontend is accessible at:"
echo "  - Local: http://localhost:3000"
echo "  - Network: http://10.0.1.2:3000"
echo "  - Production: https://url.masondrake.dev"
echo ""
echo "Useful commands:"
echo "  View logs: journalctl -u $SERVICE_NAME -f"
echo "  Restart service: systemctl restart $SERVICE_NAME"
echo "  Stop service: systemctl stop $SERVICE_NAME"
echo "  Check status: systemctl status $SERVICE_NAME"
echo ""
