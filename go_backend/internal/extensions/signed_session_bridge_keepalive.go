package extensions

import (
	"net/http"
)

func (s *Sandbox) signedKeepAliveClient() *http.Client {
	base := s.signedHTTPClient()
	transport := base.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}
	return &http.Client{Timeout: signedSessionKeepAliveTimeout, Transport: transport}
}

// SignedSessionKeepAlive renueva en silencio la sesión firmada del sandbox
// cuando sigue siendo usable y está cerca de expirar (ver
// SignedSessionState.keepAliveRefresh). Nunca hace bootstrap ni produce una
// URL de challenge — Flutter solo abre el modal de Cloudflare ante una acción
// explícita del usuario. Devuelve un mapa con la forma de SignedSessionStatus
// más el flag "refreshed" para el llamador del keepalive.
func (s *Sandbox) SignedSessionKeepAlive() map[string]any {
	status := map[string]any{
		"authenticated": false,
		"refreshed":     false,
	}
	if s.Session == nil || s.SignedSession == nil {
		status["error"] = "signedSession is not configured"
		return status
	}
	cfg := configSesionFirmadaConDefaults(s.SignedSession)
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		status["error"] = err.Error()
		return status
	}
	status["install_id"] = record.InstallID
	status["session_id"] = record.SessionID
	status["expires_at"] = record.ExpiresAt
	status["authenticated"] = registroSesionFirmadaUsable(record)

	refreshed, err := s.Session.keepAliveRefresh(s.signedKeepAliveClient(), cfg, record)
	if err != nil {
		status["error"] = err.Error()
	}
	if refreshed {
		// Tras un refresh exitoso, el record ya carga el nuevo expiry/sesión.
		status["session_id"] = record.SessionID
		status["expires_at"] = record.ExpiresAt
		status["refreshed"] = true
	}
	status["authenticated"] = registroSesionFirmadaUsable(record)
	return status
}

// SignedSessionProvision runs the startup provisioning step for a sandbox:
// report status, silently refresh a near-expiry session, or silently attempt a
// bootstrap when the session is missing/expired. Never opens UI itself — if
// el gateway pide un challenge humano solo se reporta needs_verification para
// que Flutter decida cuándo mostrar el modal (acción explícita del usuario).
// Acotado por el cliente de corto timeout del keepalive para que un gateway
// colgado no frene el arranque.
