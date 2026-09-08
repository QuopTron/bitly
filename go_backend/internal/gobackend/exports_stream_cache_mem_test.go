package gobackend

import (
	"os"
	"testing"
	"time"
)

func TestStreamFailCacheMemory(t *testing.T) {
	if _, hit := streamFailGet("isrc:XYZ"); hit {
		t.Fatal("expected miss on fresh key")
	}

	streamFailSet("isrc:XYZ", "all providers failed", "no_stream", "ytmusic-spotiflac")
	e, hit := streamFailGet("isrc:XYZ")
	if !hit {
		t.Fatal("expected hit after Set")
	}
	if e.err != "all providers failed" || e.errorType != "no_stream" || e.service != "ytmusic-spotiflac" {
		t.Fatalf("entry mismatch: %+v", e)
	}

	// Expired memory entry is a miss from memory but disk may still hold it.
	streamFailMu.Lock()
	streamFailCache["isrc:XYZ"] = streamFailEntry{at: time.Now().Add(-streamFailMemoryTTL - time.Second), err: "old"}
	streamFailMu.Unlock()
	if _, hit := streamFailGet("isrc:XYZ"); hit {
		t.Fatal("expected miss when memory expired and no disk entry")
	}

	streamFailClear("isrc:XYZ")
	if _, hit := streamFailGet("isrc:XYZ"); hit {
		t.Fatal("expected miss after Clear")
	}
}

func TestStreamFailKeyPicksStrongestIdentifier(t *testing.T) {
	if got := streamFailKey("", "", "", "", "", "raw-id"); got != "raw-id" {
		t.Fatalf("expected raw id fallback, got %q", got)
	}
	if got := streamFailKey("", "spot:123", "", "", "", "raw-id"); got != "spot:123" {
		t.Fatalf("expected cross-provider id, got %q", got)
	}
	if got := streamFailKey("US-XYZ-123", "spot:123", "", "", "", "raw-id"); got != "US-XYZ-123" {
		t.Fatalf("expected ISRC priority, got %q", got)
	}
	if got := streamFailKey("", "", "", "", "", ""); got != "" {
		t.Fatalf("expected empty key, got %q", got)
	}
}

func TestStreamFailCacheDiskPersistence(t *testing.T) {
	// Point the download dir at a temp folder and force the path to resolve
	// there, then verify a failure survives a simulated "restart" (memory map
	// wiped, same dir on disk).
	dir := t.TempDir()
	old := downloadDir
	downloadDir = dir
	defer func() { downloadDir = old }()

	streamFailMu.Lock()
	streamFailCache = map[string]streamFailEntry{}
	streamFailMu.Unlock()

	streamFailSet("isrc:DISK1", "all providers failed", "no_stream", "soundcloud")
	path := streamFailPersistPathLocked()
	if path == "" {
		t.Fatal("expected a persist path once download dir is set")
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("expected persisted file at %s: %v", path, err)
	}

	// Simulate restart: drop the whole in-memory map.
	streamFailMu.Lock()
	streamFailCache = map[string]streamFailEntry{}
	streamFailMu.Unlock()

	e, hit := streamFailGet("isrc:DISK1")
	if !hit {
		t.Fatal("expected disk hit after simulated restart")
	}
	if e.err != "all providers failed" {
		t.Fatalf("disk entry mismatch: %+v", e)
	}
}
