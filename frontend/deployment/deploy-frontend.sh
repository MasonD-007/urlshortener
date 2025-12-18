#!/bin/bash
set -e

echo "=========================================="
echo "URL Shortener Frontend Deployment"
echo "=========================================="

# Variables
PROXMOX_HOST="10.0.1.2"
PROXMOX_USER="root"
DEPLOY_DIR="/var/www/urlshortener"
SERVICE_NAME="urlshortener-frontend"

# Get the script directory and frontend directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"

echo "Deploying frontend from local machine to Proxmox container..."
echo ""

# Copy frontend files to Proxmox
echo "Step 1: Copying frontend files to Proxmox ($PROXMOX_HOST)..."
ssh $PROXMOX_USER@$PROXMOX_HOST "mkdir -p /tmp/urlshortener-frontend"
scp -r "$FRONTEND_DIR"/* $PROXMOX_USER@$PROXMOX_HOST:/tmp/urlshortener-frontend/

echo ""
echo "Step 2: Running deployment on Proxmox..."
echo "-----------------------------------"

# Run deployment on Proxmox
ssh $PROXMOX_USER@$PROXMOX_HOST << 'ENDSSH'
set -e

DEPLOY_DIR="/var/www/urlshortener"
SERVICE_NAME="urlshortener-frontend"

echo "Checking for Node.js..."
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js already installed: $(node --version)"
fi

echo "Setting up deployment directory..."
mkdir -p "$DEPLOY_DIR"
rm -rf "$DEPLOY_DIR"/*
cp -r /tmp/urlshortener-frontend/* "$DEPLOY_DIR/"
rm -rf "$DEPLOY_DIR/node_modules" "$DEPLOY_DIR/.next" "$DEPLOY_DIR/deployment"

cd "$DEPLOY_DIR"

echo "Installing dependencies..."
npm install

echo "Building Next.js application..."
npm run build

echo "Setting ownership to www-data..."
chown -R www-data:www-data "$DEPLOY_DIR"

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

echo "Reloading systemd..."
systemctl daemon-reload

echo "Enabling and starting $SERVICE_NAME service..."
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "Waiting for service to start..."
sleep 3

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Service Status:"
systemctl status "$SERVICE_NAME" --no-pager --lines=10

echo ""
echo "Cleaning up temporary files..."
rm -rf /tmp/urlshortener-frontend
ENDSSH

echo ""
echo "=========================================="
echo "Frontend Successfully Deployed!"
echo "=========================================="
echo ""
echo "Frontend is accessible at:"
echo "  - Local: http://10.0.1.2:3000"
echo "  - Production: https://url.masondrake.dev"
echo ""
echo "Useful commands (run on Proxmox via SSH):"
echo "  ssh $PROXMOX_USER@$PROXMOX_HOST"
echo "  View logs: journalctl -u $SERVICE_NAME -f"
echo "  Restart service: systemctl restart $SERVICE_NAME"
echo "  Stop service: systemctl stop $SERVICE_NAME"
echo "  Check status: systemctl status $SERVICE_NAME"
echo ""
