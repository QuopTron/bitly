package extensions

import (
	"fmt"
	"net/url"
	"strings"
)

// GetAuthURL returns a URL that Flutter should open in a WebView
// to complete the Cloudflare challenge for the given extension.
func (sm *SessionManager) GetAuthURL(extID string, config *SignedSessionConfig) (map[string]interface{}, error) {
	if config == nil {
		return nil, fmt.Errorf("no signed session config for %s", extID)
	}

	baseURL := config.BaseURL
	if baseURL == "" {
		return nil, fmt.Errorf("no base URL configured for %s", extID)
	}
	if config.Endpoints.Bootstrap == "" && config.Endpoints.Challenge == "" {
		return nil, fmt.Errorf("no bootstrap/challenge endpoint configured for %s", extID)
	}

	endpoint := config.Endpoints.Bootstrap
	if endpoint == "" {
		endpoint = config.Endpoints.Challenge
	}

	authURL := strings.TrimRight(baseURL, "/") + "/" + strings.TrimLeft(endpoint, "/")

	params := url.Values{}
	if config.Namespace != "" {
		params.Set("namespace", config.Namespace)
	}
	if config.Platform != "" {
		params.Set("platform", config.Platform)
	}
	if config.AppVersion != "" {
		params.Set("app_version", config.AppVersion)
	}
	if config.CallbackURL != "" {
		params.Set("redirect_uri", config.CallbackURL)
	}
	if len(params) > 0 {
		authURL += "?" + params.Encode()
	}

	expiresIn := config.TimeWindowSeconds
	if expiresIn <= 0 {
		expiresIn = 300
	}

	return map[string]interface{}{
		"url":         authURL,
		"callbackUrl": config.CallbackURL,
		"scheme":      config.Scheme,
		"expiresIn":   expiresIn,
	}, nil
}
