package gobackend

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestSignedSessionSurvivesAndroidInitFlow simulates the Android startup order:
// InitGlobalState (embedded extensions with signed session) → InitExtensionSystem
// → LoadExtensionsFromDir. Before the fix, the latter two replaced extRegistry
// with an empty one, so signedSessionSandbox returned nil and no Cloudflare
// auth URL was ever produced.
func TestSignedSessionSurvivesAndroidInitFlow(t *testing.T) {
	// Reset globals.
	extRegistry = nil
	extSettings = nil

	// 1. InitGlobalState — embedded extensions with signed session.
	state := InitGlobalState()
	if strings.Contains(state, `"error"`) {
		t.Fatalf("InitGlobalState failed: %s", state)
	}
	if !strings.Contains(state, "qobuz-web") {
		t.Fatalf("qobuz-web not registered: %s", state)
	}
	if sb := signedSessionSandbox("qobuz-web"); sb == nil {
		t.Fatal("qobuz-web sandbox missing after InitGlobalState")
	} else if sb.SignedSession == nil {
		t.Fatal("qobuz-web SignedSession not attached after InitGlobalState")
	}

	// 2. Simulate Flutter calling initExtensionSystem with a (possibly stale)
	//    on-disk extensions dir that does NOT contain signedSession in manifest.
	staleDir := t.TempDir()
	extID := "qobuz-web"
	extSub := filepath.Join(staleDir, extID)
	if err := os.MkdirAll(extSub, 0755); err != nil {
		t.Fatal(err)
	}
	// Old manifest without signedSession + old index.js.
	os.WriteFile(filepath.Join(extSub, "manifest.json"), []byte(`{"name":"qobuz-web"}`), 0644)
	os.WriteFile(filepath.Join(extSub, "index.js"), []byte(`function searchTracks(q,l){return[];}`), 0644)

	// JSON-escape the path (Windows backslashes would break the payload).
	escaped := strings.ReplaceAll(staleDir, `\`, `\\`)

	r1 := InitExtensionSystem(`{"extensions_dir":"` + escaped + `","data_dir":"` + escaped + `"}`)
	if strings.Contains(r1, `"error"`) {
		t.Fatalf("InitExtensionSystem failed: %s", r1)
	}

	// The embedded sandbox (with SignedSession) must be preserved.
	if sb := signedSessionSandbox("qobuz-web"); sb == nil {
		t.Fatal("qobuz-web sandbox missing after InitExtensionSystem")
	} else if sb.SignedSession == nil {
		t.Fatal("SignedSession was lost after InitExtensionSystem (extRegistry clobbered)")
	}

	// 3. Simulate loadExtensionsFromDir.
	r2 := LoadExtensionsFromDir(`{"dir_path":"` + escaped + `"}`)
	if strings.Contains(r2, `"error"`) {
		t.Fatalf("LoadExtensionsFromDir failed: %s", r2)
	}
	if sb := signedSessionSandbox("qobuz-web"); sb == nil {
		t.Fatal("qobuz-web sandbox missing after LoadExtensionsFromDir")
	} else if sb.SignedSession == nil {
		t.Fatal("SignedSession was lost after LoadExtensionsFromDir (extRegistry clobbered)")
	}

	// 4. The pending verification URL must be producible (no error JSON).
	res := GetPendingVerificationUrl(`{"extension_id":"qobuz-web"}`)
	if strings.Contains(res, `"error"`) {
		t.Fatalf("GetPendingVerificationUrl returned error: %s", res)
	}
	if !strings.Contains(res, `"auth_url"`) {
		t.Fatalf("GetPendingVerificationUrl unexpected shape: %s", res)
	}
}

// TestLoadDirExtensionsIntoSkipsExisting verifies the loader never replaces a
// sandbox that already exists (embedded copy has signed-session config).
func TestLoadDirExtensionsIntoSkipsExisting(t *testing.T) {
	staleDir := t.TempDir()
	extSub := filepath.Join(staleDir, "deezer")
	os.MkdirAll(extSub, 0755)
	os.WriteFile(filepath.Join(extSub, "manifest.json"), []byte(`{"name":"deezer"}`), 0644)
	os.WriteFile(filepath.Join(extSub, "index.js"), []byte(`function searchTracks(q,l){return[];}`), 0644)

	extRegistry = nil
	extSettings = nil
	InitGlobalState()

	if sb := signedSessionSandbox("deezer"); sb == nil || sb.SignedSession == nil {
		t.Fatal("deezer SignedSession missing after InitGlobalState")
	}
	_ = LoadExtensionsFromDir(`{"dir_path":"` + strings.ReplaceAll(staleDir, `\`, `\\`) + `"}`)
	if sb := signedSessionSandbox("deezer"); sb == nil || sb.SignedSession == nil {
		t.Fatal("deezer SignedSession lost after LoadExtensionsFromDir with stale dir")
	}
}
