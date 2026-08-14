package extensions

import (
	"os"
	"path/filepath"
	"testing"
)

// writeDirExtension creates a minimal extDir/<id>/index.js + manifest.json.
func writeDirExtension(t *testing.T, root, id string, withSignedSession bool) {
	t.Helper()
	dir := filepath.Join(root, id)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	js := `function searchTracks(q, limit) { return []; }
function getHomeFeed() { return { success: false, sections: [] }; }`
	if err := os.WriteFile(filepath.Join(dir, "index.js"), []byte(js), 0644); err != nil {
		t.Fatal(err)
	}
	var manifest string
	if withSignedSession {
		manifest = `{
  "name": "` + id + `",
  "signedSession": {
    "namespace": "test-ns",
    "baseUrl": "https://api.example.com/v2",
    "appVersion": "` + id + `@1.0.0",
    "callbackUrl": "spotiflac://session-grant"
  }
}`
	} else {
		manifest = `{"name": "` + id + `"}`
	}
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(manifest), 0644); err != nil {
		t.Fatal(err)
	}
}

func TestLoadDirExtensionsIntoConnectsSignedSession(t *testing.T) {
	root, _ := os.MkdirTemp("", "loaddir-*")
	defer os.RemoveAll(root)

	writeDirExtension(t, root, "qobuz-web", true)
	writeDirExtension(t, root, "plain-ext", false)

	reg, err := NewRegistry(root)
	if err != nil {
		t.Fatal(err)
	}

	loaded := LoadDirExtensionsInto(reg, root, root)
	if loaded != 2 {
		t.Fatalf("expected 2 loaded extensions, got %d", loaded)
	}

	// qobuz-web must have SignedSession + Session attached.
	sb := reg.Runtime().Sandbox("qobuz-web")
	if sb == nil {
		t.Fatal("qobuz-web sandbox not found")
	}
	if sb.SignedSession == nil {
		t.Error("qobuz-web SignedSession not attached from manifest")
	}
	if sb.Session == nil {
		t.Error("qobuz-web Session state not created")
	}

	// plain-ext must NOT have a signed session.
	plain := reg.Runtime().Sandbox("plain-ext")
	if plain == nil {
		t.Fatal("plain-ext sandbox not found")
	}
	if plain.SignedSession != nil {
		t.Error("plain-ext should not have SignedSession")
	}
}

func TestLoadDirExtensionsIntoSkipsNonDirs(t *testing.T) {
	root, _ := os.MkdirTemp("", "loaddir-skip-*")
	defer os.RemoveAll(root)

	// A stray .js file at the root should be ignored by the subdir loader.
	if err := os.WriteFile(filepath.Join(root, "stray.js"), []byte("var x=1;"), 0644); err != nil {
		t.Fatal(err)
	}
	writeDirExtension(t, root, "amazon", true)

	reg, err := NewRegistry(root)
	if err != nil {
		t.Fatal(err)
	}
	loaded := LoadDirExtensionsInto(reg, root, root)
	if loaded != 1 {
		t.Fatalf("expected 1 loaded extension, got %d", loaded)
	}
	if reg.Runtime().Sandbox("stray") != nil {
		t.Error("stray.js should not create a sandbox")
	}
}

func TestLoadDirExtensionsIntoKeepsExistingSandbox(t *testing.T) {
	root, _ := os.MkdirTemp("", "loaddir-keep-*")
	defer os.RemoveAll(root)

	// Pre-load qobuz-web with SignedSession (like InitGlobalState does).
	writeDirExtension(t, root, "qobuz-web", true)
	reg, err := NewRegistry(root)
	if err != nil {
		t.Fatal(err)
	}
	cfg := DefaultConfig()
	if _, err := reg.Runtime().RunJS(`function searchTracks(q,l){return[];}`, "qobuz-web", "qobuz-web", cfg, root); err != nil {
		t.Fatal(err)
	}
	if sb := reg.Runtime().Sandbox("qobuz-web"); sb != nil {
		sb.SignedSession = &SignedSessionConfig{Namespace: "embedded", BaseURL: "https://embedded"}
		sb.Session = &SignedSessionState{}
	}

	// Loading from dir must NOT replace the pre-loaded sandbox.
	loaded := LoadDirExtensionsInto(reg, root, root)
	if loaded != 0 {
		t.Fatalf("expected 0 loaded (already present), got %d", loaded)
	}
	sb := reg.Runtime().Sandbox("qobuz-web")
	if sb == nil || sb.SignedSession == nil {
		t.Fatal("existing sandbox must be preserved")
	}
	if sb.SignedSession.Namespace != "embedded" {
		t.Errorf("existing SignedSession was replaced: got %q", sb.SignedSession.Namespace)
	}
}
