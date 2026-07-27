package httpclient

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()
	if cfg.Timeout != 30*time.Second {
		t.Errorf("expected 30s timeout, got %v", cfg.Timeout)
	}
	if cfg.MaxIdleConns != 100 {
		t.Errorf("expected 100 MaxIdleConns, got %d", cfg.MaxIdleConns)
	}
	if !cfg.FollowRedirects {
		t.Error("expected FollowRedirects=true")
	}
}

func TestNewClient(t *testing.T) {
	cfg := DefaultConfig()
	client := NewClient(cfg)
	if client == nil {
		t.Fatal("expected non-nil client")
	}
	if client.Timeout != cfg.Timeout {
		t.Errorf("expected %v timeout, got %v", cfg.Timeout, client.Timeout)
	}
}

func TestNewClientWithUTLS(t *testing.T) {
	cfg := DefaultConfig()
	client := NewClientWithUTLS(cfg, "Chrome_120")
	if client == nil {
		t.Fatal("expected non-nil client")
	}
}

func TestNewTransport(t *testing.T) {
	cfg := DefaultConfig()
	transport := NewTransport(cfg, nil)
	if transport == nil {
		t.Fatal("expected non-nil transport")
	}
	if transport.MaxIdleConns != cfg.MaxIdleConns {
		t.Errorf("expected %d MaxIdleConns, got %d", cfg.MaxIdleConns, transport.MaxIdleConns)
	}
	if transport.ForceAttemptHTTP2 {
		t.Error("expected ForceAttemptHTTP2=false")
	}
}

func TestNewTransportWithProxy(t *testing.T) {
	cfg := DefaultConfig()
	cfg.ProxyURL = "http://proxy.example.com:8080"
	transport := NewTransport(cfg, nil)
	if transport.Proxy == nil {
		t.Fatal("expected Proxy function to be set")
	}
	url, err := transport.Proxy(&http.Request{})
	if err != nil {
		t.Fatalf("Proxy() error: %v", err)
	}
	if url == nil || url.String() != "http://proxy.example.com:8080" {
		t.Errorf("expected proxy URL, got %v", url)
	}
}

func TestRandomUserAgent(t *testing.T) {
	ua := RandomUserAgent()
	if ua == "" {
		t.Error("expected non-empty User-Agent")
	}
	if !strings.HasPrefix(ua, "Mozilla") {
		t.Errorf("expected User-Agent to start with Mozilla, got %s", ua)
	}
}

func TestRandomUserAgent_Rotation(t *testing.T) {
	agents := make(map[string]bool)
	for i := 0; i < 10; i++ {
		ua := RandomUserAgent()
		agents[ua] = true
	}
	// At least 3 different User-Agents should be generated
	if len(agents) < 3 {
		t.Errorf("expected at least 3 unique User-Agents, got %d: %v", len(agents), agents)
	}
}
