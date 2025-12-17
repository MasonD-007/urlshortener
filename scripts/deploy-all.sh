#!/bin/bash

# Build and deploy all OpenFaaS functions
# Usage: ./scripts/deploy-all.sh

set -e

echo "========================================="
echo "URL Shortener - Deploy All Functions"
echo "========================================="
echo ""

# Check if OpenFaaS gateway is accessible
GATEWAY="http://10.0.1.2:8080"
echo "Checking OpenFaaS gateway at $GATEWAY..."
if ! curl -s -f "$GATEWAY/healthz" > /dev/null 2>&1; then
    echo "Warning: OpenFaaS gateway not accessible at $GATEWAY"
    echo "Make sure OpenFaaS is running and accessible."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

cd functions

# Pull OpenFaaS templates if not already present
if [ ! -d "template" ]; then
    echo "Pulling OpenFaaS templates..."
    faas-cli template pull
    echo ""
fi

# Build functions
echo "Building functions..."
faas-cli build -f stack.yml

echo ""
echo "Deploying functions..."
faas-cli deploy -f stack.yml --gateway $GATEWAY

echo ""
echo "========================================="
echo "Deployment complete!"
echo "========================================="
echo ""
echo "Functions deployed:"
echo "  - url-to-hash: $GATEWAY/function/url-to-hash"
echo "  - redirect: $GATEWAY/function/redirect"
echo ""
echo "Test with:"
echo "  curl -X POST $GATEWAY/function/url-to-hash -d '{\"url\":\"https://example.com\"}'"
echo ""
