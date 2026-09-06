package gobackend

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// TestCaptureDRMFixture downloads ONE real encrypted track through the actual
// download pipeline (extension + orchestrator) and saves the golden pair:
//
//	<provider>.<trackId>.encrypted   — raw bytes as served (encrypted/DRM)
//	<provider>.<trackId>.key.json    — {keyHex, outputExtension, inputFormat}
//	<provider>.<trackId>.clear       — reference clear file (when the host can
//	                                   decrypt it: desktop ffmpeg CLI, or the
//	                                   extension's own JS decrypt for deezer)
//
// Env (all required except where noted):
//
//	BITLY_FIXTURE_PROVIDER  amazon | deezer
//	BITLY_FIXTURE_QUERY     search query used to pick the first track
//	BITLY_FIXTURE_OUT       output dir (default: os.TempDir()/drm-fixtures)
//
// A verified signed session for the provider is required (the Cloudflare/
// signed-session flow the app uses); without it the download fails with
// VERIFY_REQUIRED and the harness logs that instead of a fixture.
func TestCaptureDRMFixture(t *testing.T) {
	provider := os.Getenv("BITLY_FIXTURE_PROVIDER")
	query := os.Getenv("BITLY_FIXTURE_QUERY")
	if provider == "" || query == "" {
		t.Skip("set BITLY_FIXTURE_PROVIDER + BITLY_FIXTURE_QUERY to run the real capture")
	}
	outDir := os.Getenv("BITLY_FIXTURE_OUT")
	if outDir == "" {
		outDir = filepath.Join(os.TempDir(), "drm-fixtures")
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		t.Fatal(err)
	}

	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	// Pick the first track-ish search result from the provider (type labels
	// differ per extension: "track"/"song").
	payload := fmt.Sprintf(`{"query":%q,"limit":8,"source":%q,"type":"all"}`, query, provider)
	var items []FeedItemGo
	if err := json.Unmarshal([]byte(Search(payload)), &items); err != nil {
		t.Fatalf("search unmarshal: %v", err)
	}
	var track *FeedItemGo
	for i := range items {
		if (items[i].Type == "track" || items[i].Type == "song") && items[i].ID != "" {
			track = &items[i]
			break
		}
	}
	if track == nil {
		t.Fatalf("no track found for %q on %s", query, provider)
	}
	t.Logf("capturing: %s - %s (id=%s src=%s isrc=%s)", track.Artists, track.Name, track.ID, track.Source, track.ISRC)

	req := download.Request{
		ItemID:    track.ID,
		Title:     track.Name,
		Artist:    track.Artists,
		Album:     track.AlbumName,
		ISRC:      track.ISRC,
		Provider:  provider,
		TrackID:   track.ID,
		Quality:   "FLAC",
		OutputDir: outDir,
	}
	start := time.Now()
	res := downloadOrch.Download(req)
	elapsed := time.Since(start).Round(time.Second)
	t.Logf("download (%s): success=%v provider=%s encrypted=%v clientDecrypt=%v path=%q keySet=%v error=%q (%s)",
		elapsed, res.Success, res.Provider, res.Encrypted, res.ClientDecrypt, res.FilePath,
		res.DecryptionKey != "", res.Error, res.ErrorType)

	if res == nil || res.FilePath == "" {
		t.Fatalf("no file produced: %+v", res)
	}
	if !res.Encrypted && res.DecryptionKey == "" {
		t.Logf("result is CLEAR audio (no DRM) — not a DRM fixture; file kept at %s", res.FilePath)
		return
	}

	base := filepath.Join(outDir, provider+"."+safeFixtureName(track.ID))
	// Keep the raw encrypted bytes (when orchestrator kept them) as the
	// "encrypted" side of the pair.
	if res.Encrypted {
		src := res.FilePath
		enc := base + ".encrypted"
		if err := copyFixtureFile(src, enc); err != nil {
			t.Fatalf("copy encrypted: %v", err)
		}
		t.Logf("encrypted fixture: %s", enc)
	}
	meta := map[string]string{
		"provider":        provider,
		"trackId":         track.ID,
		"title":           track.Name,
		"artist":          track.Artists,
		"keyHex":          res.DecryptionKey,
		"outputExtension": res.OutputExtension,
		"inputFormat":     res.InputFormat,
		"clearPath":       res.FilePath,
		"clearB64Prefix":  clearPrefix(res.FilePath),
	}
	metaPath := base + ".key.json"
	data, _ := json.MarshalIndent(meta, "", "  ")
	if err := os.WriteFile(metaPath, data, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Logf("metadata fixture: %s", metaPath)
	t.Logf("NOTE: validate <clear> == ffmpeg -decryption_key <key> <encrypted> (mov) or the zarz block rule (deezer) before adding to internal/drm/testdata")
}

func safeFixtureName(id string) string {
	out := make([]byte, 0, len(id))
	for _, c := range id {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '_', c == '-':
			out = append(out, byte(c))
		default:
			out = append(out, '_')
		}
	}
	return string(out)
}

func copyFixtureFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o644)
}

func clearPrefix(path string) string {
	data, err := os.ReadFile(path)
	if err != nil || len(data) == 0 {
		return ""
	}
	n := len(data)
	if n > 512 {
		n = 512
	}
	return base64.StdEncoding.EncodeToString(data[:n])
}
