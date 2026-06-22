package playlist

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGenerateNFO_Success(t *testing.T) {
	dir := t.TempDir()
	path, err := GenerateNFO(Config{
		Name: "Album", Artist: "Artist", Genre: "Jazz", Year: "2024",
		OutputDir: dir,
		Tracks:    []Track{{Title: "T1", Artist: "A", Duration: 200000}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasSuffix(path, ".nfo") {
		t.Error("expected .nfo extension")
	}
}

func TestGenerateCUE_EmptyName(t *testing.T) {
	dir := t.TempDir()
	path, err := GenerateCUE(Config{OutputDir: dir,
		Tracks: []Track{{Title: "S1", Artist: "A"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if !strings.Contains(string(data), "Unknown Album") {
		t.Error("expected fallback title")
	}
}

func TestGenerateBulkPlaylistFiles(t *testing.T) {
	dir := t.TempDir()
	results := GenerateBulkPlaylistFiles(Config{
		Name: "Bulk", Artist: "X", OutputDir: dir,
		Tracks: []Track{
			{Title: "T1", Artist: "A", Duration: 100000, FilePath: "x.flac"},
		},
	})
	if len(results) != 4 {
		t.Errorf("expected 4 files, got %d", len(results))
	}
}

func TestGenerateBulkPlaylistFiles_NoTracks(t *testing.T) {
	results := GenerateBulkPlaylistFiles(Config{Name: "Empty"})
	if len(results) != 1 {
		t.Errorf("expected 1 file (NFO), got %d", len(results))
	}
}

func TestAbsolutePathResolution(t *testing.T) {
	dir := t.TempDir()
	out, err := GenerateM3U(Config{
		Name: "AbsPath", OutputDir: dir,
		Tracks: []Track{
			{Title: "T", Artist: "A", FilePath: filepath.Join(dir, "song.flac"), Duration: 100000},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(out)
	if !strings.Contains(string(data), dir) {
		t.Error("expected absolute path")
	}
}
