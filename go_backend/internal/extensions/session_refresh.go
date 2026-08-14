package extensions

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// RefreshSession refreshes the session token using the refresh token.
func (sm *SessionManager) RefreshSession(extID string, config *SignedSessionConfig) (*SessionState, error) {
	sm.mu.RLock()
	state := sm.sessions[extID]
	sm.mu.RUnlock()

	if state == nil {
		return nil, fmt.Errorf("no session for %s", extID)
	}
	if !state.Active {
		return nil, fmt.Errorf("session for %s is not active", extID)
	}
	if state.RefreshToken == "" {
		return nil, fmt.Errorf("no refresh token for %s", extID)
	}

	if config == nil || config.Endpoints.Refresh == "" {
		return nil, fmt.Errorf("refresh not configured for %s", extID)
	}

	baseURL := config.BaseURL
	refreshURL := strings.TrimRight(baseURL, "/") + "/" + strings.TrimLeft(config.Endpoints.Refresh, "/")

	form := url.Values{}
	form.Set("refresh_token", state.RefreshToken)
	form.Set("grant_type", "refresh_token")

	req, err := http.NewRequest("POST", refreshURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("refresh request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := sm.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("refresh failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("refresh returned HTTP %d", resp.StatusCode)
	}

	var result struct {
		Token        string `json:"token"`
		RefreshToken string `json:"refresh_token,omitempty"`
		ExpiresIn    int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("refresh decode: %w", err)
	}
	if result.Token == "" {
		return nil, fmt.Errorf("refresh returned empty token")
	}

	expiresAt := time.Now().Add(time.Duration(result.ExpiresIn) * time.Second)
	if result.ExpiresIn <= 0 {
		expiresAt = time.Now().Add(24 * time.Hour)
	}

	state.Token = result.Token
	if result.RefreshToken != "" {
		state.RefreshToken = result.RefreshToken
	}
	state.ExpiresAt = expiresAt
	state.Active = true

	return state, nil
}
