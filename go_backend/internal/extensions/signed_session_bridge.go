package extensions

import "strings"

// =========================================================================
// Sandbox bridge — used by exports.go so Flutter can drive the Cloudflare
// signed-session flow (auth URL, complete grant, status) directly against
// the sandbox runtime where sessions actually live.
// =========================================================================

// SignedSessionAuthURL triggers bootstrap for a sandbox and returns the
// Cloudflare challenge URL. If the session was provisioned silently, it
// returns an empty URL (nothing to verify).
func (s *Sandbox) SignedSessionAuthURL() (string, error) {
	if s.Session == nil || s.SignedSession == nil {
		return "", errSignedSession("signedSession is not configured")
	}
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return "", err
	}
	if !signedSessionRecordIsUsable(record) {
		if err := s.Session.ensureSignedSession(client, cfg, record); err != nil {
			authURL, bootErr := s.Session.bootstrapWithGuard(client, cfg, record)
			if authURL != "" {
				return authURL, nil
			}
			if bootErr != nil {
				return "", bootErr
			}
		}
	}
	s.Session.mu.Lock()
	authURL := s.Session.AuthURL
	s.Session.mu.Unlock()
	return authURL, nil
}

// SignedSessionCompleteGrant exchanges a grant code obtained from the
// Cloudflare challenge callback (spotiflac://session-grant?code=...).
func (s *Sandbox) SignedSessionCompleteGrant(grant string) error {
	if s.Session == nil || s.SignedSession == nil {
		return errSignedSession("signedSession is not configured")
	}
	grant = strings.TrimSpace(grant)
	if grant == "" {
		return errSignedSession("grant code is empty")
	}
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return err
	}
	return s.Session.exchangeSignedSessionGrant(client, cfg, record, grant)
}

// SignedSessionStatus returns the current signed-session status for Flutter.
func (s *Sandbox) SignedSessionStatus() map[string]any {
	if s.Session == nil || s.SignedSession == nil {
		return map[string]any{"authenticated": false, "error": "signedSession is not configured"}
	}
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return map[string]any{"authenticated": false, "error": err.Error()}
	}
	return map[string]any{
		"authenticated": signedSessionRecordIsUsable(record),
		"expires_at":    record.ExpiresAt,
		"install_id":    record.InstallID,
		"session_id":    record.SessionID,
	}
}

// SignedSessionClear wipes the in-memory session for a sandbox.
func (s *Sandbox) SignedSessionClear() {
	if s.Session == nil {
		return
	}
	s.Session.mu.Lock()
	if s.Session.Record != nil {
		s.Session.Record.SessionID = ""
		s.Session.Record.SessionSecret = ""
		s.Session.Record.ExpiresAt = ""
	}
	s.Session.AuthURL = ""
	s.Session.Grant = ""
	s.Session.mu.Unlock()
}
