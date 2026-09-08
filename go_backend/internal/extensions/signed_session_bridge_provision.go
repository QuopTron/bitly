package extensions

func (s *Sandbox) SignedSessionProvision() map[string]any {
	status := map[string]any{
		"authenticated":      false,
		"refreshed":          false,
		"needs_verification": false,
	}
	if s.Session == nil || s.SignedSession == nil {
		status["error"] = "signedSession is not configured"
		return status
	}
	cfg := configSesionFirmadaConDefaults(s.SignedSession)
	client := s.signedKeepAliveClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		status["error"] = err.Error()
		return status
	}
	status["install_id"] = record.InstallID
	status["session_id"] = record.SessionID
	status["expires_at"] = record.ExpiresAt
	status["authenticated"] = registroSesionFirmadaUsable(record)

	if registroSesionFirmadaUsable(record) {
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
		status["authenticated"] = registroSesionFirmadaUsable(record)
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
	status["authenticated"] = registroSesionFirmadaUsable(record)
	return status
}

// SignedSessionStatus returns the current signed-session status for Flutter.
func (s *Sandbox) SignedSessionStatus() map[string]any {
	if s.Session == nil || s.SignedSession == nil {
		return map[string]any{"authenticated": false, "error": "signedSession is not configured"}
	}
	cfg := configSesionFirmadaConDefaults(s.SignedSession)
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return map[string]any{"authenticated": false, "error": err.Error()}
	}
	return map[string]any{
		"authenticated": registroSesionFirmadaUsable(record),
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
