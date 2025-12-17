#!/bin/bash

# Setup development environment for URL Shortener on Proxmox
# Usage: ./scripts/setup-dev.sh

set -e

echo "========================================="
echo "URL Shortener - Development Setup"
echo "========================================="
echo ""

# Detect if running on Debian
IS_DEBIAN=false
if [ -f /etc/debian_version ]; then
    IS_DEBIAN=true
    echo "Detected Debian/Proxmox container"
fi

# Function to prompt for installation
prompt_install() {
    local package=$1
    local install_cmd=$2
    
    echo ""
    echo "Missing dependency: $package"
    
    if [ "$IS_DEBIAN" = true ]; then
        read -p "Would you like to install $package now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Installing $package..."
            eval "$install_cmd"
            echo "$package installed successfully!"
        else
            echo "Error: $package is required but not installed"
            exit 1
        fi
    else
        echo "Error: $package is not installed"
        echo "Install with: $install_cmd"
        exit 1
    fi
}

# Check prerequisites
echo "Checking prerequisites..."

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
    prompt_install "Docker" "curl -fsSL https://get.docker.com | sudo sh && sudo systemctl enable docker && sudo systemctl start docker"
fi

# Check Docker Compose
if ! command -v docker-compose >/dev/null 2>&1; then
    prompt_install "Docker Compose" "sudo apt-get update && sudo apt-get install -y docker-compose"
fi

# Check AWS CLI
if ! command -v aws >/dev/null 2>&1; then
    prompt_install "AWS CLI" "sudo apt-get update && sudo apt-get install -y awscli"
fi

# Check Node.js
if ! command -v node >/dev/null 2>&1; then
    prompt_install "Node.js" "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
fi

# Check npm (usually comes with Node.js, but check separately)
if ! command -v npm >/dev/null 2>&1; then
    prompt_install "npm" "sudo apt-get install -y npm"
fi

# Check Go
if ! command -v go >/dev/null 2>&1; then
    prompt_install "Go" "sudo apt-get update && sudo apt-get install -y golang-go"
fi

# Check faas-cli
if ! command -v faas-cli >/dev/null 2>&1; then
    prompt_install "OpenFaaS CLI (faas-cli)" "curl -sSL https://cli.openfaas.com | sudo sh"
fi

# Check curl (needed for other installations)
if ! command -v curl >/dev/null 2>&1; then
    prompt_install "curl" "sudo apt-get update && sudo apt-get install -y curl"
fi

echo ""
echo "All prerequisites found!"
echo ""

# Start DynamoDB Local
echo "Starting DynamoDB Local..."
docker-compose up -d

echo "Waiting for DynamoDB Local to be ready..."
sleep 5

# Initialize DynamoDB tables
echo ""
echo "Initializing DynamoDB tables..."
./scripts/init-dynamodb.sh

echo ""
echo "========================================="
echo "Development environment setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Deploy functions: ./scripts/deploy-all.sh"
echo "  2. Start frontend: cd frontend && npm run dev"
echo ""
echo "Services:"
echo "  - DynamoDB Local: http://localhost:8000"
echo "  - OpenFaaS Gateway: http://10.0.1.2:8080"
echo "  - Frontend: http://localhost:3000"
echo ""
