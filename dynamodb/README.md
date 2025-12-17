# DynamoDB Local Setup for Debian Container

This directory contains scripts and configuration for setting up DynamoDB Local in a Debian container.

## Quick Start

### Option 1: Using Docker

```bash
docker build -t dynamodb-local ./dynamodb
docker run -p 8000:8000 dynamodb-local
```

### Option 2: Using Docker Compose

The `docker-compose.yml` in the root directory already includes DynamoDB Local configuration.

```bash
docker-compose up dynamodb
```

### Option 3: Manual Setup on Debian Container

If you want to manually install DynamoDB Local on a Debian container:

```bash
# Run the setup script
chmod +x setup.sh
./setup.sh

# Start DynamoDB Local
java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb -port 8000
```

## Creating the URL Mappings Table

After DynamoDB Local is running, create the required table:

```bash
# Install AWS CLI if not already installed
apt-get update && apt-get install -y awscli

# Create the table
aws dynamodb create-table \
  --endpoint-url http://localhost:8000 \
  --table-name url_mappings \
  --attribute-definitions AttributeName=hash,AttributeType=S \
  --key-schema AttributeName=hash,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Or use the provided initialization script:

```bash
chmod +x init-table.sh
./init-table.sh
```

## Configuration

DynamoDB Local runs on port 8000 by default. You can change this in:
- `Dockerfile` - ENV PORT=8000
- `setup.sh` - Update the port in the startup command
- `docker-compose.yml` - Update the ports mapping

## Environment Variables

The OpenFaaS functions use these environment variables to connect:

- `DYNAMODB_ENDPOINT`: http://dynamodb:8000 (or http://localhost:8000)
- `AWS_REGION`: us-east-1
- `AWS_ACCESS_KEY_ID`: local (any value works for local)
- `AWS_SECRET_ACCESS_KEY`: local (any value works for local)
- `DYNAMODB_TABLE`: url_mappings

## Table Schema

The `url_mappings` table has the following structure:

| Field | Type | Description |
|-------|------|-------------|
| hash | String (Primary Key) | 8-character hash from the original URL |
| original_url | String | The full original URL |
| created_at | String | ISO format timestamp |
| click_count | Number | Number of times the short URL was accessed |

## Testing the Connection

```bash
# List tables
aws dynamodb list-tables --endpoint-url http://localhost:8000 --region us-east-1

# Put a test item
aws dynamodb put-item \
  --endpoint-url http://localhost:8000 \
  --table-name url_mappings \
  --item '{"hash":{"S":"test1234"},"original_url":{"S":"https://example.com"},"created_at":{"S":"2024-01-01T00:00:00"},"click_count":{"N":"0"}}' \
  --region us-east-1

# Get the test item
aws dynamodb get-item \
  --endpoint-url http://localhost:8000 \
  --table-name url_mappings \
  --key '{"hash":{"S":"test1234"}}' \
  --region us-east-1
```

## Data Persistence

By default, DynamoDB Local stores data in memory. To persist data:

1. **Using Docker volume** (recommended):
   ```bash
   docker run -p 8000:8000 -v $(pwd)/data:/data dynamodb-local -dbPath /data
   ```

2. **Using -dbPath flag**:
   ```bash
   java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -sharedDb -dbPath ./data
   ```

## Troubleshooting

### Port Already in Use
```bash
# Check what's using port 8000
lsof -i :8000
# Or
netstat -tulpn | grep 8000
```

### Java Not Found
```bash
apt-get update && apt-get install -y openjdk-11-jre-headless
```

### Connection Refused
- Ensure DynamoDB Local is running: `curl http://localhost:8000`
- Check Docker network if using containers
- Verify firewall rules

## Additional Resources

- [DynamoDB Local Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)
- [AWS CLI DynamoDB Reference](https://docs.aws.amazon.com/cli/latest/reference/dynamodb/)
