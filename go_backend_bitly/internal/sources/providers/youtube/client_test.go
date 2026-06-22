package youtube

import (
	"net/http"
	"testing"
	"time"
)

func TestGetClient(t *testing.T) {
	c := GetClient()
	if c == nil {
		t.Fatal("expected non-nil Client")
	}
	if c.httpClient == nil {
		t.Error("expected non-nil httpClient")
	}
}

func TestGetClient_Singleton(t *testing.T) {
	c1 := GetClient()
	c2 := GetClient()
	if c1 != c2 {
		t.Error("GetClient should return the same instance")
	}
}

func TestSetAndroidMode(t *testing.T) {
	c := GetClient()
	c.SetAndroidMode()
	if c.innertubeUA != "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36" {
		t.Errorf("innertubeUA = %q", c.innertubeUA)
	}
}

func TestSetYtDlpPathFn(t *testing.T) {
	c := GetClient()
	called := false
	c.SetYtDlpPathFn(func() string {
		called = true
		return "/custom/yt-dlp"
	})
	if c.ytdlpPathFn == nil {
		t.Fatal("expected ytdlpPathFn to be set")
	}
	path := c.getYtDlpPath()
	if !called {
		t.Error("expected path function to be called")
	}
	if path != "/custom/yt-dlp" {
		t.Errorf("path = %q", path)
	}
}

func TestClient_Constants(t *testing.T) {
	if ytDlpSearchTimeout != 30*time.Second {
		t.Errorf("ytDlpSearchTimeout = %v", ytDlpSearchTimeout)
	}
	if ytDlpDownloadTimeout != 5*time.Minute {
		t.Errorf("ytDlpDownloadTimeout = %v", ytDlpDownloadTimeout)
	}
	if globalSearchTimeout != 15*time.Second {
		t.Errorf("globalSearchTimeout = %v", globalSearchTimeout)
	}
	if searchFailureCacheTTL != 5*time.Minute {
		t.Errorf("searchFailureCacheTTL = %v", searchFailureCacheTTL)
	}
}

func TestClient_UserAgent(t *testing.T) {
	c := GetClient()
	if c.innertubeUA == "" {
		t.Error("expected non-empty innertubeUA")
	}
}

func TestClient_Transport(t *testing.T) {
	c := GetClient()
	if transport, ok := c.httpClient.Transport.(*http.Transport); ok {
		if !transport.DisableKeepAlives {
			t.Error("expected DisableKeepAlives to be true")
		}
	}
}

func TestClient_Timeout(t *testing.T) {
	c := GetClient()
	if c.httpClient.Timeout != 10*time.Second {
		t.Errorf("timeout = %v, want 10s", c.httpClient.Timeout)
	}
}
