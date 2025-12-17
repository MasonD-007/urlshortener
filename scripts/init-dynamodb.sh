#!/bin/bash

# Initialize DynamoDB Local tables for URL shortener
# Usage: ./scripts/init-dynamodb.sh

set -e

ENDPOINT="http://localhost:8000"
REGION="us-east-1"

echo "Initializing DynamoDB Local tables..."

# Create url_mappings table
echo "Creating url_mappings table..."
aws dynamodb create-table \
  --table-name url_mappings \
  --attribute-definitions \
    AttributeName=hash,AttributeType=S \
  --key-schema \
    AttributeName=hash,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url $ENDPOINT \
  --region $REGION \
  2>/dev/null || echo "Table url_mappings already exists"

# Create url_counter table
echo "Creating url_counter table..."
aws dynamodb create-table \
  --table-name url_counter \
  --attribute-definitions \
    AttributeName=counter_id,AttributeType=S \
  --key-schema \
    AttributeName=counter_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url $ENDPOINT \
  --region $REGION \
  2>/dev/null || echo "Table url_counter already exists"

# Initialize counter with starting value 10000
echo "Initializing counter to 10000..."
aws dynamodb put-item \
  --table-name url_counter \
  --item '{
    "counter_id": {"S": "global"},
    "counter_value": {"N": "10000"}
  }' \
  --endpoint-url $ENDPOINT \
  --region $REGION \
  2>/dev/null || echo "Counter already initialized"

# Verify tables exist
echo ""
echo "Listing tables:"
aws dynamodb list-tables \
  --endpoint-url $ENDPOINT \
  --region $REGION

echo ""
echo "Verifying counter value:"
aws dynamodb get-item \
  --table-name url_counter \
  --key '{"counter_id": {"S": "global"}}' \
  --endpoint-url $ENDPOINT \
  --region $REGION

echo ""
echo "DynamoDB initialization complete!"
