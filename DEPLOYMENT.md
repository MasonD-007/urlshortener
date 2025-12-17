# OpenFaaS Deployment Guide

This guide explains how to deploy the URL shortener functions to OpenFaaS using Docker images.

## Prerequisites

- Docker installed
- OpenFaaS deployed and accessible at http://10.0.1.2:8080
- DynamoDB Local running (via `docker-compose up -d`)

## Step 1: Build Docker Images

Run the build script to create Docker images for both functions:

```bash
./scripts/build-images.sh
```

This will create:
- `url-to-hash:latest`
- `redirect:latest`

### Optional: Push to Docker Registry

If you want to push images to a registry (Docker Hub, private registry, etc.):

```bash
# Build with registry prefix
./scripts/build-images.sh docker.io/yourusername

# Push to registry
docker push docker.io/yourusername/url-to-hash:latest
docker push docker.io/yourusername/redirect:latest
```

## Step 2: Deploy via OpenFaaS UI

Navigate to http://10.0.1.2:8080/ui and deploy each function using these settings:

### Function 1: url-to-hash

**Basic Settings:**
- **Docker image**: `url-to-hash:latest` (or `docker.io/yourusername/url-to-hash:latest` if using registry)
- **Function name**: `url-to-hash`
- **Function process**: (leave empty)
- **Network**: (leave empty)

**Environment Variables** (click "Add" for each):
```
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=dummy
AWS_SECRET_ACCESS_KEY=dummy
DYNAMODB_ENDPOINT=http://10.0.1.2:8000
DYNAMODB_TABLE=url_mappings
COUNTER_TABLE=url_counter
BASE_URL=http://10.0.1.2:8080
QRCODE_FUNCTION=http://10.0.1.2:8080/function/qrcode-go
```

**Labels** (optional, click "Add" for each):
```
com.openfaas.scale.min=1
com.openfaas.scale.max=5
```

### Function 2: redirect

**Basic Settings:**
- **Docker image**: `redirect:latest` (or `docker.io/yourusername/redirect:latest` if using registry)
- **Function name**: `redirect`
- **Function process**: (leave empty)
- **Network**: (leave empty)

**Environment Variables** (click "Add" for each):
```
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=dummy
AWS_SECRET_ACCESS_KEY=dummy
DYNAMODB_ENDPOINT=http://10.0.1.2:8000
DYNAMODB_TABLE=url_mappings
COUNTER_TABLE=url_counter
```

**Labels** (optional, click "Add" for each):
```
com.openfaas.scale.min=1
com.openfaas.scale.max=10
```

## Step 3: Verify Deployment

### Check Function Status

```bash
# List all functions
curl http://10.0.1.2:8080/system/functions

# Or view in UI
# Navigate to http://10.0.1.2:8080/ui
```

### Test url-to-hash Function

```bash
curl -X POST http://10.0.1.2:8080/function/url-to-hash \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/test"}'
```

Expected response:
```json
{
  "hash": "2Bi",
  "short_url": "http://10.0.1.2:8080/function/redirect?hash=2Bi",
  "qr_code_url": "http://10.0.1.2:8080/function/qrcode-go",
  "original_url": "https://example.com/test"
}
```

### Test redirect Function

```bash
# Should redirect to example.com
curl -L http://10.0.1.2:8080/function/redirect?hash=2Bi
```

## Alternative: Deploy via faas-cli

If you prefer using the command line:

### Option 1: Using stack.yml (requires OpenFaaS templates)

```bash
cd functions
faas-cli template pull
faas-cli build -f stack.yml
faas-cli deploy -f stack.yml --gateway http://10.0.1.2:8080
```

### Option 2: Using Docker images directly

```bash
# Deploy url-to-hash
faas-cli deploy \
  --image url-to-hash:latest \
  --name url-to-hash \
  --gateway http://10.0.1.2:8080 \
  --env AWS_REGION=us-east-1 \
  --env AWS_ACCESS_KEY_ID=dummy \
  --env AWS_SECRET_ACCESS_KEY=dummy \
  --env DYNAMODB_ENDPOINT=http://10.0.1.2:8000 \
  --env DYNAMODB_TABLE=url_mappings \
  --env COUNTER_TABLE=url_counter \
  --env BASE_URL=http://10.0.1.2:8080 \
  --env QRCODE_FUNCTION=http://10.0.1.2:8080/function/qrcode-go \
  --label com.openfaas.scale.min=1 \
  --label com.openfaas.scale.max=5

# Deploy redirect
faas-cli deploy \
  --image redirect:latest \
  --name redirect \
  --gateway http://10.0.1.2:8080 \
  --env AWS_REGION=us-east-1 \
  --env AWS_ACCESS_KEY_ID=dummy \
  --env AWS_SECRET_ACCESS_KEY=dummy \
  --env DYNAMODB_ENDPOINT=http://10.0.1.2:8000 \
  --env DYNAMODB_TABLE=url_mappings \
  --env COUNTER_TABLE=url_counter \
  --label com.openfaas.scale.min=1 \
  --label com.openfaas.scale.max=10
```

## Troubleshooting

### Image Not Found

If OpenFaaS can't find your image:

1. **Local deployment**: Make sure the image is built on the same machine as OpenFaaS
2. **Multi-node**: Push images to a registry accessible by all nodes
3. **Check image name**: Verify with `docker images | grep url-to-hash`

### Function Not Starting

Check function logs:
```bash
faas-cli logs url-to-hash --gateway http://10.0.1.2:8080
faas-cli logs redirect --gateway http://10.0.1.2:8080
```

### DynamoDB Connection Errors

Ensure DynamoDB Local is running:
```bash
docker ps | grep dynamodb
```

Test connectivity:
```bash
curl http://10.0.1.2:8000
```

Initialize tables if needed:
```bash
./scripts/init-dynamodb.sh
```

### Updating Functions

To update after code changes:

```bash
# Rebuild images
./scripts/build-images.sh

# Redeploy via UI or CLI
faas-cli deploy --image url-to-hash:latest --name url-to-hash --gateway http://10.0.1.2:8080 --update
```

## Quick Reference

### Environment Variables Required

**url-to-hash:**
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `DYNAMODB_ENDPOINT`, `DYNAMODB_TABLE`, `COUNTER_TABLE`
- `BASE_URL`, `QRCODE_FUNCTION`

**redirect:**
- `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `DYNAMODB_ENDPOINT`, `DYNAMODB_TABLE`, `COUNTER_TABLE`

### Function Endpoints

- Create short URL: `POST http://10.0.1.2:8080/function/url-to-hash`
- Redirect: `GET http://10.0.1.2:8080/function/redirect?hash=<HASH>`
- QR Code: `POST http://10.0.1.2:8080/function/qrcode-go` (body: URL)

### Useful Commands

```bash
# List functions
faas-cli list --gateway http://10.0.1.2:8080

# View function details
faas-cli describe url-to-hash --gateway http://10.0.1.2:8080

# View logs
faas-cli logs url-to-hash --gateway http://10.0.1.2:8080

# Remove function
faas-cli remove url-to-hash --gateway http://10.0.1.2:8080

# Invoke function
faas-cli invoke url-to-hash --gateway http://10.0.1.2:8080
```

## Next Steps

After deployment:
1. Start the frontend: `cd frontend && npm install && npm run dev`
2. Access the UI at http://localhost:3000
3. Test creating short URLs
4. Monitor function metrics at http://10.0.1.2:8080/ui
