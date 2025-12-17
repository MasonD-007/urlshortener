#!/bin/bash
set -e

echo "=========================================="
echo "Initializing DynamoDB Tables"
echo "=========================================="

# Configuration
ENDPOINT_URL="${DYNAMODB_ENDPOINT:-http://localhost:8000}"
REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${DYNAMODB_TABLE:-url_mappings}"

echo "Endpoint: $ENDPOINT_URL"
echo "Region: $REGION"
echo "Table Name: $TABLE_NAME"
echo ""

# Wait for DynamoDB to be ready
echo "Waiting for DynamoDB Local to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s "$ENDPOINT_URL" > /dev/null 2>&1; then
    echo "DynamoDB Local is ready!"
    break
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Attempt $RETRY_COUNT/$MAX_RETRIES: DynamoDB not ready yet, waiting..."
  sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: DynamoDB Local did not become ready in time."
  echo "Please ensure DynamoDB Local is running at $ENDPOINT_URL"
  exit 1
fi

echo ""

# Check if table already exists
echo "Checking if table '$TABLE_NAME' already exists..."
if aws dynamodb describe-table \
    --endpoint-url "$ENDPOINT_URL" \
    --table-name "$TABLE_NAME" \
    --region "$REGION" > /dev/null 2>&1; then
  echo "Table '$TABLE_NAME' already exists. Skipping creation."
  echo ""
  echo "To recreate the table, first delete it with:"
  echo "  aws dynamodb delete-table --endpoint-url $ENDPOINT_URL --table-name $TABLE_NAME --region $REGION"
  exit 0
fi

# Create the url_mappings table
echo "Creating table '$TABLE_NAME'..."
aws dynamodb create-table \
  --endpoint-url "$ENDPOINT_URL" \
  --table-name "$TABLE_NAME" \
  --attribute-definitions \
    AttributeName=hash,AttributeType=S \
  --key-schema \
    AttributeName=hash,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "=========================================="
echo "Table Creation Complete!"
echo "=========================================="
echo ""

# Verify table creation
echo "Verifying table..."
aws dynamodb describe-table \
  --endpoint-url "$ENDPOINT_URL" \
  --table-name "$TABLE_NAME" \
  --region "$REGION" \
  --query 'Table.[TableName,TableStatus,KeySchema]' \
  --output table

echo ""
echo "Table '$TABLE_NAME' has been successfully created!"
echo ""
echo "Table Schema:"
echo "  Primary Key: hash (String)"
echo "  Attributes: hash, original_url, created_at, click_count"
echo ""
echo "You can now test the table with:"
echo ""
echo "# Insert a test record:"
echo "aws dynamodb put-item \\"
echo "  --endpoint-url $ENDPOINT_URL \\"
echo "  --table-name $TABLE_NAME \\"
echo "  --item '{\"hash\":{\"S\":\"test1234\"},\"original_url\":{\"S\":\"https://example.com\"},\"created_at\":{\"S\":\"2024-01-01T00:00:00\"},\"click_count\":{\"N\":\"0\"}}' \\"
echo "  --region $REGION"
echo ""
echo "# Retrieve the test record:"
echo "aws dynamodb get-item \\"
echo "  --endpoint-url $ENDPOINT_URL \\"
echo "  --table-name $TABLE_NAME \\"
echo "  --key '{\"hash\":{\"S\":\"test1234\"}}' \\"
echo "  --region $REGION"
echo ""
