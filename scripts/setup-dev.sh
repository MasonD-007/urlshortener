#!/bin/bash

# Setup development environment for URL Shortener on Proxmox
# Usage: ./scripts/setup-dev.sh

set -e

echo "========================================="
echo "URL Shortener - Development Setup"
echo "========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

command -v docker >/dev/null 2>&1 || { echo "Error: docker is not installed"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Error: docker-compose is not installed"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is not installed"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Error: node.js is not installed"; exit 1; }
command -v go >/dev/null 2>&1 || { echo "Error: go is not installed"; exit 1; }
command -v faas-cli >/dev/null 2>&1 || { echo "Error: faas-cli is not installed. Install with: curl -sSL https://cli.openfaas.com | sudo sh"; exit 1; }

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
