package drm

import (
	"crypto/cipher"
	"crypto/md5"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"golang.org/x/crypto/blowfish"
)

// Deezer scheme constants (mirrors go_backend/internal/bundled_extensions/
// deezer/index.js + extensions/crypto_decrypt.go).
const (
	deezerBlowfishSecret = "g4el58wc0zvf9na1"
	deezerBlowfishIVHex  = "0001020304050607"
	deezerChunkSize      = 2048
	deezerEncryptEvery   = 3 // chunk indices 0, 3, 6, ... are encrypted
)

// deezerKeyHex replicates generateBlowfishKeyHex from the extension:
// key[i] = md5hexASCII[i] ^ md5hexASCII[i+16] ^ secretASCII[i]  (i in 0..15)
func deezerKeyHex(trackID string) string {
	sum := md5.Sum([]byte(trackID))
	md5hex := hex.EncodeToString(sum[:]) // 32 chars
	out := make([]byte, 16)
	for i := 0; i < 16; i++ {
		out[i] = md5hex[i] ^ md5hex[i+16] ^ deezerBlowfishSecret[i]
	}
	return hex.EncodeToString(out)
}

func deezerIV() []byte {
	iv, _ := hex.DecodeString(deezerBlowfishIVHex)
	return iv
}

// encryptBlock applies Blowfish-CBC to one full 2048-byte block (the inverse
// of what the decoder must do; zarz serves only blocks with index%3==0
// encrypted, always with the same fixed IV).
func encryptBlock(keyHex string, block []byte) []byte {
	key, _ := hex.DecodeString(keyHex)
	c, err := blowfish.NewCipher(key)
	if err != nil {
		panic(err)
	}
	enc := make([]byte, len(block))
	cipher.NewCBCEncrypter(c, deezerIV()).CryptBlocks(enc, block)
	return enc
}

// zarzEncrypt encrypts [clear] the way zarz serves a Deezer FLAC: full
// 2048-byte blocks with index%3==0 are Blowfish-CBC encrypted; partial tail
// and other blocks pass through untouched. Sizes are preserved 1:1.
func zarzEncrypt(keyHex string, clear []byte) []byte {
	enc := make([]byte, len(clear))
	copy(enc, clear)
	for i := 0; i+deezerChunkSize <= len(clear); i += deezerChunkSize {
		ci := i / deezerChunkSize
		if ci%deezerEncryptEvery == 0 {
			blk := encryptBlock(keyHex, clear[i:i+deezerChunkSize])
			copy(enc[i:], blk)
		}
	}
	return enc
}

// sample is one golden fixture: the encrypted bytes (as served by the
// provider), the key, and the expected plaintext.
type sample struct {
	TrackID     string `json:"trackId"`
	KeyHex      string `json:"keyHex"`
	ClearB64    string `json:"clearB64"`
	EncryptedB64 string `json:"encryptedB64"`
}

type fixtureFile struct {
	Version    int      `json:"version"`
	ChunkSize  int      `json:"chunkSize"`
	EncryptEvery int    `json:"encryptEvery"`
	IVHex      string   `json:"ivHex"`
	GeneratedBy string  `json:"generatedBy"`
	Samples    []sample `json:"samples"`
}

func fixturePath() string {
	return filepath.Join("testdata", "deezer_blowfish_vectors.json")
}

// deterministicPayload builds repeatable pseudo-random bytes (not a real FLAC;
// these are crypto vectors, codec structure is irrelevant here).
func deterministicPayload(seed byte, n int) []byte {
	out := make([]byte, n)
	for i := range out {
		out[i] = byte((int(seed)*31 + i*7 + i>>3) & 0xff)
	}
	return out
}

