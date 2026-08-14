package download

import (
	"os"
	"path/filepath"
	"testing"
)

func writeBytes(t *testing.T, dir, name string, data []byte) string {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.WriteFile(p, data, 0o644); err != nil {
		t.Fatalf("write %s: %v", name, err)
	}
	return p
}

func TestIsPlayableCachedFile(t *testing.T) {
	dir := t.TempDir()

	// A real FLAC named .flac is playable.
	flac := writeBytes(t, dir, "a.flac", append([]byte("fLaC\x00\x00\x00\x22"), make([]byte, 100)...))
	if !isPlayableCachedFile(flac) {
		t.Error("FLAC content with .flac name should be playable")
	}

	// A container mislabeled .flac must be rejected (this is the exact stale
	// cache case: providers wrote mp4 files with .flac names that never play).
	mp4AsFlac := writeBytes(t, dir, "b.flac", append([]byte("\x00\x00\x00\x18ftypM4A \x00\x00\x00\x00"), make([]byte, 4096)...))
	if isPlayableCachedFile(mp4AsFlac) {
		t.Error("mp4 content named .flac must be rejected")
	}

	// MP3 with ID3 tag named .mp3 is playable.
	mp3 := writeBytes(t, dir, "a.mp3", append([]byte("ID3\x04\x00\x00\x00\x00\x00\x00"), make([]byte, 100)...))
	if !isPlayableCachedFile(mp3) {
		t.Error("ID3 mp3 should be playable")
	}

	// Ogg/Opus named .ogg is playable.
	ogg := writeBytes(t, dir, "a.ogg", append([]byte("OggS\x00\x02"), make([]byte, 100)...))
	if !isPlayableCachedFile(ogg) {
		t.Error("OggS content should be playable")
	}

	// Plain mp4/m4a (no protection) named .m4a is playable.
	plainMP4 := writeBytes(t, dir, "a.m4a", append([]byte("\x00\x00\x00\x18ftypM4A \x00\x00\x00\x00"), make([]byte, 4096)...))
	if !isPlayableCachedFile(plainMP4) {
		t.Error("plain mp4/m4a should be playable")
	}

	// Encrypted mp4 (sinf protection scheme) named .m4a must be rejected.
	encryptedMP4 := append([]byte("\x00\x00\x00\x24ftypmp41\x00\x00\x00\x00"), make([]byte, 512)...)
	encryptedMP4 = append(encryptedMP4, []byte("\x00\x00\x00\x20moov\x00\x00\x00\x00\x00\x00\x00\x00sinf\x00\x00\x00\x00")...)
	encryptedMP4 = append(encryptedMP4, make([]byte, 4096)...)
	enc := writeBytes(t, dir, "track.m4a", encryptedMP4)
	if isPlayableCachedFile(enc) {
		t.Error("encrypted mp4 (sinf) must NOT be served from cache")
	}

	// Random/unknown content and unknown extensions are rejected.
	junk := writeBytes(t, dir, "junk.flac", []byte("<html><body>error</body></html>"))
	if isPlayableCachedFile(junk) {
		t.Error("non-audio content must be rejected")
	}
	unknownExt := writeBytes(t, dir, "track.bin", append([]byte("fLaC"), make([]byte, 100)...))
	if isPlayableCachedFile(unknownExt) {
		t.Error("unknown extension must be rejected")
	}
}

func TestStreamCacheFileSkipsInvalid(t *testing.T) {
	dir := t.TempDir()

	// A stale mp4 mislabeled as .flac must not be returned and is deleted so
	// the next tap re-downloads.
	bad := append([]byte("\x00\x00\x00\x24ftypmp41"), make([]byte, 1024)...)
	bad = append(bad, []byte("sinf")...)
	writeBytes(t, dir, "track_1.flac", bad)

	// A valid audio file for the same item wins when present.
	writeBytes(t, dir, "track_1.mp3", append([]byte("ID3\x04\x00\x00\x00\x00\x00\x00"), make([]byte, 100)...))

	if got := StreamCacheFile(dir, "track_1"); got == "" {
		t.Error("expected a valid cached file for track_1")
	}
	if _, err := os.Stat(filepath.Join(dir, "track_1.flac")); !os.IsNotExist(err) {
		t.Error("invalid cached file should have been deleted")
	}

	// Only invalid files exist -> no cache hit.
	writeBytes(t, dir, "track_2.flac", []byte("garbage"))
	if got := StreamCacheFile(dir, "track_2"); got != "" {
		t.Errorf("expected no cache hit for track_2, got %s", got)
	}
	if _, err := os.Stat(filepath.Join(dir, "track_2.flac")); !os.IsNotExist(err) {
		t.Error("invalid cached file should have been deleted")
	}
}
