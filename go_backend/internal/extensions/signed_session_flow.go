package extensions

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

func jsonUnmarshal(data []byte, v interface{}) error {
	return json.Unmarshal(data, v)
}

func marshalJSON(v interface{}) ([]byte, error) {
	return json.Marshal(v)
}

const signedSessionRefreshSkew = time.Hour

// Signed-session keepalive policy. While the app is in the foreground,
// Flutter calls KeepAliveSignedSessions on a timer; each source's sandbox
// silently refreshes its session when it is close to expiring so a still-valid
// token never dies mid-use (which would otherwise surface VERIFY_REQUIRED on
// the next stream/search/download). Refresh only happens while the record is
// usable — an already-expired or missing session is left untouched: the app
// only asks for a human challenge on an explicit user action.
const (
	// A session with less than this much time left is refreshed.
	signedSessionKeepAliveLead = 5 * time.Minute
	// Never refresh the same source more often than this (gateway pacing).
	signedSessionKeepAliveMinInterval = 30 * time.Second
	// After a failed refresh, wait this long before trying that source again.
	signedSessionKeepAliveBackoff = 2 * time.Minute
	// Per-call HTTP timeout for keepalive refreshes (never hold the bridge
	// thread on a dead endpoint; the shared client defaults to 30s).
	signedSessionKeepAliveTimeout = 8 * time.Second
)

// bootstrapSignedSession calls GET /bootstrap?app_version&install_id.
// It either provisions a session silently or returns a challenge URL.
func (s *SignedSessionState) bootstrapSignedSession(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord) (string, error) {
	bootstrapURL, err := signedSessionURL(cfg, cfg.Endpoints.Bootstrap)
	if err != nil {
		return "", err
	}
	parsed, err := url.Parse(bootstrapURL)
	if err != nil {
		return "", err
	}
	query := parsed.Query()
	query.Set("app_version", cfg.AppVersion)
	query.Set("install_id", record.InstallID)
	parsed.RawQuery = query.Encode()

	req, err := http.NewRequest(http.MethodGet, parsed.String(), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "SpotiFLAC-Mobile/"+cfg.AppVersion)

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	body, err := readSignedBody(resp)
	if err != nil {
		return "", err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("signed-session bootstrap returned HTTP %d", resp.StatusCode)
	}
	var boot signedSessionExchangeResponse
	if err := jsonUnmarshal(body, &boot); err != nil {
		return "", fmt.Errorf("decode signed-session bootstrap response: %w", err)
	}
	if boot.SessionID != "" && boot.SessionSecret != "" && boot.ExpiresAt != "" {
		record.SessionID = boot.SessionID
		record.SessionSecret = boot.SessionSecret
		record.ExpiresAt = boot.ExpiresAt
		s.Record = record
		s.AuthURL = ""
		s.persistRecord(cfg)
		return "", nil
	}
	authURL := boot.AuthURL
	if authURL == "" && boot.ChallengeURL != "" {
		authURL = boot.ChallengeURL
	}
	if authURL == "" && boot.ChallengeID != "" {
		authURL = s.buildChallengeURL(cfg, boot.ChallengeID)
	}
	if authURL == "" {
		return "", fmt.Errorf("signed-session bootstrap did not return a session or verification challenge")
	}
	s.AuthURL = authURL
	s.Callback = cfg.CallbackURL
	return authURL, nil
}

func (s *SignedSessionState) buildChallengeURL(cfg SignedSessionConfig, challengeID string) string {
	challengeURL, err := signedSessionURL(cfg, cfg.Endpoints.Challenge)
	if err != nil {
		return ""
	}
	parsed, err := url.Parse(challengeURL)
	if err != nil {
		return ""
	}
	callback, err := url.Parse(cfg.CallbackURL)
	if err != nil {
		return ""
	}
	q := callback.Query()
	q.Set("cb_version", "v2grant")
	callback.RawQuery = q.Encode()
	query := parsed.Query()
	query.Set("id", challengeID)
	query.Set("cb", callback.String())
	parsed.RawQuery = query.Encode()
	return parsed.String()
}

