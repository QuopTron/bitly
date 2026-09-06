package gobackend

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// =========================================================================
// YOUTUBE OAUTH (Google account sign-in for InnerTube playback)
// =========================================================================
//
// Flow (non-invasive, token never leaves the device except to Google):
//   1. StartYoutubeOauth  — binds a 127.0.0.1 loopback listener, generates
//      PKCE verifier/state and returns the Google consent URL. The Dart side
//      opens it in the system browser; the user signs in on Google's page.
//   2. Google redirects the browser to http://127.0.0.1:PORT/?code=...&state=...
//      which is served by the in-process listener (same trick as the local
//      streaming proxy, so it works on Android where Chrome can reach the
//      device loopback).
//   3. PollYoutubeOauth    — returns the captured code once the browser has
//      been redirected back.
//   4. ExchangeYoutubeOauth— swaps the code for access + refresh tokens via
//      oauth2.googleapis.com (PKCE: code_verifier from step 1).
//   5. RefreshYoutubeOauth — refreshes a stored access token when needed.
//
// All state is in-memory only; the client id/secret are passed per call from
// the app's own settings storage, never logged.

var (
	ytOauthMu sync.Mutex

	ytOauthServer  *http.Server
	ytOauthCode    string
	ytOauthErr     string
	ytOauthState   string
	ytOauthVerifier string
	ytOauthClientID string
	ytOauthSecret  string
	ytOauthRedirect string
)

func randURL(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("r%d", time.Now().UnixNano())
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func pkceChallenge(verifier string) string {
	sum := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}

// youtubeOauthParams decodes {client_id, client_secret, scope} from the RPC
// payload. client_secret is optional for PKCE (desktop clients), but sending
// it makes the token endpoint accept the exchange even without PKCE support.
type youtubeOauthParams struct {
	ClientID     string `json:"client_id"`
	ClientSecret string `json:"client_secret"`
	Scope        string `json:"scope"`
}

// StartYoutubeOauth binds the loopback callback listener and returns the
// Google consent URL to open in the system browser.
func StartYoutubeOauth(payload string) string {
	var p youtubeOauthParams
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return jsonErrorStr("payload inválido")
	}
	p.ClientID = strings.TrimSpace(p.ClientID)
	if p.ClientID == "" {
		return jsonErrorStr("falta client_id")
	}
	if p.Scope == "" {
		p.Scope = "https://www.googleapis.com/auth/youtube.readonly"
	}

	ytOauthMu.Lock()
	defer ytOauthMu.Unlock()

	// Tear down any stale listener first.
	if ytOauthServer != nil {
		_ = ytOauthServer.Close()
		ytOauthServer = nil
	}
	ytOauthCode = ""
	ytOauthErr = ""
	ytOauthClientID = p.ClientID
	ytOauthSecret = p.ClientSecret

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return jsonErrorStr("no se pudo abrir listener: " + err.Error())
	}
	port := ln.Addr().(*net.TCPAddr).Port
	redirect := fmt.Sprintf("http://127.0.0.1:%d/", port)
	state := randURL(32)
	verifier := randURL(48)

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		gotState := q.Get("state")
		code := q.Get("code")
		errStr := q.Get("error")
		ytOauthMu.Lock()
		if gotState != "" && gotState == ytOauthState {
			if code != "" {
				ytOauthCode = code
			} else if errStr != "" {
				ytOauthErr = errStr
			}
		}
		ytOauthMu.Unlock()
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		io.WriteString(w, "<html><body><h2>✅ Sesión recibida</h2><p>Ya puedes volver a la app.</p><script>window.close()</script></body></html>")
	})

	ytOauthServer = &http.Server{Handler: mux}
	ytOauthState = state
	ytOauthVerifier = verifier
	ytOauthRedirect = redirect

	go func() {
		_ = ytOauthServer.Serve(ln)
	}()

	params := url.Values{}
	params.Set("client_id", p.ClientID)
	params.Set("redirect_uri", redirect)
	params.Set("response_type", "code")
	params.Set("scope", p.Scope)
	params.Set("access_type", "offline")
	params.Set("prompt", "consent")
	params.Set("state", state)
	params.Set("code_challenge", pkceChallenge(verifier))
	params.Set("code_challenge_method", "S256")
	authURL := "https://accounts.google.com/o/oauth2/v2/auth?" + params.Encode()

	out, _ := json.Marshal(map[string]interface{}{
		"ok":           true,
		"auth_url":     authURL,
		"redirect_uri": redirect,
	})
	return string(out)
}

