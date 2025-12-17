import json
import hashlib
import boto3
import os
from datetime import datetime

def handle(req):
    """
    Handle incoming request to shorten a URL.
    
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
    try:
        # Parse incoming request
        data = json.loads(req)
        original_url = data.get('url')
        
        if not original_url:
            return json.dumps({
                "error": "URL is required"
            }), 400
        
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
        
        return json.dumps({
            "hash": url_hash,
            "short_url": short_url,
            "original_url": original_url
        })
        
    except json.JSONDecodeError:
        return json.dumps({
            "error": "Invalid JSON input"
        }), 400
    except Exception as e:
        return json.dumps({
            "error": str(e)
        }), 500
