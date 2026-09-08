package drm

import (
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"os"
	"testing"
)

func TestGenerateDeezerFixtures(t *testing.T) {
	if os.Getenv("BITLY_FIXTURE_GEN") == "" {
		t.Skip("set BITLY_FIXTURE_GEN=1 to regenerate deezer fixture vectors")
	}
	ids := []string{"3733293352", "3135556"}
	samples := make([]sample, 0, 2)
	payloads := [][]byte{
		deterministicPayload(0x5a, deezerChunkSize*4),     // 4 blocks: encrypt 0 and 3
		deterministicPayload(0x7c, deezerChunkSize*3+137), // 3 blocks + partial tail
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
