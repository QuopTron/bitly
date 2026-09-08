package gobackend

import (
	"encoding/json"
	"net/url"
	"strings"
	"time"
)

func ExchangeYoutubeOauth(payload string) string {
	logYoutubeOAuth("exchange: starting code exchange")
	start := time.Now()

	var p struct {
		Code string `json:"code"`
	}
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return jsonErrorString("payload inválido")
	}
	ytOauthMu.Lock()
	clientID := ytOauthClientID
	secret := ytOauthSecret
	redirect := ytOauthRedirect
	verifier := ytOauthVerifier
	ytOauthMu.Unlock()

	if strings.TrimSpace(p.Code) == "" {
		return jsonErrorString("falta code")
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

	tokens, err := llamadaTokenGoogle(form)
	if err != nil {
		logYoutubeOAuth("exchange: FAILED after %v: %v", time.Since(start), err)
		return jsonErrorString("intercambio falló: " + err.Error())
	}
	logYoutubeOAuth("exchange: OK in %v", time.Since(start))
	out, _ := json.Marshal(tokens)
	return string(out)
}

// RefreshYoutubeOauth refreshes an access token. Payload:
// {client_id, client_secret, refresh_token}.
func RefreshYoutubeOauth(payload string) string {
	logYoutubeOAuth("refresh: starting token refresh")
	start := time.Now()

	var p struct {
		ClientID     string `json:"client_id"`
		ClientSecret string `json:"client_secret"`
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		return jsonErrorString("payload inválido")
	}
	if strings.TrimSpace(p.RefreshToken) == "" {
		return jsonErrorString("falta refresh_token")
	}
	form := url.Values{}
	form.Set("client_id", strings.TrimSpace(p.ClientID))
	if strings.TrimSpace(p.ClientSecret) != "" {
		form.Set("client_secret", strings.TrimSpace(p.ClientSecret))
	}
	form.Set("refresh_token", strings.TrimSpace(p.RefreshToken))
	form.Set("grant_type", "refresh_token")

	tokens, err := llamadaTokenGoogle(form)
	if err != nil {
		logYoutubeOAuth("refresh: FAILED after %v: %v", time.Since(start), err)
		return jsonErrorString("refresh falló: " + err.Error())
	}
	logYoutubeOAuth("refresh: OK in %v", time.Since(start))
	out, _ := json.Marshal(tokens)
	return string(out)
}
