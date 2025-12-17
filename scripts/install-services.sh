#!/bin/bash

# Install URL Shortener services on Debian/Proxmox container
# Run as root: sudo ./scripts/install-services.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

echo "========================================="
echo "URL Shortener - Service Installation"
echo "========================================="
echo ""

# Get the current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Project directory: $PROJECT_DIR"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    echo "Install with: apt-get update && apt-get install -y docker.io"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed"
    echo "Install with: curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs"
    exit 1
fi

echo "Prerequisites OK"
echo ""

# Create installation directory
echo "Creating installation directory..."
INSTALL_DIR="/opt/urlshortener"
mkdir -p "$INSTALL_DIR"

# Copy project files
echo "Copying project files to $INSTALL_DIR..."
rsync -av --exclude 'node_modules' --exclude '.next' --exclude '.git' \
    "$PROJECT_DIR/" "$INSTALL_DIR/"

echo "Files copied"
echo ""

# Create DynamoDB data directory
echo "Creating DynamoDB data directory..."
mkdir -p /var/lib/dynamodb-local
chown root:root /var/lib/dynamodb-local

# Build frontend
echo "Building frontend for production..."
cd "$INSTALL_DIR/frontend"

# Install dependencies
echo "Installing npm dependencies..."
npm install --production=false

# Build Next.js
echo "Building Next.js application..."
npm run build

echo "Frontend built successfully"
echo ""

# Set proper ownership for frontend
echo "Setting ownership for frontend files..."
useradd -r -s /bin/false www-data 2>/dev/null || true
chown -R www-data:www-data "$INSTALL_DIR/frontend"

# Install systemd services
echo "Installing systemd services..."

# Copy service files
cp "$INSTALL_DIR/services/dynamodb-local.service" /etc/systemd/system/
cp "$INSTALL_DIR/services/urlshortener-frontend.service" /etc/systemd/system/

# Update WorkingDirectory in service files to match installation directory
sed -i "s|/opt/urlshortener|$INSTALL_DIR|g" /etc/systemd/system/dynamodb-local.service
sed -i "s|/opt/urlshortener|$INSTALL_DIR|g" /etc/systemd/system/urlshortener-frontend.service

# Reload systemd
systemctl daemon-reload

echo "Services installed"
echo ""

# Pull DynamoDB Docker image
echo "Pulling DynamoDB Local Docker image..."
docker pull amazon/dynamodb-local:latest

echo ""

# Start services
echo "Starting services..."

# Start DynamoDB
systemctl enable dynamodb-local.service
systemctl start dynamodb-local.service

echo "Waiting for DynamoDB to be ready..."
sleep 5

# Initialize DynamoDB tables
echo "Initializing DynamoDB tables..."
cd "$INSTALL_DIR"
bash "$INSTALL_DIR/scripts/init-dynamodb.sh"

# Start frontend
systemctl enable urlshortener-frontend.service
systemctl start urlshortener-frontend.service

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Services installed and started:"
echo "  - dynamodb-local.service"
echo "  - urlshortener-frontend.service"
echo ""
echo "Service status:"
systemctl status dynamodb-local.service --no-pager -l || true
echo ""
systemctl status urlshortener-frontend.service --no-pager -l || true
echo ""
echo "Useful commands:"
echo "  systemctl status dynamodb-local"
echo "  systemctl status urlshortener-frontend"
echo "  systemctl restart dynamodb-local"
echo "  systemctl restart urlshortener-frontend"
echo "  journalctl -u dynamodb-local -f"
echo "  journalctl -u urlshortener-frontend -f"
echo ""
echo "Access the frontend at: http://10.0.1.2:3000"
echo "DynamoDB Local at: http://10.0.1.2:8000"
echo ""
