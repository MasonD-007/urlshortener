#!/usr/bin/env python3
"""
Simple redirect handler for URL shortener
Runs as a standalone web server that processes short URL redirects
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import requests
import json
import sys
from urllib.parse import urlparse

OPENFAAS_GATEWAY = "http://localhost:8080"
REDIRECT_FUNCTION = f"{OPENFAAS_GATEWAY}/function/redirect-url"

class RedirectHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # Extract the hash from the path
        path = self.path.lstrip('/')
        
        # Remove query strings if any
        hash_value = path.split('?')[0]
        
        # Validate hash format (8 character hex)
        if not hash_value or len(hash_value) != 8:
            self.send_error(400, "Invalid hash format")
            return
        
        try:
            # Call the OpenFaaS redirect-url function
            response = requests.post(
                REDIRECT_FUNCTION,
                data=hash_value,
                headers={'Content-Type': 'text/plain'},
                allow_redirects=False
            )
            
            if response.status_code == 301:
                # Extract the Location header and redirect
                location = response.headers.get('Location')
                if location:
                    self.send_response(301)
                    self.send_header('Location', location)
                    self.send_header('Cache-Control', 'no-cache')
                    self.end_headers()
                    print(f"Redirected {hash_value} -> {location}", file=sys.stderr)
                else:
                    self.send_error(500, "No location header in redirect response")
            elif response.status_code == 404:
                self.send_error(404, "Short URL not found")
            else:
                self.send_error(response.status_code, f"Error from redirect function")
                
        except Exception as e:
            print(f"Error processing redirect: {e}", file=sys.stderr)
            self.send_error(500, str(e))
    
    def log_message(self, format, *args):
        # Log to stderr
        sys.stderr.write(f"{self.address_string()} - {format % args}\n")

def run_server(port=3001):
    server_address = ('', port)
    httpd = HTTPServer(server_address, RedirectHandler)
    print(f"Redirect handler running on port {port}...", file=sys.stderr)
    httpd.serve_forever()

if __name__ == '__main__':
    port = 3001
    if len(sys.argv) > 1:
        port = int(sys.argv[1])
    run_server(port)
