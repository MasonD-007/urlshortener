import json
import boto3
import os
from botocore.exceptions import ClientError

def handle(req):
    """
    Handle incoming request to redirect from a short URL hash.
    
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
    try:
        # Extract hash from request (assuming it comes as plain text)
        url_hash = req.strip()
        
        if not url_hash:
            return json.dumps({
                "statusCode": 400,
                "body": json.dumps({"error": "Hash is required"})
            })
        
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
        
        # Query DynamoDB for the hash
        response = table.get_item(
            Key={'hash': url_hash}
        )
        
        if 'Item' not in response:
            return json.dumps({
                "statusCode": 404,
                "body": json.dumps({"error": "URL not found"})
            })
        
        original_url = response['Item']['original_url']
        
        # Increment click count (optional)
        table.update_item(
            Key={'hash': url_hash},
            UpdateExpression='SET click_count = click_count + :inc',
            ExpressionAttributeValues={':inc': 1}
        )
        
        # Return redirect response
        return json.dumps({
            "statusCode": 301,
            "headers": {
                "Location": original_url
            },
            "body": ""
        })
        
    except ClientError as e:
        return json.dumps({
            "statusCode": 500,
            "body": json.dumps({"error": f"Database error: {str(e)}"})
        })
    except Exception as e:
        return json.dumps({
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        })
