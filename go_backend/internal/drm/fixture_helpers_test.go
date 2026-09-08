package drm

import (
	"crypto/cipher"
	"crypto/md5"
	"encoding/hex"
	"path/filepath"

	//lint:ignore SA1019 Deezer Blowfish DRM: el algoritmo lo exige el cifrado de Deezer (no reemplazable por AES).
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
	TrackID      string `json:"trackId"`
	KeyHex       string `json:"keyHex"`
	ClearB64     string `json:"clearB64"`
	EncryptedB64 string `json:"encryptedB64"`
}

type fixtureFile struct {
	Version      int      `json:"version"`
	ChunkSize    int      `json:"chunkSize"`
	EncryptEvery int      `json:"encryptEvery"`
	IVHex        string   `json:"ivHex"`
	GeneratedBy  string   `json:"generatedBy"`
	Samples      []sample `json:"samples"`
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
