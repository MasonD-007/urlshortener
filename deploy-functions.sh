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
GATEWAY="http://localhost:8080"
DOCKER_USER="masondrake"

echo ""
echo "Step 1: Building and tagging Docker images..."
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
echo "Step 3: Deploying functions..."
echo "-----------------------------------"
faas-cli deploy -f stack.yml --gateway $GATEWAY

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
echo "  - qrcode-wrapper: $GATEWAY/function/qrcode-wrapper"
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
