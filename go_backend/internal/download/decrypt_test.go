package download

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsPlainAudioFile(t *testing.T) {
	dir := t.TempDir()
	write := func(name string, b []byte) string {
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, b, 0o644); err != nil {
			t.Fatal(err)
		}
		return p
	}

	cases := []struct {
		name string
		path string
		want bool
	}{
		{"flac magic", write("a.flac", []byte("fLaC\x00\x00\x00\x22")), true},
		{"id3 magic", write("a.mp3", []byte("ID3\x04\x00\x00\x00")), true},
		{"ogg magic", write("a.ogg", []byte("OggS\x00\x02")), true},
		{"riff magic", write("a.wav", []byte("RIFF\x24\x00\x00\x00")), true},
		{"mp4 ftyp is NOT plain", write("a.mp4", []byte("\x00\x00\x00\x18ftypmp42")), false},
		{"empty file", write("empty", nil), false},
		{"missing file", filepath.Join(dir, "nope.flac"), false},
	}
	for _, c := range cases {
		if got := isPlainAudioFile(c.path); got != c.want {
			t.Errorf("%s: isPlainAudioFile(%q) = %v, want %v", c.name, c.path, got, c.want)
		}
	}
}

func TestDecryptionKeyCandidates(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		wantHas []string
	}{
		{
			name:    "base64 16-byte key decodes to plain hex",
			in:      "AAAAAAAAAAAAAAAAAAAAAA==", // 16 zero bytes, 24 base64 chars
			wantHas: []string{"00000000000000000000000000000000"},
		},
		{
			name:    "plain 32-hex stays unprefixed",
			in:      "00112233445566778899aabbccddeeff",
			wantHas: []string{"00112233445566778899aabbccddeeff"},
		},
		{
			name:    "0x prefix stripped",
			in:      "0x00112233445566778899aabbccddeeff",
			wantHas: []string{"00112233445566778899aabbccddeeff"},
		},
		{
			name:    "uppercase hex normalized",
			in:      "00112233445566778899AABBCCDDEEFF",
			wantHas: []string{"00112233445566778899aabbccddeeff"},
		},
	}
	for _, c := range cases {
		got := decryptionKeyCandidates(c.in)
		for _, want := range c.wantHas {
			found := false
			for _, g := range got {
				if g == want {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("%s: missing candidate %q in %v", c.name, want, got)
			}
		}
	}

	// Keys of any other length must never be emitted: ffmpeg's mov demuxer
	// rejects anything that isn't exactly 16 bytes ("Invalid decryption key
	// len") and 0x-prefixed values ("Error setting option").
	for _, bad := range []string{
		"0xd5ad5be36f5ae1be5fe3c75bf367f8d39f356b4d796fceb9", // 24-byte hex w/ prefix
		"d5ad5be36f5ae1be5fe3c75bf367f8d39f356b4d796fceb9",   // 24-byte hex
		"abc123",    // too short
		"not-a-key", // not hex at all
	} {
		if got := decryptionKeyCandidates(bad); len(got) != 0 {
			t.Errorf("%q: expected no candidates, got %v", bad, got)
		}
	}
}
