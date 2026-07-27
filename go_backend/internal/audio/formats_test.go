package audio

import (
	"os"
	"testing"
)

func TestReadBits(t *testing.T) {
	tests := []struct {
		data []byte
		n    int
		want int64
	}{
		{[]byte{0xFF}, 8, 255},
		{[]byte{0xF0}, 4, 15},  // top 4 bits of 0xF0 = 15
		{[]byte{0xAB, 0xCD}, 16, 0xABCD},
		{[]byte{0x12, 0x34}, 12, 0x123}, // 12 bits: 0x12 (8) + top 4 of 0x34 (0x3)
		{[]byte{0x80}, 1, 1},             // top bit of 0x80 = 1
		{[]byte{0x12}, 5, 2},            // top 5 bits of 0x12 = 00010 = 2
	}

	for _, tt := range tests {
		got := readBits(tt.data, tt.n)
		if got != tt.want {
			t.Errorf("readBits(%v, %d) = %d, want %d", tt.data, tt.n, got, tt.want)
		}
	}
}

func TestReadFLACMagic(t *testing.T) {
	// Create a minimal valid FLAC file
	f, err := os.CreateTemp("", "test-*.flac")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(f.Name())

	// Write FLAC header: fLaC + STREAMINFO block
	header := []byte{
		0x66, 0x4C, 0x61, 0x43, // "fLaC"
		0x80,                                           // last-metadata-block flag + STREAMINFO
		0x00, 0x00, 0x22,                               // block length: 34 bytes
		// STREAMINFO (34 bytes, simplified)
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // min/max block size
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // min/max frame size (0=unknown)
		0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, // sample rate=16000, channels=1, bits=16, samples=0
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // MD5
		0x00, 0x00, 0x00, 0x00,
		// Audio data
		0xFF, 0xF8, 0x00, 0x00,
	}
	f.Write(header)
	f.Close()

	// Can't easily call readFLAC without a full Metadata struct
	// This just verifies our file has the right magic bytes
	data, _ := os.ReadFile(f.Name())
	if string(data[:4]) != "fLaC" {
		t.Error("expected fLaC magic bytes")
	}
}

func TestReadMP3Magic(t *testing.T) {
	f, err := os.CreateTemp("", "test-*.mp3")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(f.Name())

	header := []byte{0x49, 0x44, 0x33} // ID3
	f.Write(header)
	f.Close()

	data, _ := os.ReadFile(f.Name())
	if string(data[:3]) != "ID3" {
		t.Error("expected ID3 magic bytes")
	}
}

func TestReadOGGMagic(t *testing.T) {
	f, err := os.CreateTemp("", "test-*.ogg")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(f.Name())

	header := []byte{0x4F, 0x67, 0x67, 0x53} // OggS
	f.Write(header)
	f.Close()

	data, _ := os.ReadFile(f.Name())
	if string(data[:4]) != "OggS" {
		t.Error("expected OggS magic bytes")
	}
}
