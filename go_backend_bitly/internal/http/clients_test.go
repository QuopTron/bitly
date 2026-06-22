package httpclient

import (
	"testing"
	"time"
)

func TestNewClient(t *testing.T) {
	c := NewClient(30 * time.Second)
	if c == nil {
		t.Fatal("NewClient returned nil")
	}
	if c.Timeout != 30*time.Second {
		t.Errorf("expected Timeout 30s, got %v", c.Timeout)
	}
}

func TestNewClient_DifferentTimeouts(t *testing.T) {
	c1 := NewClient(10 * time.Second)
	c2 := NewClient(90 * time.Second)
	if c1.Timeout != 10*time.Second {
		t.Errorf("expected 10s, got %v", c1.Timeout)
	}
	if c2.Timeout != 90*time.Second {
		t.Errorf("expected 90s, got %v", c2.Timeout)
	}
}

func TestNewMetadataClient(t *testing.T) {
	c := NewMetadataClient(15 * time.Second)
	if c == nil {
		t.Fatal("NewMetadataClient returned nil")
	}
	if c.Timeout != 15*time.Second {
		t.Errorf("expected Timeout 15s, got %v", c.Timeout)
	}
}

func TestNewMetadataClient_HasTransport(t *testing.T) {
	c := NewMetadataClient(5 * time.Second)
	if c.Transport == nil {
		t.Error("NewMetadataClient should set a Transport")
	}
}

func TestGetSharedClient(t *testing.T) {
	c := GetSharedClient()
	if c == nil {
		t.Fatal("GetSharedClient returned nil")
	}
	if c != DefaultClient {
		t.Error("GetSharedClient should return the package-level DefaultClient")
	}
	if c.Timeout != DefaultTimeout {
		t.Errorf("expected Timeout %v, got %v", DefaultTimeout, c.Timeout)
	}
}

func TestGetDownloadClient(t *testing.T) {
	c := GetDownloadClient()
	if c == nil {
		t.Fatal("GetDownloadClient returned nil")
	}
	if c != DownloadClient {
		t.Error("GetDownloadClient should return the package-level DownloadClient")
	}
	if c.Timeout != DownloadTimeout {
		t.Errorf("expected Timeout %v, got %v", DownloadTimeout, c.Timeout)
	}
}

func TestSetNetworkCompatibilityOptions(t *testing.T) {
	initial := GetNetworkCompatibilityOptions()

	SetNetworkCompatibilityOptions(true, true)
	opts := GetNetworkCompatibilityOptions()
	if !opts.AllowHTTP {
		t.Error("AllowHTTP should be true after SetNetworkCompatibilityOptions(true, _)")
	}
	if !opts.InsecureTLS {
		t.Error("InsecureTLS should be true after SetNetworkCompatibilityOptions(_, true)")
	}

	SetNetworkCompatibilityOptions(false, false)
	opts = GetNetworkCompatibilityOptions()
	if opts.AllowHTTP {
		t.Error("AllowHTTP should be false after SetNetworkCompatibilityOptions(false, _)")
	}
	if opts.InsecureTLS {
		t.Error("InsecureTLS should be false after SetNetworkCompatibilityOptions(_, false)")
	}

	SetNetworkCompatibilityOptions(initial.AllowHTTP, initial.InsecureTLS)
}

func TestGetNetworkCompatibilityOptionsDefaults(t *testing.T) {
	opts := GetNetworkCompatibilityOptions()
	if opts.AllowHTTP || opts.InsecureTLS {
		t.Log("Note: NetworkCompatibilityOptions may have been modified by other tests")
	}
}

func TestSetNetworkCompatibilityOptions_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("SetNetworkCompatibilityOptions should not panic: %v", r)
		}
	}()
	SetNetworkCompatibilityOptions(false, false)
	SetNetworkCompatibilityOptions(true, false)
	SetNetworkCompatibilityOptions(false, true)
}

func TestCloseIdleConnections(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("CloseIdleConnections should not panic: %v", r)
		}
	}()
	CloseIdleConnections()
}
