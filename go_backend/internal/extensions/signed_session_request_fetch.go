package extensions

import (
	"net/http"
)

func (s *SignedSessionState) signedFetch(
	client *http.Client,
	cfg SignedSessionConfig,
	record *signedSessionRecord,
	method, requestPath string,
	body []byte,
	extraHeaders map[string]string,
) map[string]any {
	if record == nil || record.SessionID == "" || record.SessionSecret == "" {
		if err := s.ensureSignedSession(client, cfg, record); err != nil {
			authURL, authErr := s.bootstrapWithGuard(client, cfg, record)
			if authURL != "" {
				return resultadoVerificacionRequerida(authURL)
			}
			if authErr != nil {
				return map[string]any{"ok": false, "error": authErr.Error()}
			}
		}
	}

	resp, respBody, respHeaders, err := s.doSignedRequest(client, cfg, record, method, requestPath, body, extraHeaders)
	if err != nil {
		return map[string]any{"ok": false, "error": err.Error()}
	}
	contract, hasContract := parseSignedErrorContract(respBody)

	// VERIFY_REQUIRED (428) from the gateway means human verification needed.
	if resp.StatusCode == http.StatusPreconditionRequired && hasContract && contract.Code == "VERIFY_REQUIRED" {
		authURL := s.authURLSnapshot()
		if authURL == "" {
			authURL, _ = s.bootstrapWithGuard(client, cfg, record)
		}
		if authURL != "" {
			return resultadoVerificacionRequerida(authURL)
		}
	}

	// SESSION_INVALID from the gateway means our session was revoked.
	if resp.StatusCode == http.StatusUnauthorized && hasContract &&
		contract.Origin == "gateway" && contract.Code == "SESSION_INVALID" {
		s.mu.Lock()
		record.SessionID = ""
		record.SessionSecret = ""
		record.ExpiresAt = ""
		s.mu.Unlock()
		authURL, authErr := s.bootstrapWithGuard(client, cfg, record)
		if authURL != "" {
			return resultadoVerificacionRequerida(authURL)
		}
		if authErr == nil && registroSesionFirmadaUsable(record) {
			// Bootstrap silently provisioned a new session; retry once.
			resp, respBody, respHeaders, err = s.doSignedRequest(client, cfg, record, method, requestPath, body, extraHeaders)
			if err != nil {
				return map[string]any{"ok": false, "error": err.Error()}
			}
			contract, hasContract = parseSignedErrorContract(respBody)
		}
	}

	result := map[string]any{
		"statusCode": resp.StatusCode,
		"status":     resp.StatusCode,
		"ok":         resp.StatusCode >= 200 && resp.StatusCode < 300,
		"body":       string(respBody),
		"headers":    respHeaders,
	}
	if hasContract {
		result["error"] = contract.Error
		result["code"] = contract.Code
		result["origin"] = contract.Origin
		result["action"] = contract.Action
		result["retryable"] = contract.Retryable
		result["retryMode"] = contract.RetryMode
	}
	if authURL := s.authURLSnapshot(); authURL != "" {
		result["needsVerification"] = true
		result["open_auth_url"] = authURL
		result["auth_url"] = authURL
	}
	return result
}

// verificationRequiredResult builds the JS-facing object that signals Flutter
// to open the Cloudflare challenge URL in a WebView.
