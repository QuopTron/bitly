package gobackend

import "encoding/json"

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
