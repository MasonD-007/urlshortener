#!/bin/bash

# Build Docker images for OpenFaaS functions
# Usage: ./scripts/build-images.sh [docker-registry]

set -e

# Optional: Set your Docker registry (e.g., docker.io/yourusername or your-registry.com)
REGISTRY=${1:-""}

# If registry is provided, add trailing slash
if [ -n "$REGISTRY" ]; then
    REGISTRY="${REGISTRY}/"
fi

echo "========================================="
echo "Building Docker Images for OpenFaaS"
echo "========================================="
echo ""

# Build url-to-hash function
echo "Building url-to-hash..."
cd functions/url-to-hash
docker build -t ${REGISTRY}url-to-hash:latest .
echo "Built: ${REGISTRY}url-to-hash:latest"
echo ""

# Build redirect function
echo "Building redirect..."
cd ../redirect
docker build -t ${REGISTRY}redirect:latest .
echo "Built: ${REGISTRY}redirect:latest"
echo ""

cd ../..

echo "========================================="
echo "Build Complete!"
echo "========================================="
echo ""
echo "Images built:"
echo "  - ${REGISTRY}url-to-hash:latest"
echo "  - ${REGISTRY}redirect:latest"
echo ""

if [ -n "$REGISTRY" ]; then
    echo "To push images to registry:"
    echo "  docker push ${REGISTRY}url-to-hash:latest"
    echo "  docker push ${REGISTRY}redirect:latest"
    echo ""
fi

echo "To deploy to OpenFaaS, use the UI with these settings:"
echo ""
echo "Function: url-to-hash"
echo "  Docker image: ${REGISTRY}url-to-hash:latest"
echo "  Function name: url-to-hash"
echo "  Environment Variables:"
echo "    AWS_REGION=us-east-1"
echo "    AWS_ACCESS_KEY_ID=dummy"
echo "    AWS_SECRET_ACCESS_KEY=dummy"
echo "    DYNAMODB_ENDPOINT=http://10.0.1.2:8000"
echo "    DYNAMODB_TABLE=url_mappings"
echo "    COUNTER_TABLE=url_counter"
echo "    BASE_URL=http://10.0.1.2:8080"
echo "    QRCODE_FUNCTION=http://10.0.1.2:8080/function/qrcode-go"
echo ""
echo "Function: redirect"
echo "  Docker image: ${REGISTRY}redirect:latest"
echo "  Function name: redirect"
echo "  Environment Variables:"
echo "    AWS_REGION=us-east-1"
echo "    AWS_ACCESS_KEY_ID=dummy"
echo "    AWS_SECRET_ACCESS_KEY=dummy"
echo "    DYNAMODB_ENDPOINT=http://10.0.1.2:8000"
echo "    DYNAMODB_TABLE=url_mappings"
echo "    COUNTER_TABLE=url_counter"
echo ""