// exchangeSignedSessionGrant posts the grant and stores the new session.
func (s *SignedSessionState) exchangeSignedSessionGrant(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord, grant string) error {
	endpoint, err := signedSessionURL(cfg, cfg.Endpoints.Exchange)
	if err != nil {
		return err
	}
	payload := map[string]any{
		"grant":       grant,
		"install_id":  record.InstallID,
		"app_version": cfg.AppVersion,
		"platform":    cfg.Platform,
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "SpotiFLAC-Mobile/"+cfg.AppVersion)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	respBody, err := readSignedBody(resp)
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		// Include the gateway body so a failing exchange is diagnosable from
		// the Go/Flutter logs instead of a bare status code.
		return fmt.Errorf("session exchange failed: HTTP %d (%s)", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	var exchanged signedSessionExchangeResponse
	if err := jsonUnmarshal(respBody, &exchanged); err != nil {
		return fmt.Errorf("invalid session exchange response: %w", err)
	}
	if exchanged.SessionID == "" || exchanged.SessionSecret == "" || exchanged.ExpiresAt == "" {
		return fmt.Errorf("session exchange response missing session fields")
	}
	record.SessionID = exchanged.SessionID
	record.SessionSecret = exchanged.SessionSecret
	record.ExpiresAt = exchanged.ExpiresAt
	s.Record = record
	s.Grant = ""
	s.AuthURL = ""
	s.persistRecord(cfg)
	return nil
}

// keepAliveRefresh silently refreshes the session when it is still usable and
// within [signedSessionKeepAliveLead] of expiry. Paced per source and backed
// off after failures so a periodic tick never hammers the gateway. Never
// bootstraps and never returns a challenge URL — a session that needs human
// verification is reported as-is and left to the explicit-action flows.
func (s *SignedSessionState) keepAliveRefresh(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord) (bool, error) {
	s.keepAliveMu.Lock()
	defer s.keepAliveMu.Unlock()

	now := time.Now()
	if !s.keepAliveBackoffUntil.IsZero() && now.Before(s.keepAliveBackoffUntil) {
		return false, nil // still in failure backoff
	}
	if !s.lastKeepAlive.IsZero() && now.Sub(s.lastKeepAlive) < signedSessionKeepAliveMinInterval {
		return false, nil // still inside the pacing window
	}
	s.lastKeepAlive = now

	if record == nil || record.SessionID == "" || record.SessionSecret == "" || !signedSessionRecordIsUsable(record) {
		return false, nil // nothing usable to refresh — never bootstrap here
	}
	expiresAt, ok := parseSignedSessionTime(record.ExpiresAt)
	if !ok {
		return false, nil
	}
	if time.Until(expiresAt) > signedSessionKeepAliveLead {
		return false, nil // plenty of life left
	}
	if err := s.refreshSignedSession(client, cfg, record); err != nil {
		s.keepAliveBackoffUntil = time.Now().Add(signedSessionKeepAliveBackoff)
		return false, err
	}
	return true, nil
}

// refreshSignedSession refreshes the session near expiry.
func (s *SignedSessionState) refreshSignedSession(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord) error {
	body, _ := json.Marshal(map[string]string{"install_id": record.InstallID})
	resp, respBody, _, err := s.doSignedRequest(client, cfg, record, http.MethodPost, cfg.Endpoints.Refresh, body, nil)
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("session refresh failed: HTTP %d", resp.StatusCode)
	}
	var refreshed signedSessionExchangeResponse
	if err := jsonUnmarshal(respBody, &refreshed); err != nil {
		return err
	}
	if refreshed.SessionID != "" {
		record.SessionID = refreshed.SessionID
	}
	if refreshed.SessionSecret != "" {
		record.SessionSecret = refreshed.SessionSecret
	}
	if refreshed.ExpiresAt != "" {
		record.ExpiresAt = refreshed.ExpiresAt
	}
	s.Record = record
	s.persistRecord(cfg)
	return nil
}

// ensureSignedSession returns a usable session, refreshing if near expiry.
func (s *SignedSessionState) ensureSignedSession(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord) error {
	if record.SessionID == "" || record.SessionSecret == "" {
		return errSignedSession("signed session is not authenticated")
	}
	if expiresAt, ok := parseSignedSessionTime(record.ExpiresAt); ok {
		if time.Now().After(expiresAt) {
			return errSignedSession("signed session expired")
		}
		if cfg.Endpoints.Refresh != "" && time.Until(expiresAt) <= signedSessionRefreshSkew {
			_ = s.refreshSignedSession(client, cfg, record)
		}
	}
	return nil
}
