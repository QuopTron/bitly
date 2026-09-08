package extensions

import (
	"fmt"
	"strings"
)

func (s *Sandbox) SignedSessionAuthURL() (string, error) {
	initDebugLogOnce(s.DataDir)
	debugLog(fmt.Sprintf("[%s] SignedSessionAuthURL called, DataDir=%q", s.ID, s.DataDir))

	if s.Session == nil || s.SignedSession == nil {
		debugLog(fmt.Sprintf("[%s] ABORT: Session=%v SignedSession=%v", s.ID, s.Session != nil, s.SignedSession != nil))
		return "", errSignedSession("signedSession is not configured")
	}
	cfg := configSesionFirmadaConDefaults(s.SignedSession)
	debugLog(fmt.Sprintf("[%s] cfg: namespace=%q baseURL=%q bootstrap=%q challenge=%q callback=%q",
		s.ID, cfg.Namespace, cfg.BaseURL, cfg.Endpoints.Bootstrap, cfg.Endpoints.Challenge, cfg.CallbackURL))

	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		debugLog(fmt.Sprintf("[%s] loadOrInit error: %v", s.ID, err))
		return "", err
	}
	usable := registroSesionFirmadaUsable(record)
	debugLog(fmt.Sprintf("[%s] loadOrInit: usable=%v sessionID=%q expires=%q installID=%q",
		s.ID, usable, record.SessionID, record.ExpiresAt, record.InstallID))

	if !usable {
		ensureErr := s.Session.ensureSignedSession(client, cfg, record)
		usable = registroSesionFirmadaUsable(record)
		debugLog(fmt.Sprintf("[%s] after ensure: usable=%v ensureErr=%v", s.ID, usable, ensureErr))

		if !usable {
			authURL, bootErr := s.Session.bootstrapWithGuard(client, cfg, record)
			debugLog(fmt.Sprintf("[%s] bootstrap: authURL=%q bootErr=%v", s.ID, authURL, bootErr))

			if authURL != "" {
				debugLog(fmt.Sprintf("[%s] → CHALLENGE NEEDED: %s", s.ID, authURL))
				return authURL, nil
			}
			if bootErr != nil {
				debugLog(fmt.Sprintf("[%s] → BOOT ERR: %v", s.ID, bootErr))
				return "", bootErr
			}
			if ensureErr != nil {
				debugLog(fmt.Sprintf("[%s] → ENSURE ERR: %v", s.ID, ensureErr))
				return "", ensureErr
			}
		}
	}
	s.Session.mu.Lock()
	authURL := s.Session.AuthURL
	s.Session.mu.Unlock()
	debugLog(fmt.Sprintf("[%s] → FINAL authURL=%q usable=%v", s.ID, authURL, registroSesionFirmadaUsable(record)))
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
	cfg := configSesionFirmadaConDefaults(s.SignedSession)
	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return err
	}
	return s.Session.exchangeSignedSessionGrant(client, cfg, record, grant)
}

// signedKeepAliveClient returns a short-timeout HTTP client sharing the
// sandbox's DoH transport, so a keepalive refresh never holds the bridge
// thread for the shared 30s client timeout when a gateway hangs.
