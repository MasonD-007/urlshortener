import json
import hashlib
import boto3
import os
import sys
from datetime import datetime

def log(level, message, **kwargs):
    """Helper function to log messages with consistent format"""
    timestamp = datetime.utcnow().isoformat()
    log_data = {
        "timestamp": timestamp,
        "level": level,
        "function": "shorten-url",
        "message": message,
        **kwargs
    }
    print(json.dumps(log_data), file=sys.stderr)
    sys.stderr.flush()

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
    
    log("INFO", "Shorten URL request received")
    
    # CORS headers for all responses
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
    }
    
    # Handle OPTIONS preflight request
    method = os.getenv('Http_Method', '').upper()
    log("INFO", "HTTP method detected", method=method)
    
    if method == 'OPTIONS':
        log("INFO", "Handling OPTIONS preflight request")
        return json.dumps({
            "statusCode": 200,
            "headers": cors_headers,
            "body": ""
        })
    
    try:
        # Parse incoming request
        log("INFO", "Parsing request body", body_length=len(req))
        data = json.loads(req)
        original_url = data.get('url')
        
        log("INFO", "Extracted URL from request", url=original_url)
        
        if not original_url:
            log("WARN", "Empty URL received")
            return json.dumps({
                "statusCode": 400,
                "headers": cors_headers,
                "body": json.dumps({"error": "URL is required"})
            })
        
        # Generate hash from URL (first 8 characters of SHA256)
        url_hash = hashlib.sha256(original_url.encode()).hexdigest()[:8]
        log("INFO", "Generated hash", hash=url_hash, url=original_url)
        
        # Initialize DynamoDB client
        dynamodb_endpoint = os.getenv('DYNAMODB_ENDPOINT', 'http://dynamodb:8000')
        log("INFO", "Initializing DynamoDB client", endpoint=dynamodb_endpoint)
        
        dynamodb = boto3.resource(
            'dynamodb',
            endpoint_url=dynamodb_endpoint,
            region_name=os.getenv('AWS_REGION', 'us-east-1'),
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID', 'local'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY', 'local')
        )
        
        table_name = os.getenv('DYNAMODB_TABLE', 'url_mappings')
        table = dynamodb.Table(table_name)
        log("INFO", "Checking if URL mapping exists", table=table_name, hash=url_hash)
        
        # Check if hash already exists
        existing_item = None
        try:
            response = table.get_item(Key={'hash': url_hash})
            if 'Item' in response:
                existing_item = response['Item']
                log("INFO", "Found existing URL mapping", hash=url_hash, click_count=existing_item.get('click_count', 0))
        except Exception as e:
            log("WARN", "Error checking for existing item", error=str(e))
        
        # If URL already exists, return existing mapping with counter
        if existing_item:
            click_count = existing_item.get('click_count', 0)
            log("INFO", "Returning existing URL mapping", hash=url_hash, click_count=click_count)
        else:
            # Store new mapping in DynamoDB
            log("INFO", "Storing new URL mapping", table=table_name, hash=url_hash)
            table.put_item(
                Item={
                    'hash': url_hash,
                    'original_url': original_url,
                    'created_at': datetime.utcnow().isoformat(),
                    'click_count': 0
                }
            )
            click_count = 0
            log("INFO", "URL mapping stored successfully", hash=url_hash)
        
        # Build short URL
        domain = os.getenv('SHORT_DOMAIN', 'http://localhost')
        short_url = f"{domain}/{url_hash}"
        log("INFO", "Generated short URL", short_url=short_url, hash=url_hash, click_count=click_count)
        
        response_body = {
            "hash": url_hash,
            "short_url": short_url,
            "original_url": original_url,
            "click_count": click_count,
            "already_exists": existing_item is not None
        }
        
        return json.dumps({
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps(response_body)
        })
        
    except json.JSONDecodeError as e:
        log("ERROR", "JSON decode error", error=str(e), body=req[:100])
        return json.dumps({
            "statusCode": 400,
            "headers": cors_headers,
            "body": json.dumps({"error": "Invalid JSON input"})
        })
    except Exception as e:
        log("ERROR", "Unexpected error", error=str(e), error_type=type(e).__name__)
        return json.dumps({
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": str(e)})
        })
