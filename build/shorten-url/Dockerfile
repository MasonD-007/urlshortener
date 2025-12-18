FROM ghcr.io/openfaas/of-watchdog:0.9.11 as watchdog

FROM python:3.9-slim

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt flask

# Copy watchdog
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

# Copy function
WORKDIR /home/app
COPY handler.py .

# Create Flask wrapper for proper HTTP handling
RUN echo 'from flask import Flask, request, jsonify, make_response\nimport json\nfrom handler import handle\n\napp = Flask(__name__)\n\n@app.route("/", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])\ndef main():\n    # Handle OPTIONS for CORS preflight\n    if request.method == "OPTIONS":\n        response = make_response("", 200)\n        response.headers["Access-Control-Allow-Origin"] = "*"\n        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"\n        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"\n        return response\n    \n    # Get request body\n    if request.method == "POST":\n        req_data = request.get_data(as_text=True)\n    else:\n        req_data = ""\n    \n    # Call handler\n    result = handle(req_data)\n    result_data = json.loads(result)\n    \n    # Extract status code, headers, and body\n    status_code = result_data.get("statusCode", 200)\n    headers = result_data.get("headers", {})\n    body = result_data.get("body", "{}")\n    \n    # Create response\n    if isinstance(body, str):\n        try:\n            body_obj = json.loads(body)\n            response = make_response(jsonify(body_obj), status_code)\n        except:\n            response = make_response(body, status_code)\n    else:\n        response = make_response(jsonify(body), status_code)\n    \n    # Add headers\n    for key, value in headers.items():\n        response.headers[key] = value\n    \n    # Ensure CORS headers are present\n    response.headers["Access-Control-Allow-Origin"] = "*"\n    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"\n    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"\n    \n    return response\n\nif __name__ == "__main__":\n    app.run(host="0.0.0.0", port=5000)' > /home/app/server.py

# Configure watchdog for HTTP mode
ENV fprocess="python3 /home/app/server.py"
ENV mode="http"
ENV upstream_url="http://127.0.0.1:5000"
ENV write_timeout="60s"
ENV read_timeout="60s"

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
