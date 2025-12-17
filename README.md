# URL Shortener

A complete URL shortening system built with OpenFaaS, DynamoDB Local, and Next.js. This system creates short URLs with automatic QR code generation and analytics tracking.

## Architecture

```
Proxmox Container (10.0.1.2)
├── DynamoDB Local (Port 8000) - Stores URL mappings & analytics
├── OpenFaaS Gateway (Port 8080)
│   ├── url-to-hash - Creates short URLs
│   ├── redirect - Redirects to original URLs
│   └── qrcode-go - Generates QR codes
└── Next.js Frontend (Port 3000) - User interface
```

## Features

- Base62 encoded short URLs (minimum 4 characters)
- Atomic counter for collision-free hash generation
- QR code generation for all short URLs
- Click tracking and analytics
- Modern, responsive UI with Tailwind CSS
- Beautiful 404 page for invalid URLs

## Project Structure

```
urlshortener/
├── docker-compose.yml          # DynamoDB Local container
├── scripts/
│   ├── init-dynamodb.sh       # Initialize DynamoDB tables
│   ├── setup-dev.sh           # Full dev environment setup
│   └── deploy-all.sh          # Build and deploy functions
├── functions/
│   ├── stack.yml              # OpenFaaS function definitions
│   ├── shared/                # Shared Go code
│   │   ├── base62.go
│   │   ├── dynamodb.go
│   │   └── validator.go
│   ├── url-to-hash/           # URL shortening function
│   │   ├── handler.go
│   │   ├── go.mod
│   │   └── [shared code copies]
│   └── redirect/              # Redirect function
│       ├── handler.go
│       ├── go.mod
│       └── [shared code copies]
└── frontend/                  # Next.js application
    ├── src/
    │   ├── app/
    │   │   ├── layout.tsx
    │   │   ├── page.tsx
    │   │   └── globals.css
    │   └── components/
    │       ├── URLShortenerForm.tsx
    │       └── ResultDisplay.tsx
    └── [config files]
```

## Prerequisites

- Docker & Docker Compose
- AWS CLI (for DynamoDB Local management)
- Node.js 20+
- Go 1.21+
- OpenFaaS CLI (`faas-cli`)

## Quick Start

### 1. Setup Development Environment

```bash
# Start DynamoDB Local and initialize tables
./scripts/setup-dev.sh
```

This will:
- Start DynamoDB Local on port 8000
- Create `url_mappings` and `url_counter` tables
- Initialize counter to 10000

### 2. Deploy OpenFaaS Functions

```bash
# Build and deploy all functions
./scripts/deploy-all.sh
```

This will:
- Pull OpenFaaS templates
- Build `url-to-hash` and `redirect` functions
- Deploy to OpenFaaS gateway at http://10.0.1.2:8080

### 3. Start Frontend

```bash
cd frontend
npm install
npm run dev
```

The frontend will be available at http://localhost:3000

## Usage

### Web Interface

1. Navigate to http://localhost:3000
2. Enter a long URL
3. Click "Shorten URL"
4. Copy the short URL or download the QR code

### API Usage

#### Create Short URL

```bash
curl -X POST http://10.0.1.2:8080/function/url-to-hash \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

Response:
```json
{
  "hash": "2bK4",
  "short_url": "http://10.0.1.2:8080/function/redirect?hash=2bK4",
  "qr_code_url": "http://10.0.1.2:8080/function/qrcode-go",
  "original_url": "https://example.com"
}
```

#### Access Short URL

```bash
curl -L http://10.0.1.2:8080/function/redirect?hash=2bK4
```

This will redirect to the original URL and increment the click counter.

## Database Schema

### url_mappings Table

```
hash (String, Primary Key)  - Base62 encoded short code
original_url (String)       - Original long URL
created_at (Number)         - Unix timestamp of creation
click_count (Number)        - Number of times accessed
last_accessed (Number)      - Unix timestamp of last access
```

### url_counter Table

```
counter_id (String, PK)     - Always "global"
counter_value (Number)      - Current counter value
```

## Environment Variables

### OpenFaaS Functions

```bash
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=dummy
AWS_SECRET_ACCESS_KEY=dummy
DYNAMODB_ENDPOINT=http://10.0.1.2:8000
DYNAMODB_TABLE=url_mappings
COUNTER_TABLE=url_counter
BASE_URL=http://10.0.1.2:8080
QRCODE_FUNCTION=http://10.0.1.2:8080/function/qrcode-go
```

### Next.js Frontend

```bash
NEXT_PUBLIC_API_GATEWAY=http://10.0.1.2:8080
NEXT_PUBLIC_QRCODE_FUNCTION=http://10.0.1.2:8080/function/qrcode-go
```

## Management Commands

### View DynamoDB Tables

```bash
aws dynamodb list-tables \
  --endpoint-url http://localhost:8000 \
  --region us-east-1
```

### Query URL Mapping

```bash
aws dynamodb get-item \
  --table-name url_mappings \
  --key '{"hash": {"S": "2bK4"}}' \
  --endpoint-url http://localhost:8000 \
  --region us-east-1
```

### Check Counter Value

```bash
aws dynamodb get-item \
  --table-name url_counter \
  --key '{"counter_id": {"S": "global"}}' \
  --endpoint-url http://localhost:8000 \
  --region us-east-1
```

### View Function Logs

```bash
faas-cli logs url-to-hash --gateway http://10.0.1.2:8080
faas-cli logs redirect --gateway http://10.0.1.2:8080
```

## Technical Details

### Hash Generation

- Uses atomic counter starting at 10000
- Encodes counter to Base62 (0-9, A-Z, a-z)
- First hash: "2Bi" (10000 in base62)
- Guarantees minimum 4 characters
- No collisions due to atomic increment

### QR Code Integration

- Frontend calls `qrcode-go` function directly
- POST request with short URL as body
- Returns PNG image (256x256px)
- Can be displayed inline or downloaded

### Analytics

- Click count incremented atomically
- Last accessed timestamp updated
- Processing happens asynchronously (non-blocking)

### URL Validation

- Requires HTTP or HTTPS scheme
- Must have valid host
- Rejects localhost and private IPs (security)

## Troubleshooting

### DynamoDB Connection Errors

Ensure DynamoDB Local is running:
```bash
docker ps | grep dynamodb
```

Restart if needed:
```bash
docker-compose restart
```

### OpenFaaS Function Not Found

Check function deployment:
```bash
faas-cli list --gateway http://10.0.1.2:8080
```

Redeploy if needed:
```bash
./scripts/deploy-all.sh
```

### Frontend Connection Issues

Verify environment variables in `frontend/.env.local`:
```bash
cat frontend/.env.local
```

## Production Considerations

### Security
- Add rate limiting to prevent abuse
- Implement API authentication
- Use HTTPS for all endpoints
- Validate and sanitize all inputs
- Consider URL expiration dates

### Performance
- Replace DynamoDB Local with AWS DynamoDB
- Add Redis caching for hot URLs
- Implement CDN for QR codes
- Use connection pooling
- Enable OpenFaaS auto-scaling

### Monitoring
- Set up Prometheus metrics
- Configure alerting for errors
- Track response times
- Monitor counter growth
- Set up health checks

## Future Enhancements

- Custom short codes (user-specified)
- URL expiration dates
- Password-protected URLs
- Analytics dashboard
- Bulk URL shortening (CSV upload)
- API key authentication
- Custom domains
- Link management interface

## License

MIT

## Support

For issues and questions, please open an issue on GitHub.
