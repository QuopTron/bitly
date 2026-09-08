package extensions

import (
	"fmt"
	"net/http"
	"net/url"
)

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
