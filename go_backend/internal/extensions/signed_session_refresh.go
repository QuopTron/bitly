package extensions

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

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

	if record == nil || record.SessionID == "" || record.SessionSecret == "" || !registroSesionFirmadaUsable(record) {
		return false, nil // nothing usable to refresh — never bootstrap here
	}
	expiresAt, ok := parsearTiempoSesionFirmada(record.ExpiresAt)
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
		return fmt.Errorf("ERR_SESION: fallo el refresco de sesion: HTTP %d", resp.StatusCode)
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
	if expiresAt, ok := parsearTiempoSesionFirmada(record.ExpiresAt); ok {
		if time.Now().After(expiresAt) {
			return errSignedSession("signed session expired")
		}
		if cfg.Endpoints.Refresh != "" && time.Until(expiresAt) <= signedSessionRefreshSkew {
			_ = s.refreshSignedSession(client, cfg, record)
		}
	}
	return nil
}
