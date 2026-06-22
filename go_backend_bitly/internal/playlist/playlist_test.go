package playlist

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGenerateM3U_Success(t *testing.T) {
	dir := t.TempDir()
	path, err := GenerateM3U(Config{
		Name: "MyPlaylist", Artist: "Artist", Year: "2024",
		Genre: "Rock", OutputDir: dir,
		Tracks: []Track{
			{Title: "Song", Artist: "A", Duration: 200000, FilePath: "test.flac"},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	content := string(data)
	if !strings.Contains(content, "#EXTM3U") {
		t.Error("missing #EXTM3U header")
	}
	if !strings.Contains(content, "Song") {
		t.Error("missing track title")
	}
	if filepath.Ext(path) != ".m3u" {
		t.Error("expected .m3u extension")
	}
}

func TestGenerateM3U8_Success(t *testing.T) {
	dir := t.TempDir()
	path, err := GenerateM3U8(Config{
		Name: "MyList", OutputDir: dir,
		Tracks: []Track{{Title: "T1", Artist: "A", Duration: 180000, FilePath: "t.flac"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasSuffix(path, ".m3u8") {
		t.Error("expected .m3u8 extension")
	}
}

func TestGenerateCUE_Success(t *testing.T) {
	dir := t.TempDir()
	path, err := GenerateCUE(Config{
		Name: "Album", Artist: "Artist", OutputDir: dir,
		Tracks: []Track{
			{Title: "S1", Artist: "A", TrackNum: 1, ISRC: "US123", Duration: 200000},
			{Title: "S2", Artist: "A", TrackNum: 2, DiscNum: 1},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if !strings.Contains(string(data), "PERFORMER") {
		t.Error("missing PERFORMER")
	}
	if !strings.Contains(string(data), "ISRC US123") {
		t.Error("missing ISRC")
	}
}
