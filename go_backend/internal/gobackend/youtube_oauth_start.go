package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
)

// StartYoutubeOauth binds the loopback callback listener and returns the
// Google consent URL to open in the system browser.
func StartYoutubeOauth(payload string) string {
	logYoutubeOAuth("start: initializing OAuth flow")
	var p youtubeOauthParams
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return jsonErrorString("payload inválido")
	}
	p.ClientID = strings.TrimSpace(p.ClientID)
	if p.ClientID == "" {
		return jsonErrorString("falta client_id")
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
		return jsonErrorString("no se pudo abrir listener: " + err.Error())
	}
	port := ln.Addr().(*net.TCPAddr).Port
	redirect := fmt.Sprintf("http://127.0.0.1:%d/", port)
	state := urlAleatoria(32)
	verifier := urlAleatoria(48)

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

	// Capture the server pointer locally so the goroutine uses the freshly
	// created server even if another call sets ytOauthServer to nil (the mutex
	// is released before this goroutine runs).
	srv := ytOauthServer
	go func() {
		_ = srv.Serve(ln)
	}()

	params := url.Values{}
	params.Set("client_id", p.ClientID)
	params.Set("redirect_uri", redirect)
	params.Set("response_type", "code")
	params.Set("scope", p.Scope)
	params.Set("access_type", "offline")
	params.Set("prompt", "consent")
	params.Set("state", state)
	params.Set("code_challenge", challengePKCE(verifier))
	params.Set("code_challenge_method", "S256")
	authURL := "https://accounts.google.com/o/oauth2/v2/auth?" + params.Encode()

	out, _ := json.Marshal(map[string]interface{}{
		"ok":           true,
		"auth_url":     authURL,
		"redirect_uri": redirect,
	})
	return string(out)
}