// TestGenerateDeezerFixtures writes the golden fixture JSON. Gated because it
// is only needed when regenerating after an algorithm change. The plaintext is
// deterministic, so the committed fixture is reproducible byte-for-byte.
func TestGenerateDeezerFixtures(t *testing.T) {
	if os.Getenv("BITLY_FIXTURE_GEN") == "" {
		t.Skip("set BITLY_FIXTURE_GEN=1 to regenerate deezer fixture vectors")
	}
	ids := []string{"3733293352", "3135556"}
	samples := make([]sample, 0, 2)
	payloads := [][]byte{
		deterministicPayload(0x5a, deezerChunkSize*4),               // 4 blocks: encrypt 0 and 3
		deterministicPayload(0x7c, deezerChunkSize*3+137),           // 3 blocks + partial tail
	}
	for i, id := range ids {
		key := deezerKeyHex(id)
		clear := payloads[i]
		enc := zarzEncrypt(key, clear)
		samples = append(samples, sample{
			TrackID:      id,
			KeyHex:       key,
			ClearB64:     base64.StdEncoding.EncodeToString(clear),
			EncryptedB64: base64.StdEncoding.EncodeToString(enc),
		})
	}
	f := fixtureFile{
		Version:      1,
		ChunkSize:    deezerChunkSize,
		EncryptEvery: deezerEncryptEvery,
		IVHex:        deezerBlowfishIVHex,
		GeneratedBy:  "internal/drm fixture_test.go (zarz Deezer Blowfish rule; keys cross-checked against the extension's generateBlowfishKeyHex)",
		Samples:      samples,
	}
	data, err := json.MarshalIndent(f, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(fixturePath(), data, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Logf("wrote %s (%d bytes)", fixturePath(), len(data))
}

// TestDeezerFixtureConsistency re-encrypts the stored plaintexts with the
// stored keys and asserts the result matches the stored encrypted bytes. This
// guards the fixture file against accidental edits and confirms the vector
// remains a valid pair for the range-decryptor tests in Fase 1.
func TestDeezerFixtureConsistency(t *testing.T) {
	data, err := os.ReadFile(fixturePath())
	if err != nil {
		t.Fatal(err)
	}
	var f fixtureFile
	if err := json.Unmarshal(data, &f); err != nil {
		t.Fatal(err)
	}
	if f.Version != 1 || f.ChunkSize != deezerChunkSize || f.EncryptEvery != deezerEncryptEvery {
		t.Fatalf("unexpected fixture metadata: %+v", f)
	}
	for _, s := range f.Samples {
		clear, err1 := base64.StdEncoding.DecodeString(s.ClearB64)
		enc, err2 := base64.StdEncoding.DecodeString(s.EncryptedB64)
		if err1 != nil || err2 != nil {
			t.Fatalf("decode %s: %v %v", s.TrackID, err1, err2)
		}
		if len(clear) != len(enc) {
			t.Fatalf("length mismatch for %s", s.TrackID)
		}
		if got := deezerKeyHex(s.TrackID); got != s.KeyHex {
			t.Fatalf("key derivation mismatch for %s: got %s want %s", s.TrackID, got, s.KeyHex)
		}
		if subtle.ConstantTimeCompare(zarzEncrypt(s.KeyHex, clear), enc) != 1 {
			t.Fatalf("encrypted vector does not match for %s", s.TrackID)
		}
	}
}

// TestDeezerKnownKeyVectors pins the extension's generateBlowfishKeyHex output
// for a few ids (computed with node + the extension's own algorithm) so any
// future Go implementation of the key derivation is verified against the JS.
func TestDeezerKnownKeyVectors(t *testing.T) {
	want := map[string]string{
		"3733293352": "35346369606c73666e707c61386a3535",
		"3135556":    "6c6c666b39662c37652575603c643439",
		"1234567890": "3b6e376b623172616075773a696c6a31",
		"1088926":    "38303662366a2b31622e70393b3f6160",
	}
	for id, w := range want {
		if got := deezerKeyHex(id); got != w {
			t.Errorf("key(%q)=%s want %s", id, got, w)
		}
	}
}
