package extensions

import (
	"net/http"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// doSignedRequest signs and executes a request against the session gateway.
func (s *SignedSessionState) doSignedRequest(
	client *http.Client,
	cfg SignedSessionConfig,
	record *signedSessionRecord,
	method, requestPath string,
	body []byte,
	extraHeaders map[string]string,
) (*http.Response, []byte, map[string]any, error) {
	fullURL, err := signedSessionURL(cfg, requestPath)
	if err != nil {
		return nil, nil, nil, err
	}
	req, err := signAndBuildRequest(cfg, record, method, fullURL, body, extraHeaders)
	if err != nil {
		return nil, nil, nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, nil, err
	}
	respBody, err := readSignedBody(resp)
	if err != nil {
		return nil, nil, nil, err
	}
	headers := make(map[string]any)
	for k, v := range resp.Header {
		if len(v) == 1 {
			headers[k] = v[0]
		} else {
			headers[k] = v
		}
	}
	return resp, respBody, headers, nil
}

// signedFetch executes a signed request, handling bootstrap/verification and
// stale-session retries. It returns the JS-facing response object.
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
				return verificationRequiredResult(authURL)
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
			return verificationRequiredResult(authURL)
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
			return verificationRequiredResult(authURL)
		}
		if authErr == nil && signedSessionRecordIsUsable(record) {
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
func verificationRequiredResult(authURL string) map[string]any {
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
	cfg := signedSessionConfigWithDefaults(s.SignedSession)
	client := s.signedHTTPClient()
	record, err := s.Session.loadOrInit(s.DataDir, cfg)
	if err != nil {
		return map[string]any{"ok": false, "error": err.Error()}
	}
	return s.Session.signedFetch(client, cfg, record, method, requestPath, []byte(body), headers)
}

// signedHTTPClient returns a shared HTTP client for the sandbox.
func (s *Sandbox) signedHTTPClient() *http.Client {
	if s.httpClient == nil {
		s.httpClient = &http.Client{
			Timeout: 30_000_000_000,
			Transport: &http.Transport{
				DialContext: httpclient.NewDoHDialContext(),
			},
		}
	}
	return s.httpClient
}
