package function

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

// Request represents the incoming request
type Request struct {
	URL string `json:"url"`
}

// Response represents the outgoing response
type Response struct {
	Hash        string `json:"hash"`
	ShortURL    string `json:"short_url"`
	QRCodeURL   string `json:"qr_code_url"`
	OriginalURL string `json:"original_url"`
	Error       string `json:"error,omitempty"`
}

// Handle is the OpenFaaS handler function
func Handle(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.Header().Set("Content-Type", "application/json")

	// Handle preflight
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Only allow POST
	if r.Method != "POST" {
		sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse request
	var req Request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Validate URL
	if err := ValidateURL(req.URL); err != nil {
		sendError(w, fmt.Sprintf("Invalid URL: %v", err), http.StatusBadRequest)
		return
	}

	// Initialize DynamoDB client
	dbClient, err := NewDynamoDBClient()
	if err != nil {
		sendError(w, fmt.Sprintf("Database error: %v", err), http.StatusInternalServerError)
		return
	}

	// Get next counter value
	ctx := context.Background()
	counter, err := dbClient.GetNextCounter(ctx)
	if err != nil {
		sendError(w, fmt.Sprintf("Failed to generate hash: %v", err), http.StatusInternalServerError)
		return
	}

	// Encode counter to base62 hash
	hash := EncodeBase62(counter)

	// Create URL mapping
	mapping := &URLMapping{
		Hash:         hash,
		OriginalURL:  req.URL,
		CreatedAt:    time.Now().Unix(),
		ClickCount:   0,
		LastAccessed: 0,
	}

	// Save to DynamoDB
	if err := dbClient.SaveURLMapping(ctx, mapping); err != nil {
		sendError(w, fmt.Sprintf("Failed to save URL: %v", err), http.StatusInternalServerError)
		return
	}

	// Build response
	baseURL := os.Getenv("BASE_URL")
	if baseURL == "" {
		baseURL = "http://10.0.1.2:8080"
	}

	qrcodeFunction := os.Getenv("QRCODE_FUNCTION")
	if qrcodeFunction == "" {
		qrcodeFunction = "http://10.0.1.2:8080/function/qrcode-go"
	}

	shortURL := fmt.Sprintf("%s/function/redirect?hash=%s", baseURL, hash)

	response := Response{
		Hash:        hash,
		ShortURL:    shortURL,
		QRCodeURL:   qrcodeFunction,
		OriginalURL: req.URL,
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// sendError sends a JSON error response
func sendError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(Response{Error: message})
}
