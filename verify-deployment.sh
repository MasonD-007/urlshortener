#!/bin/bash
set -e

echo "=========================================="
echo "URL Shortener Deployment Verification"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GATEWAY="http://10.0.1.2:8080"
DYNAMODB_ENDPOINT="http://10.0.1.2:8000"

echo "1. Checking DynamoDB..."
if curl -s "$DYNAMODB_ENDPOINT" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} DynamoDB is running at $DYNAMODB_ENDPOINT"
else
    echo -e "${RED}✗${NC} DynamoDB is NOT accessible at $DYNAMODB_ENDPOINT"
    echo "   Start with: docker-compose up -d"
fi
echo ""

echo "2. Checking OpenFaaS Gateway..."
if curl -s "$GATEWAY/healthz" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} OpenFaaS Gateway is running at $GATEWAY"
else
    echo -e "${RED}✗${NC} OpenFaaS Gateway is NOT accessible at $GATEWAY"
fi
echo ""

echo "3. Checking OpenFaaS Functions..."
echo ""
faas-cli list --gateway "$GATEWAY" 2>/dev/null || echo -e "${RED}✗${NC} Cannot list functions"
echo ""

echo "4. Testing shorten-url function..."
SHORTEN_RESULT=$(echo '{"url":"https://example.com/test"}' | faas-cli invoke shorten-url --gateway "$GATEWAY" 2>&1)
if echo "$SHORTEN_RESULT" | grep -q "short_url"; then
    echo -e "${GREEN}✓${NC} shorten-url function is working"
    HASH=$(echo "$SHORTEN_RESULT" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4)
    echo "   Created hash: $HASH"
else
    echo -e "${RED}✗${NC} shorten-url function failed"
    echo "   Response: $SHORTEN_RESULT"
    HASH=""
fi
echo ""

echo "5. Testing redirect-url function..."
if [ -n "$HASH" ]; then
    REDIRECT_RESULT=$(curl -s -i -X POST "$GATEWAY/function/redirect-url" -d "$HASH" 2>&1)
    if echo "$REDIRECT_RESULT" | grep -q "301 Moved Permanently"; then
        echo -e "${GREEN}✓${NC} redirect-url function is working"
        LOCATION=$(echo "$REDIRECT_RESULT" | grep "Location:" | cut -d' ' -f2 | tr -d '\r')
        echo "   Redirects to: $LOCATION"
        
        # Check CORS headers
        if echo "$REDIRECT_RESULT" | grep -q "Access-Control-Allow-Origin"; then
            echo -e "${GREEN}✓${NC} CORS headers are present"
        else
            echo -e "${YELLOW}⚠${NC}  CORS headers are missing"
        fi
    else
        echo -e "${RED}✗${NC} redirect-url function failed"
        echo "$REDIRECT_RESULT" | head -20
    fi
else
    echo -e "${YELLOW}⚠${NC}  Skipping redirect test (no hash available)"
fi
echo ""

echo "6. Testing qrcode-wrapper function..."
if [ -n "$HASH" ]; then
    QR_RESULT=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$GATEWAY/function/qrcode-wrapper" -d "https://url.masondrake.dev/$HASH" 2>&1)
    if [ "$QR_RESULT" = "200" ]; then
        echo -e "${GREEN}✓${NC} qrcode-wrapper function is working"
    else
        echo -e "${RED}✗${NC} qrcode-wrapper function failed (HTTP $QR_RESULT)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Skipping QR code test (no hash available)"
fi
echo ""

echo "7. Checking Frontend Files..."
FRONTEND_FILES=(
    "frontend/src/app/[hash]/page.tsx"
    "frontend/src/components/URLShortenerForm.tsx"
    "frontend/src/components/ResultDisplay.tsx"
)

for file in "${FRONTEND_FILES[@]}"; do
    if [ -f "$file" ]; then
        if grep -q "https://faas.masondrake.dev" "$file"; then
            echo -e "${GREEN}✓${NC} $file uses https://faas.masondrake.dev"
        else
            GATEWAY_URL=$(grep "NEXT_PUBLIC_API_GATEWAY" "$file" | grep -o 'https://[^"]*' | head -1)
            echo -e "${YELLOW}⚠${NC}  $file uses: $GATEWAY_URL"
        fi
    else
        echo -e "${RED}✗${NC} $file not found"
    fi
done
echo ""

echo "8. Checking Function Source Files..."
if [ -f "openfaas/redirect-url/server.py" ]; then
    echo -e "${GREEN}✓${NC} openfaas/redirect-url/server.py exists"
else
    echo -e "${RED}✗${NC} openfaas/redirect-url/server.py is missing"
fi

if [ -f "build/redirect-url/server.py" ]; then
    echo -e "${GREEN}✓${NC} build/redirect-url/server.py exists"
else
    echo -e "${RED}✗${NC} build/redirect-url/server.py is missing"
fi
echo ""

echo "=========================================="
echo "Deployment Status Summary"
echo "=========================================="
echo ""
echo -e "${YELLOW}To deploy updates:${NC}"
echo ""
echo "1. Deploy OpenFaaS functions:"
echo "   cd /Users/masondrake/gitwork/urlshortener"
echo "   faas-cli build -f stack.yml"
echo "   faas-cli deploy -f stack.yml"
echo ""
echo "2. Deploy Frontend (on production server):"
echo "   cd /Users/masondrake/gitwork/urlshortener/frontend/deployment"
echo "   sudo ./deploy-frontend.sh"
echo ""
echo -e "${YELLOW}To test the full flow:${NC}"
echo "   1. Visit: https://url.masondrake.dev"
echo "   2. Create a short URL"
echo "   3. Click the short URL to test redirect"
echo ""
