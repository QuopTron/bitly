package extensions

import (
	"net/http"
	"time"
)

func (s *SignedSessionState) bootstrapWithGuard(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord) (string, error) {
	s.bootstrapMu.Lock()
	defer s.bootstrapMu.Unlock()

	if !s.lastBootstrap.IsZero() {
		elapsed := time.Since(s.lastBootstrap)
		if elapsed < s.bootstrapCooldown {
			return s.lastAuthURL, s.lastBootstrapErr
		}
	}

	authURL, err := s.bootstrapSignedSession(client, cfg, record)
	s.lastBootstrap = time.Now()
	s.lastAuthURL = authURL
	switch {
	case err != nil:
		// Bootstrap failed (e.g. HTTP 429/5xx/network). Back off so repeated
		// streaming calls don't keep hammering a rate-limited gateway.
		s.lastBootstrapErr = err
		s.bootstrapCooldown = 30 * time.Second
	case authURL != "":
		// VERIFY_REQUIRED — needs a human challenge; don't re-bootstrap on
		// every request until the user completes verification.
		s.lastBootstrapErr = errSignedSession("verification required")
		s.bootstrapCooldown = 60 * time.Second
	default:
		// Successfully provisioned a silent session; the record now has a
		// SessionID so subsequent signedFetch calls won't bootstrap again.
		s.lastBootstrapErr = nil
		s.bootstrapCooldown = 0
	}
	return authURL, err
}

// persistRecord best-effort writes the current record to disk so the session
// survives restarts. It never fails the caller (read-only FS is fine).
