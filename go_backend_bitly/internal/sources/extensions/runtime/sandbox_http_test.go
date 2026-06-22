package runtime

import (
	"net/http"
	"net/http/httptest"
	neturl "net/url"
	"strings"
	"testing"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func TestIsPrivateDomain_Localhost(t *testing.T) {
	if !isPrivateDomain("localhost") { t.Error("expected true") }
	if !isPrivateDomain("foo.local") { t.Error("expected true for .local") }
}

func TestIsPrivateDomain_LocalIPs(t *testing.T) {
	if !isPrivateDomain("127.0.0.1") { t.Error("expected true for 127.x") }
	if !isPrivateDomain("10.0.0.1") { t.Error("expected true for 10.x") }
	if !isPrivateDomain("192.168.1.1") { t.Error("expected true for 192.168.x") }
	if !isPrivateDomain("172.16.0.1") { t.Error("expected true for 172.16.x") }
	if !isPrivateDomain("::1") { t.Error("expected true for ::1") }
	if !isPrivateDomain("0.0.0.0") { t.Error("expected true for 0.0.0.0") }
}

func TestIsPrivateDomain_Public(t *testing.T) {
	if isPrivateDomain("example.com") { t.Error("expected false") }
	if isPrivateDomain("8.8.8.8") { t.Error("expected false for 8.8.8.8") }
}

func TestSimpleCookieJar(t *testing.T) {
	jar := newSimpleCookieJar()
	u, _ := neturl.Parse("https://example.com")
	cookie := &http.Cookie{Name: "test", Value: "value"}
	jar.SetCookies(u, []*http.Cookie{cookie})
	cookies := jar.Cookies(u)
	if len(cookies) != 1 { t.Fatalf("expected 1 cookie, got %d", len(cookies)) }
	if cookies[0].Name != "test" { t.Errorf("expected name 'test', got %q", cookies[0].Name) }
}

func TestSimpleCookieJar_HostIsolation(t *testing.T) {
	jar := newSimpleCookieJar()
	example, _ := neturl.Parse("https://example.com")
	other, _ := neturl.Parse("https://other.com")
	jar.SetCookies(example, []*http.Cookie{{Name: "ex", Value: "1"}})
	if len(jar.Cookies(other)) != 0 { t.Error("expected no cookies for other host") }
}

func TestReadExtensionHTTPResponseBody(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("test body"))
	}))
	defer ts.Close()
	req, _ := http.NewRequest("GET", ts.URL, nil)
	resp, err := ts.Client().Do(req)
	if err != nil { t.Fatal(err) }
	defer resp.Body.Close()
	data, err := readExtensionHTTPResponseBody(resp)
	if err != nil { t.Fatal(err) }
	if string(data) != "test body" { t.Errorf("expected 'test body', got %q", string(data)) }
}

func TestReadExtensionHTTPResponseBody_TooLarge(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := strings.Repeat("x", maxExtensionHTTPResponseBytes+1)
		w.Write([]byte(body))
	}))
	defer ts.Close()
	req, _ := http.NewRequest("GET", ts.URL, nil)
	resp, err := ts.Client().Do(req)
	if err != nil { t.Fatal(err) }
	defer resp.Body.Close()
	_, err = readExtensionHTTPResponseBody(resp)
	if err == nil { t.Error("expected error for oversized response") }
}

func TestValidateDomain_RejectHTTP(t *testing.T) {
	mf := &manifest.ExtensionManifest{
		Permissions: manifest.ExtensionPermissions{Network: []string{"*"}},
	}
	err := validateDomain("http://example.com", mf)
	if err == nil { t.Error("expected error for http without AllowHTTP") }
}

func TestValidateDomain_AllowHTTP(t *testing.T) {
	mf := &manifest.ExtensionManifest{
		Permissions: manifest.ExtensionPermissions{Network: []string{"*"}, AllowHTTP: true},
	}
	// Should not error for http with AllowHTTP, but private domain check may still apply
	err := validateDomain("http://8.8.8.8", mf)
	if err != nil {
		// Might still fail for other reasons, but not for scheme
		if strings.Contains(err.Error(), "only https") { t.Error("unexpected scheme error") }
	}
}

func TestValidateDomain_NoScheme(t *testing.T) {
	err := validateDomain("no-scheme", nil)
	if err == nil { t.Error("expected error for no scheme") }
}

func TestValidateDomain_EmbeddedCreds(t *testing.T) {
	mf := &manifest.ExtensionManifest{
		Permissions: manifest.ExtensionPermissions{Network: []string{"*"}, AllowHTTP: true},
	}
	err := validateDomain("http://user:pass@example.com", mf)
	if err == nil { t.Error("expected error for embedded creds") }
}

func TestExtractHeaders(t *testing.T) {
	headers := extractHeaders(goja.FunctionCall{}, 0)
	if headers == nil { t.Error("expected non-nil map") }
	if len(headers) != 0 { t.Errorf("expected empty, got %d", len(headers)) }
}

func TestExtractBody_NoArg(t *testing.T) {
	if body := extractBody(goja.FunctionCall{}, 0); body != "" {
		t.Errorf("expected empty, got %q", body)
	}
}
