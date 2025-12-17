# Quick Deployment Reference Card

## Build Images First

```bash
./scripts/build-images.sh
```

---

## Deploy via OpenFaaS UI (http://10.0.1.2:8080/ui)

### Function 1: url-to-hash

```
Docker image:        url-to-hash:latest
Function name:       url-to-hash
Function process:    (empty)
Network:             (empty)
```

**Environment Variables:**
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

**Labels (optional):**
```
com.openfaas.scale.min=1
com.openfaas.scale.max=5
```

---

### Function 2: redirect

```
Docker image:        redirect:latest
Function name:       redirect
Function process:    (empty)
Network:             (empty)
```

**Environment Variables:**
```
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=dummy
AWS_SECRET_ACCESS_KEY=dummy
DYNAMODB_ENDPOINT=http://10.0.1.2:8000
DYNAMODB_TABLE=url_mappings
COUNTER_TABLE=url_counter
```

**Labels (optional):**
```
com.openfaas.scale.min=1
com.openfaas.scale.max=10
```

---

## Testing

```bash
# Test url-to-hash
curl -X POST http://10.0.1.2:8080/function/url-to-hash \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'

# Test redirect (use hash from above)
curl -L http://10.0.1.2:8080/function/redirect?hash=2Bi
```

---

## Complete Setup Sequence

1. Start DynamoDB: `docker-compose up -d`
2. Initialize DB: `./scripts/init-dynamodb.sh`
3. Build images: `./scripts/build-images.sh`
4. Deploy functions via UI (see above)
5. Start frontend: `cd frontend && npm install && npm run dev`
6. Access UI: http://localhost:3000
