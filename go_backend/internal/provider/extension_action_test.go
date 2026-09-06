package provider

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// actionExtProvider builds an ExtensionProvider backed by a tiny JS extension
// that exports clearCachedTokens() and a few dummy search/download functions.
func actionExtProvider(t *testing.T) *ExtensionProvider {
	t.Helper()
	dir, _ := os.MkdirTemp("", "act-*")
	t.Cleanup(func() { os.RemoveAll(dir) })
	extDir := filepath.Join(dir, "act-ext")
	if err := os.MkdirAll(extDir, 0755); err != nil {
		t.Fatal(err)
	}
	js := `function clearCachedTokens() {
  return { ok: true, cleared: { poTokens: 3, generic: 12 } };
}
function searchTracks(q, limit) { return []; }
function searchAlbums(q, limit) { return []; }
function searchArtists(q, limit) { return []; }
function searchPlaylists(q, limit) { return []; }
function getTrack(id) { return null; }
function getTrackByISRC(i) { return null; }
function getAlbum(id) { return null; }
function getArtist(id) { return null; }
function getStreamURL(id, q) { return ""; }`
	if err := os.WriteFile(filepath.Join(extDir, "index.js"), []byte(js), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(extDir, "manifest.json"), []byte(`{"name":"act-ext"}`), 0644); err != nil {
		t.Fatal(err)
	}
	reg, err := extensions.NewRegistry(dir)
	if err != nil {
		t.Fatal(err)
	}
	extensions.LoadDirExtensionsInto(reg, dir, dir)
	return NewExtensionProvider("act-ext", "act-ext", reg.Runtime())
}

func TestHasAction(t *testing.T) {
	ep := actionExtProvider(t)
	if !ep.HasAction("clearCachedTokens") {
		t.Error("expected clearCachedTokens to be exported")
	}
	if ep.HasAction("nonexistentAction") {
		t.Error("nonexistentAction should not be exported")
	}
}

func TestInvokeAction(t *testing.T) {
	ep := actionExtProvider(t)
	res, err := ep.InvokeAction("clearCachedTokens")
	if err != nil {
		t.Fatalf("InvokeAction: %v", err)
	}
	m, ok := res.(map[string]interface{})
	if !ok {
		t.Fatalf("expected map result, got %T", res)
	}
	if m["ok"] != true {
		t.Errorf("result ok = %v", m["ok"])
	}
}

func TestInvokeAction_MissingMethod(t *testing.T) {
	ep := actionExtProvider(t)
	if _, err := ep.InvokeAction("doesNotExist"); err == nil {
		t.Fatal("expected error for missing action")
	}
}
