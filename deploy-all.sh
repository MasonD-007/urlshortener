#!/bin/bash
set -e

echo "=========================================="
echo "URL Shortener Full Deployment"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo "✓ Docker is running"
echo ""

# Build and deploy OpenFaaS functions
echo "Building OpenFaaS functions..."
faas-cli build -f stack.yml

echo ""
echo "Deploying OpenFaaS functions..."
faas-cli deploy -f stack.yml

echo ""
echo "✓ OpenFaaS functions deployed"
echo ""

# Test the functions
echo "Testing deployed functions..."
echo ""

echo "1. Testing shorten-url..."
RESULT=$(echo '{"url":"https://github.com"}' | faas-cli invoke shorten-url 2>&1)
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
    REDIRECT_RESULT=$(curl -s "http://10.0.1.2:8080/function/redirect-url?format=json" -X POST -d "$HASH")
    if echo "$REDIRECT_RESULT" | grep -q "original_url"; then
        echo "   ✓ redirect-url is working (JSON format)"
        ORIGINAL=$(echo "$REDIRECT_RESULT" | grep -o '"original_url":"[^"]*"' | cut -d'"' -f4)
        echo "   URL: $ORIGINAL"
    else
        echo "   ✗ redirect-url failed"
    fi
    
    echo ""
    echo "3. Testing redirect-url (HTTP redirect)..."
    if curl -s -I -X POST "http://10.0.1.2:8080/function/redirect-url" -d "$HASH" | grep -q "301"; then
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
echo "Next steps:"
echo ""
echo "1. Deploy frontend on production server:"
echo "   ssh your-server"
echo "   cd /root/urlshortener/frontend"
echo "   npm run build"
echo "   systemctl restart urlshortener-frontend"
echo ""
echo "2. Test the full flow:"
echo "   Visit: https://url.masondrake.dev"
echo "   Create a short URL and test the redirect"
echo ""
