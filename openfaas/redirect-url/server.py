from flask import Flask, request, make_response
import json
from handler import handle

app = Flask(__name__)

@app.route("/", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
def main():
    # Handle OPTIONS for CORS preflight
    if request.method == "OPTIONS":
        response = make_response("", 200)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return response
    
    # Get request body
    if request.method == "POST":
        req_data = request.get_data(as_text=True)
    else:
        req_data = ""
    
    # Call handler
    result = handle(req_data)
    result_data = json.loads(result)
    
    # Extract status code, headers, and body
    status_code = result_data.get("statusCode", 200)
    headers = result_data.get("headers", {})
    body = result_data.get("body", "")
    
    # Handle redirects (301, 302, etc)
    if status_code in [301, 302, 303, 307, 308]:
        location = headers.get("Location", "/")
        response = make_response("", status_code)
        response.headers["Location"] = location
        # Add CORS headers even for redirects
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Expose-Headers"] = "Location"
        return response
    
    # Create regular response
    if isinstance(body, str) and body:
        try:
            body_obj = json.loads(body)
            response = make_response(json.dumps(body_obj), status_code)
            response.headers["Content-Type"] = "application/json"
        except:
            response = make_response(body, status_code)
    else:
        response = make_response("", status_code)
    
    # Add headers
    for key, value in headers.items():
        if key.lower() != "location":  # Already handled for redirects
            response.headers[key] = value
    
    # Ensure CORS headers are present
    if "Access-Control-Allow-Origin" not in response.headers:
        response.headers["Access-Control-Allow-Origin"] = "*"
    
    return response

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
