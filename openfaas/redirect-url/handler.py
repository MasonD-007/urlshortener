import json
import boto3
import os
import sys
from datetime import datetime
from botocore.exceptions import ClientError

def log(level, message, **kwargs):
    """Helper function to log messages with consistent format"""
    timestamp = datetime.utcnow().isoformat()
    log_data = {
        "timestamp": timestamp,
        "level": level,
        "function": "redirect-url",
        "message": message,
        **kwargs
    }
    print(json.dumps(log_data), file=sys.stderr)
    sys.stderr.flush()

def handle(req):
    """
    Handle incoming request to redirect from a short URL hash with CORS support.
    
    Expected input: The hash string (e.g., "abc123")
    
    Returns HTTP redirect response or error:
    {
        "statusCode": 301,
        "headers": {
            "Location": "https://example.com/original/url"
        }
    }
    
    Or error response:
    {
        "statusCode": 404,
        "body": {
            "error": "URL not found"
        }
    }
    """
    
    log("INFO", "Redirect request received")
    
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
        # Extract hash from request (assuming it comes as plain text)
        url_hash = req.strip()
        log("INFO", "Received hash", hash=url_hash, hash_length=len(url_hash))
        
        if not url_hash:
            log("WARN", "Empty hash received")
            return json.dumps({
                "statusCode": 400,
                "headers": cors_headers,
                "body": json.dumps({"error": "Hash is required"})
            })
        
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
        log("INFO", "Querying DynamoDB", table=table_name, hash=url_hash)
        
        # Query DynamoDB for the hash
        response = table.get_item(
            Key={'hash': url_hash}
        )
        
        if 'Item' not in response:
            log("WARN", "Hash not found in database", hash=url_hash)
            return json.dumps({
                "statusCode": 404,
                "headers": cors_headers,
                "body": json.dumps({"error": "URL not found"})
            })
        
        original_url = response['Item']['original_url']
        # Convert Decimal to int for JSON serialization
        current_count = int(response['Item'].get('click_count', 0))
        log("INFO", "URL found", hash=url_hash, original_url=original_url, current_count=current_count)
        
        # Increment click count
        log("INFO", "Incrementing click count", hash=url_hash)
        update_response = table.update_item(
            Key={'hash': url_hash},
            UpdateExpression='SET click_count = click_count + :inc',
            ExpressionAttributeValues={':inc': 1},
            ReturnValues='UPDATED_NEW'
        )
        # Convert Decimal to int for JSON serialization
        new_count = int(update_response.get('Attributes', {}).get('click_count', current_count + 1))
        log("INFO", "Click count updated", hash=url_hash, new_count=new_count)
        
        # Check if JSON format is requested via query parameter
        query_string = os.getenv('Http_Query', '')
        log("INFO", "Query string", query=query_string)
        
        # If format=json is in query string, return JSON instead of redirect
        if 'format=json' in query_string:
            log("INFO", "Returning JSON response", hash=url_hash, click_count=new_count)
            response_body = {
                "hash": url_hash,
                "original_url": original_url,
                "click_count": new_count
            }
            return json.dumps({
                "statusCode": 200,
                "headers": cors_headers,
                "body": json.dumps(response_body)
            })
        
        # Default: Return redirect response (merge CORS headers with Location)
        redirect_headers = cors_headers.copy()
        redirect_headers["Location"] = original_url
        
        log("INFO", "Returning redirect response", hash=url_hash, location=original_url, status=301)
        
        return json.dumps({
            "statusCode": 301,
            "headers": redirect_headers,
            "body": ""
        })
        
    except ClientError as e:
        log("ERROR", "DynamoDB error", error=str(e), error_code=e.response.get('Error', {}).get('Code'))
        return json.dumps({
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": f"Database error: {str(e)}"})
        })
    except Exception as e:
        log("ERROR", "Unexpected error", error=str(e), error_type=type(e).__name__)
        return json.dumps({
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": str(e)})
        })
