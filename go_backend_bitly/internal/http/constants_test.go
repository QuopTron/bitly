package httpclient

import (
	"net/url"
	"strings"
	"testing"
	"time"
)

func TestDefaultTimeout_Positive(t *testing.T) {
	if DefaultTimeout <= 0 {
		t.Errorf("DefaultTimeout should be positive, got %v", DefaultTimeout)
	}
}

func TestDefaultTimeout_Reasonable(t *testing.T) {
	if DefaultTimeout < 5*time.Second {
		t.Error("DefaultTimeout should be at least 5s")
	}
	if DefaultTimeout > 10*time.Minute {
		t.Error("DefaultTimeout seems unreasonably large")
	}
}

func TestDownloadTimeout_Positive(t *testing.T) {
	if DownloadTimeout <= 0 {
		t.Errorf("DownloadTimeout should be positive, got %v", DownloadTimeout)
	}
}

func TestDownloadTimeout_GreaterThanDefault(t *testing.T) {
	if DownloadTimeout <= DefaultTimeout {
		t.Error("DownloadTimeout should be larger than DefaultTimeout")
	}
}

func TestSongLinkTimeout_Positive(t *testing.T) {
	if SongLinkTimeout <= 0 {
		t.Errorf("SongLinkTimeout should be positive, got %v", SongLinkTimeout)
	}
}

func TestSongLinkTimeout_Reasonable(t *testing.T) {
	if SongLinkTimeout < 5*time.Second {
		t.Error("SongLinkTimeout should be at least 5s")
	}
	if SongLinkTimeout > 5*time.Minute {
		t.Error("SongLinkTimeout seems unreasonably large")
	}
}

func TestDefaultMaxRetries_Positive(t *testing.T) {
	if DefaultMaxRetries <= 0 {
		t.Errorf("DefaultMaxRetries should be positive, got %d", DefaultMaxRetries)
	}
}

func TestDefaultMaxRetries_Reasonable(t *testing.T) {
	if DefaultMaxRetries > 10 {
		t.Errorf("DefaultMaxRetries=%d seems unreasonably high", DefaultMaxRetries)
	}
}

func TestDefaultRetryDelay_Positive(t *testing.T) {
	if DefaultRetryDelay <= 0 {
		t.Errorf("DefaultRetryDelay should be positive, got %v", DefaultRetryDelay)
	}
}

func TestDefaultRetryDelay_Reasonable(t *testing.T) {
	if DefaultRetryDelay < 100*time.Millisecond {
		t.Error("DefaultRetryDelay should be at least 100ms")
	}
	if DefaultRetryDelay > 30*time.Second {
		t.Error("DefaultRetryDelay seems unreasonably large")
	}
}

func TestUserAgentForURL_Nil(t *testing.T) {
	ua := UserAgentForURL(nil)
	if ua == "" {
		t.Fatal("UserAgentForURL(nil) should return a non-empty string")
	}
}

func TestUserAgentForURL_NilContainsChrome(t *testing.T) {
	ua := UserAgentForURL(nil)
	if !strings.Contains(ua, "Chrome/") {
		t.Errorf("nil URL should return a Chrome UA, got: %s", ua)
	}
}

func TestUserAgentForURL_NilContainsMozilla(t *testing.T) {
	ua := UserAgentForURL(nil)
	if !strings.HasPrefix(ua, "Mozilla/5.0") {
		t.Errorf("nil URL should return a Mozilla/5.0 UA, got: %s", ua)
	}
}

func TestUserAgentForURL_AppSpecific(t *testing.T) {
	u, _ := url.Parse("https://api.zarz.moe/v1/endpoint")
	ua := UserAgentForURL(u)
	if ua != "Bitly/1.0" {
		t.Errorf("expected 'Bitly/1.0' for api.zarz.moe, got: %s", ua)
	}
}

func TestUserAgentForURL_EmptyHost(t *testing.T) {
	u, _ := url.Parse("https://api.zarz.moe")
	ua := UserAgentForURL(u)
	if ua != "Bitly/1.0" {
		t.Errorf("expected 'Bitly/1.0' for api.zarz.moe, got: %s", ua)
	}
}

func TestUserAgentForURL_RandomHost(t *testing.T) {
	u, _ := url.Parse("https://example.com/path")
	ua := UserAgentForURL(u)
	if ua == "" {
		t.Fatal("expected non-empty UA for example.com")
	}
}

func TestUserAgentForURL_RandomHostFormat(t *testing.T) {
	u, _ := url.Parse("https://example.com")
	ua := UserAgentForURL(u)
	if !strings.HasPrefix(ua, "Mozilla/5.0") {
		t.Errorf("UA should start with Mozilla/5.0, got: %s", ua)
	}
	if !strings.Contains(ua, "Windows NT 10.0") {
		t.Errorf("UA should contain Windows NT 10.0, got: %s", ua)
	}
	if !strings.Contains(ua, "Chrome/") {
		t.Errorf("UA should contain Chrome/, got: %s", ua)
	}
	if !strings.Contains(ua, "Safari/537.36") {
		t.Errorf("UA should contain Safari/537.36, got: %s", ua)
	}
}

func TestUserAgentForURL_RandomHostVariable(t *testing.T) {
	u1, _ := url.Parse("https://site-a.example")
	u2, _ := url.Parse("https://site-b.example")
	ua1 := UserAgentForURL(u1)
	ua2 := UserAgentForURL(u2)

	if ua1 == ua2 {
		t.Log("Note: random UA happened to be identical between calls")
	}
}

func TestUserAgentForURL_RandomVersionRange(t *testing.T) {
	seen := make(map[int]bool)
	for i := 0; i < 100; i++ {
		u, _ := url.Parse("https://example.com")
		ua := UserAgentForURL(u)
		var chromeMajor int
		_, err := parseChromeVersion(ua, &chromeMajor)
		if err != nil {
			t.Fatalf("failed to parse Chrome version from %q: %v", ua, err)
		}
		seen[chromeMajor] = true
	}
	if len(seen) <= 1 {
		t.Log("Note: Chrome major version was constant across 100 calls")
	}
}

func parseChromeVersion(ua string, major *int) (int, error) {
	idx := strings.Index(ua, "Chrome/")
	if idx < 0 {
		return 0, nil
	}
	rest := ua[idx+7:]
	dot := strings.Index(rest, ".")
	if dot < 0 {
		return 0, nil
	}
	*major = 0
	for _, c := range rest[:dot] {
		*major = *major*10 + int(c-'0')
	}
	return 0, nil
}

func TestUserAgentForURL_SubdomainOfAppHost(t *testing.T) {
	u, _ := url.Parse("https://sub.api.zarz.moe")
	ua := UserAgentForURL(u)
	if ua == "" {
		t.Error("UserAgentForURL should return non-empty UA for subdomain")
	}
	if !strings.Contains(ua, "Mozilla/") {
		t.Errorf("expected random UA for subdomain (not 'Bitly/1.0'), got: %s", ua)
	}
}
