#!/bin/bash
set -e

echo "=========================================="
echo "URL Shortener Full Deployment"
echo "=========================================="
echo ""

# Variables
GATEWAY="http://localhost:8080"
DOCKER_USER="masondrake"
DEPLOY_DIR="/var/www/urlshortener"
SERVICE_NAME="urlshortener-frontend"

# Check if Docker is running
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "⚠ Frontend deployment requires root privileges."
   echo "Please run: sudo ./deploy-all.sh"
   echo ""
   echo "Skipping frontend deployment..."
else
    echo "Deploying frontend locally..."
    
    # Get the current directory where the script is
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    FRONTEND_DIR="$SCRIPT_DIR/frontend"
    
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
    echo "Copying frontend files..."
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
    
    echo ""
    echo "✓ Frontend deployed"
    echo ""
    echo "Service Status:"
    systemctl status "$SERVICE_NAME" --no-pager --lines=5
fi

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
echo "Useful commands:"
echo "  View frontend logs: journalctl -u $SERVICE_NAME -f"
echo "  Restart frontend: systemctl restart $SERVICE_NAME"
echo "  View function logs: faas-cli logs <function-name>"
echo ""
echo "Test the full flow:"
echo "  Visit: https://url.masondrake.dev"
echo ""
