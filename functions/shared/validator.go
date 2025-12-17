package function

import (
	"fmt"
	"net/url"
	"strings"
)

// ValidateURL validates that a URL is properly formatted and uses HTTP/HTTPS
func ValidateURL(rawURL string) error {
	if rawURL == "" {
		return fmt.Errorf("URL cannot be empty")
	}

	// Parse the URL
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid URL format: %w", err)
	}

	// Check scheme
	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return fmt.Errorf("URL must use HTTP or HTTPS scheme")
	}

	// Check host
	if parsedURL.Host == "" {
		return fmt.Errorf("URL must have a valid host")
	}

	// Check for localhost or private IPs (optional security check)
	host := strings.ToLower(parsedURL.Hostname())
	if host == "localhost" || host == "127.0.0.1" || strings.HasPrefix(host, "192.168.") || strings.HasPrefix(host, "10.") {
		return fmt.Errorf("cannot shorten URLs pointing to private networks")
	}

	return nil
}
