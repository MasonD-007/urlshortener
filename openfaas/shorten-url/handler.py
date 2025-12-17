import json
import hashlib
import boto3
import os
from datetime import datetime

def handle(req):
    """
    Handle incoming request to shorten a URL with CORS support.
    
    Expected input (JSON):
    {
        "url": "https://example.com/very/long/url"
    }
    
    Returns:
    {
        "hash": "abc123",
        "short_url": "http://yourdomain.com/abc123",
        "original_url": "https://example.com/very/long/url"
    }
    """
    
    # CORS headers for all responses
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
    }
    
    # Handle OPTIONS preflight request
    method = os.getenv('Http_Method', '').upper()
    if method == 'OPTIONS':
        return json.dumps({
            "statusCode": 200,
            "headers": cors_headers,
            "body": ""
        })
    
    try:
        # Parse incoming request
        data = json.loads(req)
        original_url = data.get('url')
        
        if not original_url:
            return json.dumps({
                "statusCode": 400,
                "headers": cors_headers,
                "body": json.dumps({"error": "URL is required"})
            })
        
        # Generate hash from URL (first 8 characters of SHA256)
        url_hash = hashlib.sha256(original_url.encode()).hexdigest()[:8]
        
        # Initialize DynamoDB client
        dynamodb = boto3.resource(
            'dynamodb',
            endpoint_url=os.getenv('DYNAMODB_ENDPOINT', 'http://dynamodb:8000'),
            region_name=os.getenv('AWS_REGION', 'us-east-1'),
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID', 'local'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY', 'local')
        )
        
        table_name = os.getenv('DYNAMODB_TABLE', 'url_mappings')
        table = dynamodb.Table(table_name)
        
        # Store mapping in DynamoDB
        table.put_item(
            Item={
                'hash': url_hash,
                'original_url': original_url,
                'created_at': datetime.utcnow().isoformat(),
                'click_count': 0
            }
        )
        
        # Build short URL
        domain = os.getenv('SHORT_DOMAIN', 'http://localhost')
        short_url = f"{domain}/{url_hash}"
        
        response_body = {
            "hash": url_hash,
            "short_url": short_url,
            "original_url": original_url
        }
        
        return json.dumps({
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps(response_body)
        })
        
    except json.JSONDecodeError:
        return json.dumps({
            "statusCode": 400,
            "headers": cors_headers,
            "body": json.dumps({"error": "Invalid JSON input"})
        })
    except Exception as e:
        return json.dumps({
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": str(e)})
        })