// PollYoutubeOauth reports whether the browser callback arrived.
func PollYoutubeOauth(payload string) string {
	ytOauthMu.Lock()
	defer ytOauthMu.Unlock()
	if ytOauthErr != "" {
		out, _ := json.Marshal(map[string]interface{}{"ok": false, "done": true, "error": ytOauthErr})
		return string(out)
	}
	if ytOauthCode != "" {
		out, _ := json.Marshal(map[string]interface{}{"ok": true, "done": true, "code": ytOauthCode})
		return string(out)
	}
	return `{"ok":false,"done":false}`
}

// StopYoutubeOauth closes the loopback callback listener (call after exchange).
func StopYoutubeOauth(payload string) string {
	ytOauthMu.Lock()
	defer ytOauthMu.Unlock()
	if ytOauthServer != nil {
		_ = ytOauthServer.Close()
		ytOauthServer = nil
	}
	return `{"ok":true}`
}

// ExchangeYoutubeOauth swaps the authorization code for tokens. Payload:
// {code}. Client id/secret come from the StartYoutubeOauth call.
func ExchangeYoutubeOauth(payload string) string {
	var p struct {
		Code string `json:"code"`
	}
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return jsonErrorStr("payload inválido")
	}
	ytOauthMu.Lock()
	clientID := ytOauthClientID
	secret := ytOauthSecret
	redirect := ytOauthRedirect
	verifier := ytOauthVerifier
	ytOauthMu.Unlock()

	if strings.TrimSpace(p.Code) == "" {
		return jsonErrorStr("falta code")
	}

	form := url.Values{}
	form.Set("code", strings.TrimSpace(p.Code))
	form.Set("client_id", clientID)
	if secret != "" {
		form.Set("client_secret", secret)
	}
	form.Set("redirect_uri", redirect)
	form.Set("code_verifier", verifier)
	form.Set("grant_type", "authorization_code")

	tokens, err := googleTokenCall(form)
	if err != nil {
		return jsonErrorStr("intercambio falló: " + err.Error())
	}
	out, _ := json.Marshal(tokens)
	return string(out)
}

// RefreshYoutubeOauth refreshes an access token. Payload:
// {client_id, client_secret, refresh_token}.
func RefreshYoutubeOauth(payload string) string {
	var p struct {
		ClientID     string `json:"client_id"`
		ClientSecret string `json:"client_secret"`
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return jsonErrorStr("payload inválido")
	}
	if strings.TrimSpace(p.RefreshToken) == "" {
		return jsonErrorStr("falta refresh_token")
	}
	form := url.Values{}
	form.Set("client_id", strings.TrimSpace(p.ClientID))
	if strings.TrimSpace(p.ClientSecret) != "" {
		form.Set("client_secret", strings.TrimSpace(p.ClientSecret))
	}
	form.Set("refresh_token", strings.TrimSpace(p.RefreshToken))
	form.Set("grant_type", "refresh_token")

	tokens, err := googleTokenCall(form)
	if err != nil {
		return jsonErrorStr("refresh falló: " + err.Error())
	}
	out, _ := json.Marshal(tokens)
	return string(out)
}

type googleTokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	TokenType    string `json:"token_type"`
	Error        string `json:"error"`
	ErrorDesc    string `json:"error_description"`
}

func googleTokenCall(form url.Values) (map[string]interface{}, error) {
	client := &http.Client{Timeout: 25 * time.Second}
	resp, err := client.PostForm("https://oauth2.googleapis.com/token", form)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var tr googleTokenResponse
	if err := json.Unmarshal(body, &tr); err != nil {
		return nil, fmt.Errorf("respuesta inválida (%d)", resp.StatusCode)
	}
	if tr.Error != "" {
		return nil, fmt.Errorf("%s: %s", tr.Error, tr.ErrorDesc)
	}
	if tr.AccessToken == "" {
		return nil, fmt.Errorf("sin access_token (HTTP %d)", resp.StatusCode)
	}
	return map[string]interface{}{
		"ok":            true,
		"access_token":  tr.AccessToken,
		"refresh_token": tr.RefreshToken,
		"expires_in":    tr.ExpiresIn,
		"token_type":    tr.TokenType,
	}, nil
}

// logYouTubeOAuth is a tiny helper so future debugging does not leak secrets.
func logYouTubeOAuth(format string, args ...interface{}) {
	log.Printf("[youtube-oauth] "+format, args...)
}
