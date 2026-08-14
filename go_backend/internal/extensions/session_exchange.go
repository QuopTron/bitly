package extensions

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// ExchangeGrant exchanges a grant code (obtained from Cloudflare redirect)
// for a session token.
func (sm *SessionManager) ExchangeGrant(extID string, config *SignedSessionConfig, grantCode string) (*SessionState, error) {
	if config == nil {
		return nil, fmt.Errorf("no signed session config for %s", extID)
	}
	if grantCode == "" {
		return nil, fmt.Errorf("empty grant code")
	}

	baseURL := config.BaseURL
	endpoint := config.Endpoints.Exchange
	if baseURL == "" || endpoint == "" {
		return nil, fmt.Errorf("exchange endpoint not configured for %s", extID)
	}

	exchangeURL := strings.TrimRight(baseURL, "/") + "/" + strings.TrimLeft(endpoint, "/")

	form := url.Values{}
	form.Set("code", grantCode)
	form.Set("grant_type", "authorization_code")
	if config.CallbackURL != "" {
		form.Set("redirect_uri", config.CallbackURL)
	}

	req, err := http.NewRequest("POST", exchangeURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("exchange request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := sm.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("exchange failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("exchange returned HTTP %d", resp.StatusCode)
	}

	var result struct {
		Token        string `json:"token"`
		RefreshToken string `json:"refresh_token,omitempty"`
		ExpiresIn    int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("exchange decode: %w", err)
	}
	if result.Token == "" {
		return nil, fmt.Errorf("exchange returned empty token")
	}

	expiresAt := time.Now().Add(time.Duration(result.ExpiresIn) * time.Second)
	if result.ExpiresIn <= 0 {
		expiresAt = time.Now().Add(24 * time.Hour)
	}

	state := &SessionState{
		ExtensionID:  extID,
		Token:        result.Token,
		RefreshToken: result.RefreshToken,
		ExpiresAt:    expiresAt,
		CreatedAt:    time.Now(),
		Active:       true,
	}

	sm.mu.Lock()
	sm.sessions[extID] = state
	sm.mu.Unlock()

	return state, nil
}
