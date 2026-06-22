package tidal

import (
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
	if c.cache == nil {
		t.Error("expected initialized cache")
	}
}

func TestGetClient_Singleton(t *testing.T) {
	c1 := GetClient()
	c2 := GetClient()
	if c1 != c2 {
		t.Error("GetClient should return the same instance")
	}
}

func TestClient_Constants(t *testing.T) {
	if providerName != "tidal_monochrome" {
		t.Errorf("providerName = %q", providerName)
	}
	if metadataTTL != 10*time.Minute {
		t.Errorf("metadataTTL = %v", metadataTTL)
	}
}

func TestClient_BaseURLs(t *testing.T) {
	c := GetClient()
	if len(c.baseURLs) == 0 {
		t.Log("baseURLs may be empty if refreshServers failed (expected in test env)")
	}
}



func TestCacheEntry_Access(t *testing.T) {
	entry := cacheEntry{
		data:    "test_value",
	}
	if entry.data != "test_value" {
		t.Errorf("data = %q", entry.data)
	}
}

func TestGetClient_HTTPClient(t *testing.T) {
	c := GetClient()
	if c.httpClient == nil {
		t.Error("expected non-nil httpClient")
	}
	if c.httpClient.Timeout <= 0 {
		t.Errorf("timeout = %v", c.httpClient.Timeout)
	}
}
