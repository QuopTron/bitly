package store

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRequireHTTPSURL(t *testing.T) {
	tests := []struct {
		name, rawURL, ctx string
		wantErr           bool
	}{
		{"valid", "https://example.com/r.json", "registry", false},
		{"empty", "", "registry", true},
		{"http_scheme", "http://example.com/r.json", "registry", true},
		{"invalid", "://bad", "registry", true},
		{"no_host", "https:///path", "registry", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := requireHTTPSURL(tt.rawURL, tt.ctx)
			if (err != nil) != tt.wantErr {
				t.Errorf("requireHTTPSURL(%q,%q) err=%v wantErr=%v", tt.rawURL, tt.ctx, err, tt.wantErr)
			}
		})
	}
}

func TestHttpGet(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"ok":true}`))
	}))
	defer ts.Close()

	body, status, err := httpGet(ts.URL, 5*time.Second)
	if err != nil { t.Fatal(err) }
	if status != http.StatusOK { t.Errorf("status=%d want=%d", status, http.StatusOK) }
	if string(body) != `{"ok":true}` { t.Errorf("body=%s", string(body)) }
}

func TestHttpGetError(t *testing.T) {
	_, _, err := httpGet("http://127.0.0.1:1/", time.Millisecond)
	if err == nil { t.Error("expected error") }
}

func TestSetAndGetRegistryURL(t *testing.T) {
	s := &Store{}
	s.SetRegistryURL("https://example.com/new")
	if got := s.GetRegistryURL(); got != "https://example.com/new" {
		t.Errorf("GetRegistryURL()=%q", got)
	}
}

func TestSetRegistryURLSame(t *testing.T) {
	s := &Store{registryURL: "https://example.com/r"}
	s.SetRegistryURL("https://example.com/r")
	if s.cache != nil { t.Error("cache should still be nil") }
}

func TestResolveRegistryURLRaw(t *testing.T) {
	s := &Store{}
	u := "https://raw.githubusercontent.com/owner/repo/main/registry.json"
	got, err := s.ResolveRegistryURL(u)
	if err != nil { t.Fatal(err) }
	if got != u { t.Errorf("got=%q want=%q", got, u) }
}

func TestResolveRegistryURLNonGitHub(t *testing.T) {
	s := &Store{}
	u := "https://my-server.com/reg.json"
	got, err := s.ResolveRegistryURL(u)
	if err != nil { t.Fatal(err) }
	if got != u { t.Errorf("got=%q want=%q", got, u) }
}

func TestResolveRegistryURLEmpty(t *testing.T) {
	s := &Store{}
	_, err := s.ResolveRegistryURL("")
	if err == nil { t.Error("expected error") }
}

func TestResolveRegistryURLInvalidGitHub(t *testing.T) {
	s := &Store{}
	_, err := s.ResolveRegistryURL("https://github.com/onlyowner")
	if err == nil { t.Error("expected error") }
}

func TestResolveRegistryURLGitHubFallback(t *testing.T) {
	s := &Store{}
	got, err := s.ResolveRegistryURL("https://github.com/no-such-user/no-such-repo")
	if err != nil { t.Fatal(err) }
	want := "https://raw.githubusercontent.com/no-such-user/no-such-repo/main/registry.json"
	if got != want { t.Errorf("got=%q want=%q", got, want) }
}

func TestResolveRegistryURLHTTPGitHub(t *testing.T) {
	s := &Store{}
	got, err := s.ResolveRegistryURL("http://github.com/owner/repo")
	if err != nil { t.Fatal(err) }
	if got != "https://raw.githubusercontent.com/owner/repo/main/registry.json" {
		t.Errorf("got=%q", got)
	}
}

func TestResolveRegistryURLGitSuffix(t *testing.T) {
	s := &Store{}
	got, err := s.ResolveRegistryURL("https://github.com/owner/repo.git")
	if err != nil { t.Fatal(err) }
	if got != "https://raw.githubusercontent.com/owner/repo/main/registry.json" {
		t.Errorf("got=%q", got)
	}
}
