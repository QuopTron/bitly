package extensions

import (
	"crypto/hmac"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"testing"
)

func TestMD5Hex(t *testing.T) {
	h := md5.Sum([]byte("hello"))
	result := hex.EncodeToString(h[:])
	if len(result) != 32 {
		t.Errorf("expected 32 chars, got %d", len(result))
	}
	if result != "5d41402abc4b2a76b9719d911017c592" {
		t.Errorf("unexpected md5: %s", result)
	}
}

func TestSHA1Hex(t *testing.T) {
	h := sha1.Sum([]byte("hello"))
	result := hex.EncodeToString(h[:])
	if len(result) != 40 {
		t.Errorf("expected 40 chars, got %d", len(result))
	}
}

func TestSHA256Hex(t *testing.T) {
	h := sha256.Sum256([]byte("hello"))
	result := hex.EncodeToString(h[:])
	if len(result) != 64 {
		t.Errorf("expected 64 chars, got %d", len(result))
	}
}

func TestHMACSHA256(t *testing.T) {
	mac := hmac.New(sha256.New, []byte("key"))
	mac.Write([]byte("data"))
	result := hex.EncodeToString(mac.Sum(nil))
	if len(result) != 64 {
		t.Errorf("expected 64 chars, got %d", len(result))
	}
}

func TestHMACSHA1(t *testing.T) {
	mac := hmac.New(sha1.New, []byte("key"))
	mac.Write([]byte("data"))
	result := hex.EncodeToString(mac.Sum(nil))
	if len(result) != 40 {
		t.Errorf("expected 40 chars, got %d", len(result))
	}
}

func TestBase64Encode(t *testing.T) {
	result := base64.StdEncoding.EncodeToString([]byte("hello"))
	expected := "aGVsbG8="
	if result != expected {
		t.Errorf("expected %s, got %s", expected, result)
	}
}

func TestBase64Decode(t *testing.T) {
	decoded, err := base64.StdEncoding.DecodeString("aGVsbG8=")
	if err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if string(decoded) != "hello" {
		t.Errorf("expected hello, got %s", string(decoded))
	}
}

func TestBase64RoundTrip(t *testing.T) {
	input := "test data with spaces and symbols!@#$%"
	encoded := base64.StdEncoding.EncodeToString([]byte(input))
	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if string(decoded) != input {
		t.Errorf("round trip failed: %s != %s", string(decoded), input)
	}
}

func TestHexEncode(t *testing.T) {
	result := hex.EncodeToString([]byte("hello"))
	if result != "68656c6c6f" {
		t.Errorf("expected 68656c6c6f, got %s", result)
	}
}

func TestHexDecode(t *testing.T) {
	decoded, err := hex.DecodeString("68656c6c6f")
	if err != nil {
		t.Fatalf("hex decode failed: %v", err)
	}
	if string(decoded) != "hello" {
		t.Errorf("expected hello, got %s", string(decoded))
	}
}

func TestHexRoundTrip(t *testing.T) {
	input := "any data \x00\x01\x02"
	encoded := hex.EncodeToString([]byte(input))
	decoded, err := hex.DecodeString(encoded)
	if err != nil {
		t.Fatalf("hex decode failed: %v", err)
	}
	if string(decoded) != input {
		t.Errorf("round trip failed")
	}
}
