import qrcode
from qrcode.constants import ERROR_CORRECT_M
import io
import json

def handle(req):
    """
    Generate a QR code from the input text/URL.
    Returns a PNG image with CORS headers.
    """
    try:
        # Read the input (URL to encode)
        input_text = req.strip()
        
        if not input_text:
            return json.dumps({
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type, Authorization"
                },
                "body": json.dumps({"error": "No input provided"})
            })
        
        # Generate QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=ERROR_CORRECT_M,
            box_size=10,
            border=4,
        )
        qr.add_data(input_text)
        qr.make(fit=True)
        
        # Create an image from the QR Code instance
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Save to bytes buffer
        buf = io.BytesIO()
        img.save(buf, 'PNG')
        png_bytes = buf.getvalue()
        
        # Return the PNG image with proper headers
        return json.dumps({
            "statusCode": 200,
            "headers": {
                "Content-Type": "image/png",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": png_bytes.hex(),
            "isBase64Encoded": False
        })
        
    except Exception as e:
        return json.dumps({
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": json.dumps({"error": f"QR code generation failed: {str(e)}"})
        })
