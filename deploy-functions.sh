#!/bin/bash
set -e

echo "=========================================="
echo "OpenFaaS Functions Deployment Script"
echo "=========================================="

# Check if running on the OpenFaaS server
if [ ! -f "stack.yml" ]; then
    echo "Error: stack.yml not found. Please run this script from the urlshortener directory."
    exit 1
fi

# Variables
GATEWAY="http://10.0.1.2:8080"

echo ""
echo "Step 1: Building Docker images..."
echo "-----------------------------------"

# Build shorten-url function
echo "Building shorten-url..."
docker build -t shorten-url:latest -f openfaas/shorten-url/Dockerfile openfaas/shorten-url

# Build redirect-url function
echo "Building redirect-url..."
docker build -t redirect-url:latest -f openfaas/redirect-url/Dockerfile openfaas/redirect-url

echo ""
echo "Step 2: Removing old deployments (if they exist)..."
echo "-----------------------------------"
faas-cli remove shorten-url --gateway $GATEWAY 2>/dev/null || echo "shorten-url not deployed yet"
faas-cli remove redirect-url --gateway $GATEWAY 2>/dev/null || echo "redirect-url not deployed yet"

# Wait for cleanup
echo "Waiting for cleanup..."
sleep 5

echo ""
echo "Step 3: Deploying functions..."
echo "-----------------------------------"
faas-cli deploy -f stack.yml --gateway $GATEWAY --skip-push

echo ""
echo "Step 4: Verifying deployment..."
echo "-----------------------------------"
sleep 3
faas-cli list --gateway $GATEWAY

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Functions deployed:"
echo "  - shorten-url: $GATEWAY/function/shorten-url"
echo "  - redirect-url: $GATEWAY/function/redirect-url"
echo ""
echo "Test the functions:"
echo "  curl -X POST $GATEWAY/function/shorten-url \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"url\": \"https://youtube.com\"}'"
echo ""
echo "View logs:"
echo "  faas-cli logs shorten-url --gateway $GATEWAY"
echo "  faas-cli logs redirect-url --gateway $GATEWAY"
echo ""
