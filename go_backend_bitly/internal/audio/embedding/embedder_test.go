package embedding

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNewEmbedder(t *testing.T) {
	e := NewEmbedder("/tmp/covers")
	if e == nil {
		t.Fatal("expected non-nil Embedder")
	}
}

func TestNewEmbedder_EmptyCoverDir(t *testing.T) {
	e := NewEmbedder("")
	if e == nil {
		t.Fatal("expected non-nil Embedder")
	}
}

func TestEmbed_NoAudioPath(t *testing.T) {
	e := NewEmbedder("")
	err := e.Embed(context.Background(), EmbedRequest{})
	if err == nil {
		t.Fatal("expected error for empty audio path")
	}
	if !strings.Contains(err.Error(), "no audio file specified") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestEmbed_FileNotFound(t *testing.T) {
	e := NewEmbedder("")
	err := e.Embed(context.Background(), EmbedRequest{
		AudioPath: "/nonexistent/file.flac",
	})
	if err == nil {
		t.Fatal("expected error for nonexistent file")
	}
	if !strings.Contains(err.Error(), "file not found") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestEmbedLyrics_NoAudioPath(t *testing.T) {
	e := NewEmbedder("")
	err := e.EmbedLyrics(context.Background(), "", "some lyrics")
	if err == nil {
		t.Fatal("expected error for empty audio path")
	}
}

func TestEmbedLyrics_EmptyLyrics(t *testing.T) {
	e := NewEmbedder("")
	err := e.EmbedLyrics(context.Background(), "/some/file.flac", "")
	if err != nil {
		t.Fatalf("expected nil for empty lyrics: %v", err)
	}
}

func TestEmbedLyrics_FileNotFound(t *testing.T) {
	e := NewEmbedder("")
	err := e.EmbedLyrics(context.Background(), "/nonexistent/file.flac", "lyrics")
	if err == nil {
		t.Fatal("expected error for nonexistent file")
	}
}

func TestEmbedCover_NoPaths(t *testing.T) {
	e := NewEmbedder("")
	err := e.EmbedCover(context.Background(), "", "")
	if err == nil {
		t.Fatal("expected error for empty paths")
	}
}

func TestEmbedCover_MissingAudio(t *testing.T) {
	e := NewEmbedder("")
	err := e.EmbedCover(context.Background(), "/no/audio.flac", "/no/cover.jpg")
	if err == nil {
		t.Fatal("expected error for nonexistent audio")
	}
}

func TestEmbedCover_MissingCover(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "test.flac")
	os.WriteFile(audioPath, []byte("fake flac"), 0644)

	e := NewEmbedder("")
	err := e.EmbedCover(context.Background(), audioPath, "/nonexistent/cover.jpg")
	if err == nil {
		t.Fatal("expected error for nonexistent cover")
	}
}

func TestEmbedRequest_Fields(t *testing.T) {
	req := EmbedRequest{
		AudioPath:   "/music/song.flac",
		Title:       "Test Song",
		Artist:      "Test Artist",
		Album:       "Test Album",
		AlbumArtist: "Test AA",
		Genre:       "Rock",
		Date:        "2024",
		ISRC:        "USABC1234567",
		TrackNum:    1,
		TotalTracks: 12,
		DiscNum:     1,
		TotalDiscs:  2,
		Label:       "Test Label",
		Copyright:   "2024 Test",
		Composer:    "Test Composer",
		Lyrics:      "Test lyrics",
		CoverPath:   "/covers/test.jpg",
	}

	if req.AudioPath != "/music/song.flac" {
		t.Errorf("AudioPath = %q", req.AudioPath)
	}
	if req.TrackNum != 1 {
		t.Errorf("TrackNum = %d", req.TrackNum)
	}
	if req.TotalTracks != 12 {
		t.Errorf("TotalTracks = %d", req.TotalTracks)
	}
}

func TestResolveCoverPath_EmptyDir(t *testing.T) {
	e := NewEmbedder("")
	path := e.resolveCoverPath("/music/song.flac")
	if path != "" {
		t.Errorf("expected empty path, got %q", path)
	}
}

func TestWriteSidecar(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "song.mp3")
	os.WriteFile(audioPath, []byte("fake audio"), 0644)

	content := "sidecar content"
	err := writeSidecar(audioPath, ".lrc", content)
	if err != nil {
		t.Fatalf("writeSidecar failed: %v", err)
	}

	sidecarPath := filepath.Join(dir, "song.lrc")
	data, err := os.ReadFile(sidecarPath)
	if err != nil {
		t.Fatalf("failed to read sidecar: %v", err)
	}
	if string(data) != content {
		t.Errorf("sidecar content = %q, want %q", string(data), content)
	}
}

func TestWriteSidecarBytes(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "song.flac")
	os.WriteFile(audioPath, []byte("fake audio"), 0644)

	data := []byte("binary cover data")
	err := writeSidecarBytes(audioPath, ".jpg", data)
	if err != nil {
		t.Fatalf("writeSidecarBytes failed: %v", err)
	}

	sidecarPath := filepath.Join(dir, "song.jpg")
	readData, err := os.ReadFile(sidecarPath)
	if err != nil {
		t.Fatalf("failed to read sidecar: %v", err)
	}
	if string(readData) != string(data) {
		t.Errorf("sidecar content mismatch")
	}
}

func TestEmbedSidecar(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "song.mp3")
	os.WriteFile(audioPath, []byte("fake audio"), 0644)
	coverPath := filepath.Join(dir, "cover.jpg")
	os.WriteFile(coverPath, []byte("fake cover"), 0644)

	e := NewEmbedder("")
	err := e.embedSidecar(EmbedRequest{
		AudioPath: audioPath,
		CoverPath: coverPath,
		Lyrics:    "test lyrics",
	})
	if err != nil {
		t.Fatalf("embedSidecar failed: %v", err)
	}

	// Check cover sidecar
	if _, err := os.Stat(filepath.Join(dir, "song.jpg")); os.IsNotExist(err) {
		t.Error("expected cover sidecar file")
	}
	// Check lyrics sidecar
	if _, err := os.Stat(filepath.Join(dir, "song.lrc")); os.IsNotExist(err) {
		t.Error("expected lyrics sidecar file")
	}
}
