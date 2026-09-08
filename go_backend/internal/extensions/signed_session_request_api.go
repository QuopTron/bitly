package extensions

import (
	"net/http"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

func resultadoVerificacionRequerida(authURL string) map[string]any {
	return map[string]any{
		"ok": false, "needsVerification": true,
		"error": "VERIFY_REQUIRED", "open_auth_url": authURL,
		"auth_url": authURL,
	}
}

// authURLSnapshot reads the pending auth URL under the state mutex.
func (s *SignedSessionState) authURLSnapshot() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.AuthURL
}

// SignedFetch executes a signed request for a sandbox.
func (s *Sandbox) SignedFetch(method, requestPath, body string, headers map[string]string) map[string]any {
	if s.Session == nil || s.SignedSession == nil {
		return map[string]any{"ok": false, "error": "signedSession is not configured"}
	}
	cfg := configSesionFirmadaConDefaults(s.SignedSession)
	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return map[string]any{"ok": false, "error": err.Error()}
	}
	return s.Session.signedFetch(client, cfg, record, method, requestPath, []byte(body), headers)
}

// signedHTTPClient returns a shared HTTP client for the sandbox. Its
// transport is wrapped in the shared host breaker so a dead session gateway
// (api.zarz.moe 522 storm) fails fast on bootstrap/exchange/refresh instead of
// waiting out the 30s timeout on every signed request.
func (s *Sandbox) signedHTTPClient() *http.Client {
	if s.httpClient == nil {
		s.httpClient = &http.Client{
			Timeout: 30_000_000_000,
			Transport: httpclient.NewBreakerTransport(&http.Transport{
				DialContext: httpclient.NewDoHDialContext(),
			}),
		}
	}
	return s.httpClient
}
