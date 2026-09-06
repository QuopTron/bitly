package extensions

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var debugLogPath string
var debugLogInited bool

func initDebugLogOnce(dataDir string) {
	if debugLogInited {
		return
	}
	debugLogInited = true
	// Write to sdcard so we can read it without root
	for _, p := range []string{
		"/sdcard/signed_session_debug.log",
		filepath.Join(dataDir, "signed_session_debug.log"),
	} {
		f, err := os.OpenFile(p, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0666)
		if err == nil {
			f.Close()
			debugLogPath = p
			return
		}
	}
	// Fallback to dataDir
	debugLogPath = filepath.Join(dataDir, "signed_session_debug.log")
}

func debugLog(msg string) {
	if debugLogPath == "" {
		return
	}
	f, err := os.OpenFile(debugLogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] %s\n", time.Now().Format("15:04:05.000"), msg)
}

// =========================================================================
// Sandbox bridge — used by exports.go so Flutter can drive the Cloudflare
// signed-session flow (auth URL, complete grant, status) directly against
// the sandbox runtime where sessions actually live.
// =========================================================================

// SignedSessionAuthURL triggers bootstrap for a sandbox and returns the
// Cloudflare challenge URL. If the session was provisioned silently, it
// returns an empty URL (nothing to verify).
func (s *Sandbox) SignedSessionAuthURL() (string, error) {
	initDebugLogOnce(s.DataDir)
	debugLog(fmt.Sprintf("[%s] SignedSessionAuthURL called, DataDir=%q", s.ID, s.DataDir))

	if s.Session == nil || s.SignedSession == nil {
		debugLog(fmt.Sprintf("[%s] ABORT: Session=%v SignedSession=%v", s.ID, s.Session != nil, s.SignedSession != nil))
		return "", errSignedSession("signedSession is not configured")
	}
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	debugLog(fmt.Sprintf("[%s] cfg: namespace=%q baseURL=%q bootstrap=%q challenge=%q callback=%q",
		s.ID, cfg.Namespace, cfg.BaseURL, cfg.Endpoints.Bootstrap, cfg.Endpoints.Challenge, cfg.CallbackURL))

	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		debugLog(fmt.Sprintf("[%s] loadOrInit error: %v", s.ID, err))
		return "", err
	}
	usable := signedSessionRecordIsUsable(record)
	debugLog(fmt.Sprintf("[%s] loadOrInit: usable=%v sessionID=%q expires=%q installID=%q",
		s.ID, usable, record.SessionID, record.ExpiresAt, record.InstallID))

	if !usable {
		ensureErr := s.Session.ensureSignedSession(client, cfg, record)
		usable = signedSessionRecordIsUsable(record)
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
	debugLog(fmt.Sprintf("[%s] → FINAL authURL=%q usable=%v", s.ID, authURL, signedSessionRecordIsUsable(record)))
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

// signedKeepAliveClient returns a short-timeout HTTP client sharing the
// sandbox's DoH transport, so a keepalive refresh never holds the bridge
// thread for the shared 30s client timeout when a gateway hangs.
func (s *Sandbox) signedKeepAliveClient() *http.Client {
	base := s.signedHTTPClient()
	transport := base.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}
	return &http.Client{Timeout: signedSessionKeepAliveTimeout, Transport: transport}
}

// SignedSessionKeepAlive silently refreshes the sandbox's signed session when
// it is still usable and near expiry (see SignedSessionState.keepAliveRefresh).
// It never bootstraps and never produces a challenge URL — Flutter only opens
// the Cloudflare modal on an explicit user action. Returns a status map shaped
// like SignedSessionStatus plus a "refreshed" flag for the keepalive caller.
func (s *Sandbox) SignedSessionKeepAlive() map[string]any {
	status := map[string]any{
		"authenticated": false,
		"refreshed":     false,
	}
	if s.Session == nil || s.SignedSession == nil {
		status["error"] = "signedSession is not configured"
		return status
	}
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		status["error"] = err.Error()
		return status
	}
	status["install_id"] = record.InstallID
	status["session_id"] = record.SessionID
	status["expires_at"] = record.ExpiresAt
	status["authenticated"] = signedSessionRecordIsUsable(record)

	refreshed, err := s.Session.keepAliveRefresh(s.signedKeepAliveClient(), cfg, record)
	if err != nil {
		status["error"] = err.Error()
	}
	if refreshed {
		// After a successful refresh the record carries the new expiry/session.
		status["session_id"] = record.SessionID
		status["expires_at"] = record.ExpiresAt
		status["refreshed"] = true
	}
	status["authenticated"] = signedSessionRecordIsUsable(record)
	return status
}

// SignedSessionProvision runs the startup provisioning step for a sandbox:
// report status, silently refresh a near-expiry session, or silently attempt a
// bootstrap when the session is missing/expired. Never opens UI itself — if
// the gateway demands a human challenge it only reports needs_verification so
// Flutter decides when to show the modal (explicit user action). Bounded by
// the keepalive short-timeout client so a hung gateway can't stall startup.
func (s *Sandbox) SignedSessionProvision() map[string]any {
	status := map[string]any{
		"authenticated": false,
		"refreshed":     false,
		"needs_verification": false,
	}
	if s.Session == nil || s.SignedSession == nil {
		status["error"] = "signedSession is not configured"
		return status
	}
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	client := s.signedKeepAliveClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		status["error"] = err.Error()
		return status
	}
	status["install_id"] = record.InstallID
	status["session_id"] = record.SessionID
	status["expires_at"] = record.ExpiresAt
	status["authenticated"] = signedSessionRecordIsUsable(record)

	if signedSessionRecordIsUsable(record) {
		// Valid session: silently refresh if it is near expiry.
		refreshed, rerr := s.Session.keepAliveRefresh(client, cfg, record)
		if rerr != nil {
			status["error"] = rerr.Error()
		}
		if refreshed {
			status["session_id"] = record.SessionID
			status["expires_at"] = record.ExpiresAt
			status["refreshed"] = true
		}
		status["authenticated"] = signedSessionRecordIsUsable(record)
		return status
	}

	// Missing/expired session: try a silent bootstrap. If the gateway replies
	// with a challenge URL we do NOT return it for an automatic modal — the
	// explicit-action flows (play/search/download) fetch it on demand.
	authURL, bootErr := s.Session.bootstrapWithGuard(client, cfg, record)
	if bootErr != nil {
		status["error"] = bootErr.Error()
		return status
	}
	if authURL != "" {
		status["needs_verification"] = true
		status["auth_url"] = authURL
		return status
	}
	// Silent bootstrap succeeded.
	status["session_id"] = record.SessionID
	status["expires_at"] = record.ExpiresAt
	status["authenticated"] = signedSessionRecordIsUsable(record)
	return status
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
