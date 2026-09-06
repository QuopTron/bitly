package gobackend

import (
	"encoding/json"
	"net/url"
	"strings"
	"testing"
)

func TestStartPollStopYoutubeOauth(t *testing.T) {
	payload := `{"client_id":"test-client.apps.googleusercontent.com","client_secret":"test-secret"}`
	raw := StartYoutubeOauth(payload)
	var res map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &res); err != nil {
		t.Fatalf("StartYoutubeOauth returned invalid JSON: %v (%s)", err, raw)
	}
	if res["ok"] != true {
		t.Fatalf("StartYoutubeOauth failed: %s", raw)
	}
	authURL, _ := res["auth_url"].(string)
	redirect, _ := res["redirect_uri"].(string)
	if authURL == "" {
		t.Fatal("missing auth_url")
	}
	if !strings.HasPrefix(redirect, "http://127.0.0.1:") {
		t.Fatalf("redirect must be loopback, got %s", redirect)
	}

	u, err := url.Parse(authURL)
	if err != nil {
		t.Fatal(err)
	}
	q := u.Query()
	if q.Get("redirect_uri") != redirect {
		t.Fatalf("redirect_uri mismatch: %s vs %s", q.Get("redirect_uri"), redirect)
	}
	if q.Get("code_challenge") == "" || q.Get("code_challenge_method") != "S256" {
		t.Fatal("missing PKCE params")
	}
	if q.Get("state") == "" {
		t.Fatal("missing state")
	}
	if q.Get("client_id") != "test-client.apps.googleusercontent.com" {
		t.Fatal("client_id not forwarded")
	}

	// Nothing captured yet.
	if poll := PollYoutubeOauth(""); !strings.Contains(poll, `"done":false`) {
		t.Fatalf("expected pending poll, got %s", poll)
	}

	// Stop must be idempotent.
	if stop := StopYoutubeOauth(""); stop != `{"ok":true}` {
		t.Fatalf("stop failed: %s", stop)
	}
	if stop := StopYoutubeOauth(""); stop != `{"ok":true}` {
		t.Fatalf("second stop failed: %s", stop)
	}
}

func TestYoutubeOauthRequiresClientID(t *testing.T) {
	raw := StartYoutubeOauth(`{}`)
	if !strings.Contains(raw, "falta client_id") {
		t.Fatalf("expected missing client_id error, got %s", raw)
	}
}
