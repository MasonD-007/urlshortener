package function

import (
	"context"
	"fmt"
	"net/http"
)

// Handle is the OpenFaaS handler function for redirects
func Handle(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	// Handle preflight
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Only allow GET
	if r.Method != "GET" {
		send404(w, "Method not allowed")
		return
	}

	// Get hash from query parameter
	hash := r.URL.Query().Get("hash")
	if hash == "" {
		send404(w, "Missing hash parameter")
		return
	}

	// Initialize DynamoDB client
	dbClient, err := NewDynamoDBClient()
	if err != nil {
		send404(w, "Database error")
		return
	}

	// Get URL mapping
	ctx := context.Background()
	mapping, err := dbClient.GetURLMapping(ctx, hash)
	if err != nil {
		send404(w, "Error retrieving URL")
		return
	}

	if mapping == nil {
		send404(w, "Short URL not found")
		return
	}

	// Update analytics asynchronously (don't block redirect)
	go func() {
		// Create a new context for the background operation
		bgCtx := context.Background()
		_ = dbClient.IncrementClickCount(bgCtx, hash)
	}()

	// Redirect to original URL
	http.Redirect(w, r, mapping.OriginalURL, http.StatusFound)
}

// send404 sends a custom 404 page
func send404(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusNotFound)

	html := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - URL Not Found</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 60px 40px;
            max-width: 500px;
            width: 100%%;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            text-align: center;
        }
        h1 {
            font-size: 72px;
            color: #667eea;
            margin-bottom: 20px;
            font-weight: 700;
        }
        h2 {
            font-size: 24px;
            color: #333;
            margin-bottom: 16px;
        }
        p {
            color: #666;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 30px;
        }
        .error-detail {
            background: #f5f5f5;
            border-radius: 8px;
            padding: 12px;
            color: #999;
            font-size: 14px;
            margin-bottom: 30px;
        }
        a {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
            color: white;
            text-decoration: none;
            padding: 14px 32px;
            border-radius: 8px;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        a:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>
        <h2>Short URL Not Found</h2>
        <p>The short URL you're looking for doesn't exist or has been removed.</p>
        <div class="error-detail">%s</div>
        <a href="http://10.0.1.2:3000">Go to Homepage</a>
    </div>
</body>
</html>`, message)

	w.Write([]byte(html))
}
