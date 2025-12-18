#!/bin/bash
set -e

echo "=========================================="
echo "URL Shortener Full Deployment"
echo "=========================================="
echo ""

# Variables
GATEWAY="http://10.0.1.2:8080"
DOCKER_USER="masondrake"
PROXMOX_HOST="10.0.1.2"
PROXMOX_USER="root"

# Check if Docker is running
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo "✓ Docker is running"
echo ""

echo "=========================================="
echo "Part 1: Deploy OpenFaaS Functions"
echo "=========================================="
echo ""

# Build and push OpenFaaS functions
echo "Step 1: Building Docker images..."
echo "-----------------------------------"

# Build shorten-url function
echo "Building shorten-url..."
docker build -t shorten-url:latest -f openfaas/shorten-url/Dockerfile openfaas/shorten-url
docker tag shorten-url:latest $DOCKER_USER/shorten-url:latest

# Build redirect-url function
echo "Building redirect-url..."
docker build -t redirect-url:latest -f openfaas/redirect-url/Dockerfile openfaas/redirect-url
docker tag redirect-url:latest $DOCKER_USER/redirect-url:latest

# Build qrcode-wrapper function
echo "Building qrcode-wrapper..."
docker build -t qrcode-wrapper:latest -f openfaas/qrcode-wrapper/Dockerfile openfaas/qrcode-wrapper
docker tag qrcode-wrapper:latest $DOCKER_USER/qrcode-wrapper:latest

echo ""
echo "Step 2: Pushing images to Docker Hub..."
echo "-----------------------------------"
echo "Pushing $DOCKER_USER/shorten-url:latest..."
docker push $DOCKER_USER/shorten-url:latest

echo "Pushing $DOCKER_USER/redirect-url:latest..."
docker push $DOCKER_USER/redirect-url:latest

echo "Pushing $DOCKER_USER/qrcode-wrapper:latest..."
docker push $DOCKER_USER/qrcode-wrapper:latest

echo ""
echo "Step 3: Removing old deployments (if they exist)..."
echo "-----------------------------------"
faas-cli remove shorten-url --gateway $GATEWAY 2>/dev/null || echo "shorten-url not deployed yet"
faas-cli remove redirect-url --gateway $GATEWAY 2>/dev/null || echo "redirect-url not deployed yet"
faas-cli remove qrcode-wrapper --gateway $GATEWAY 2>/dev/null || echo "qrcode-wrapper not deployed yet"
faas-cli remove qrcode-go --gateway $GATEWAY 2>/dev/null || echo "qrcode-go not deployed yet"

# Wait for cleanup
echo "Waiting for cleanup..."
sleep 5

echo ""
echo "Step 4: Deploying functions..."
echo "-----------------------------------"
faas-cli deploy -f stack.yml --gateway $GATEWAY

echo ""
echo "Step 5: Verifying deployment..."
echo "-----------------------------------"
sleep 3
faas-cli list --gateway $GATEWAY

echo ""
echo "✓ OpenFaaS functions deployed"
echo ""

echo "=========================================="
echo "Part 2: Deploy Frontend"
echo "=========================================="
echo ""

# Deploy frontend to Proxmox container
echo "Deploying frontend to Proxmox container..."
echo "Running deployment script on $PROXMOX_HOST..."

# Copy frontend files to Proxmox
echo "Copying frontend files to Proxmox..."
ssh $PROXMOX_USER@$PROXMOX_HOST "mkdir -p /tmp/urlshortener-frontend"
scp -r frontend/* $PROXMOX_USER@$PROXMOX_HOST:/tmp/urlshortener-frontend/

# Run deployment on Proxmox
ssh $PROXMOX_USER@$PROXMOX_HOST << 'ENDSSH'
set -e

DEPLOY_DIR="/var/www/urlshortener"
SERVICE_NAME="urlshortener-frontend"

echo "Installing/Updating Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
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

echo "Setting ownership..."
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

echo "Reloading systemd and restarting service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "Waiting for service to start..."
sleep 3

echo "✓ Frontend deployed and running"
systemctl status "$SERVICE_NAME" --no-pager --lines=5

# Cleanup
rm -rf /tmp/urlshortener-frontend
ENDSSH

echo ""
echo "✓ Frontend deployed"
echo ""

echo "=========================================="
echo "Testing Deployment"
echo "=========================================="
echo ""

echo "1. Testing shorten-url..."
RESULT=$(echo '{"url":"https://github.com"}' | faas-cli invoke shorten-url --gateway $GATEWAY 2>&1)
if echo "$RESULT" | grep -q "short_url"; then
    echo "   ✓ shorten-url is working"
    HASH=$(echo "$RESULT" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4)
else
    echo "   ✗ shorten-url failed"
    HASH=""
fi

if [ -n "$HASH" ]; then
    echo ""
    echo "2. Testing redirect-url with hash: $HASH"
    REDIRECT_RESULT=$(curl -s "$GATEWAY/function/redirect-url?format=json" -X POST -d "$HASH")
    if echo "$REDIRECT_RESULT" | grep -q "original_url"; then
        echo "   ✓ redirect-url is working (JSON format)"
        ORIGINAL=$(echo "$REDIRECT_RESULT" | grep -o '"original_url":"[^"]*"' | cut -d'"' -f4)
        echo "   URL: $ORIGINAL"
    else
        echo "   ✗ redirect-url failed"
    fi
    
    echo ""
    echo "3. Testing redirect-url (HTTP redirect)..."
    if curl -s -I -X POST "$GATEWAY/function/redirect-url" -d "$HASH" | grep -q "301"; then
        echo "   ✓ redirect-url HTTP redirect is working"
    else
        echo "   ✗ redirect-url HTTP redirect failed"
    fi
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Services:"
echo "  - OpenFaaS Gateway: http://10.0.1.2:8080"
echo "  - Frontend: http://10.0.1.2:3000"
echo "  - Production URL: https://url.masondrake.dev"
echo ""
echo "Test the full flow:"
echo "  Visit: https://url.masondrake.dev"
echo "  Create a short URL and test the redirect"
echo ""
