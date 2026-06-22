package core

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"
)

// createFLACBytes builds a minimal FLAC byte stream:
// [fLaC][STREAMINFO meta header (4)][STREAMINFO data (34)][frame sync (2)].
// The STREAMINFO packed fields (bytes 10-17) are sample_rate(20) |
// channels-1(3) | bits-per-sample-1(5) | total_samples(36), stored big-endian.
func createFLACBytes(totalSamples uint64) []byte {
	si := make([]byte, 34)
	binary.BigEndian.PutUint16(si[0:2], 4096)
	binary.BigEndian.PutUint16(si[2:4], 4096)

	// Pack sample_rate (44100=0xAC44, 20 bits), channels-1 (1, 3 bits),
	// bits-per-sample-1 (15, 5 bits), total_samples (36 bits) into bytes 10-17.
	packed := (uint64(44100) << 44) | (uint64(1) << 41) | (uint64(15) << 36) | totalSamples
	binary.BigEndian.PutUint64(si[10:18], packed)

	var buf []byte
	buf = append(buf, "fLaC"...)
	buf = append(buf, 0x80, 0x00, 0x00, 0x22) // last=true, STREAMINFO, length=34
	buf = append(buf, si...)
	buf = append(buf, 0xFF, 0xFA) // valid frame sync code for checkFLACStream
	return buf
}

func TestValidateDownloadedFile_NonExistent(t *testing.T) {
	result := ValidateDownloadedFile("/tmp/nonexistent_file_xyz_test.flac")
	if result.IsValid {
		t.Error("expected invalid for non-existent file")
	}
	if result.Reason == "" {
		t.Error("expected reason for non-existent file")
	}
}

func TestValidateDownloadedFile_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "empty.bin")
	if err := os.WriteFile(path, []byte{}, 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Error("expected invalid for empty file")
	}
}

func TestValidateDownloadedFile_TooSmall(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "tiny.txt")
	if err := os.WriteFile(path, []byte("hello"), 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Error("expected invalid for tiny file")
	}
}

func TestValidateDownloadedFile_JustBelowMinSize(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "just_below.bin")
	if err := os.WriteFile(path, make([]byte, minFileSize-1), 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Error("expected invalid for file below minFileSize")
	}
}

func TestValidateDownloadedFile_AtMinSize(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "at_min.bin")
	if err := os.WriteFile(path, make([]byte, minFileSize), 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Error("expected invalid: minFileSize still below previewMaxFileSize")
	}
}

func TestValidateDownloadedFile_BetweenMinAndPreviewThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "mid.bin")
	if err := os.WriteFile(path, make([]byte, minFileSize+100), 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Error("expected invalid: file size below previewMaxFileSize")
	}
	if result.Reason == "" {
		t.Error("expected reason for preview-sized file")
	}
}

func TestValidateDownloadedFile_NonFLACPathViaZeroSamples(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "zerosamples.flac")
	flac := createFLACBytes(0) // zero samples → getFLACDuration returns error
	padLen := int(previewMaxFileSize + 1 - int64(len(flac)))
	if padLen > 0 {
		flac = append(flac, make([]byte, padLen)...)
	}
	if err := os.WriteFile(path, flac, 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if !result.IsValid {
		t.Errorf("expected valid (non-FLAC path via zero samples), got: %s", result.Reason)
	}
	if result.Duration != 0 {
		t.Errorf("expected Duration=0, got %v", result.Duration)
	}

	runtime.GC()
}

func TestValidateDownloadedFile_ZeroBytes(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "zero.bin")
	if err := os.WriteFile(path, []byte{}, 0644); err != nil {
		t.Fatal(err)
	}
	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Error("expected invalid for zero-byte file")
	}
}

func TestValidationResult_Struct(t *testing.T) {
	r := ValidationResult{
		IsValid:  true,
		Duration: time.Second,
		Reason:   "all good",
	}
	if !r.IsValid {
		t.Error("IsValid should be true")
	}
	if r.Duration != time.Second {
		t.Errorf("Duration mismatch: %v", r.Duration)
	}
	if r.Reason != "all good" {
		t.Errorf("Reason mismatch: %s", r.Reason)
	}
}

func TestValidationResult_ZeroValue(t *testing.T) {
	r := ValidationResult{}
	if r.IsValid {
		t.Error("zero value ValidationResult should have IsValid=false")
	}
}

func TestConstants(t *testing.T) {
	if previewMaxDuration != 35*time.Second {
		t.Errorf("previewMaxDuration: expected %v, got %v", 35*time.Second, previewMaxDuration)
	}
	if previewMaxFileSize != int64(2*1024*1024) {
		t.Errorf("previewMaxFileSize: expected %d, got %d", 2*1024*1024, previewMaxFileSize)
	}
	if minFileSize != int64(1024) {
		t.Errorf("minFileSize: expected %d, got %d", 1024, minFileSize)
	}
}

func TestGetFLACDuration_ValidFLAC(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.flac")
	data := createFLACBytes(44100 * 60) // 60 seconds
	if err := os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}

	duration, err := getFLACDuration(path)
	if err != nil {
		t.Fatalf("getFLACDuration error: %v", err)
	}
	if duration < 59*time.Second || duration > 61*time.Second {
		t.Errorf("expected duration ~60s, got %v", duration)
	}
}

func TestGetFLACDuration_ShortFLAC(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "short.flac")
	data := createFLACBytes(44100 / 2) // 0.5 seconds
	if err := os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}

	duration, err := getFLACDuration(path)
	if err != nil {
		t.Fatalf("getFLACDuration error: %v", err)
	}
	if duration < 400*time.Millisecond || duration > 600*time.Millisecond {
		t.Errorf("expected duration ~0.5s, got %v", duration)
	}
}

func TestGetFLACDuration_ZeroSamples(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "zero.flac")
	data := createFLACBytes(0)
	if err := os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}

	_, err := getFLACDuration(path)
	if err == nil {
		t.Error("expected error for zero total samples")
	}
}



func TestGetFLACDuration_FLACWithLargePadding(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "padded.flac")
	flac := createFLACBytes(44100 * 60)
	// Pad to above previewMaxFileSize to simulate real scenario
	padLen := int(previewMaxFileSize + 1 - int64(len(flac)))
	if padLen > 0 {
		flac = append(flac, make([]byte, padLen)...)
	}
	if err := os.WriteFile(path, flac, 0644); err != nil {
		t.Fatal(err)
	}

	duration, err := getFLACDuration(path)
	if err != nil {
		t.Fatalf("getFLACDuration error on padded file: %v", err)
	}
	if duration < 59*time.Second || duration > 61*time.Second {
		t.Errorf("expected duration ~60s, got %v", duration)
	}
}

func TestValidateDownloadedFile_FLACShortDuration(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "short.flac")
	flac := createFLACBytes(44100 * 10) // 10 seconds < 35s threshold
	padLen := int(previewMaxFileSize + 1 - int64(len(flac)))
	if padLen > 0 {
		flac = append(flac, make([]byte, padLen)...)
	}
	if err := os.WriteFile(path, flac, 0644); err != nil {
		t.Fatal(err)
	}

	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Errorf("expected invalid for short FLAC (10s < 35s), got IsValid=true")
	}
	if result.Reason == "" {
		t.Error("expected reason for short FLAC")
	}
	if result.Duration <= 0 {
		t.Errorf("expected positive duration, got %v", result.Duration)
	}

	// Force GC to release file handle on Windows before TempDir cleanup
	runtime.GC()
}

func TestValidateDownloadedFile_FLACLongDuration(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "long.flac")
	flac := createFLACBytes(44100 * 60) // 60 seconds > 35s threshold
	padLen := int(previewMaxFileSize + 1 - int64(len(flac)))
	if padLen > 0 {
		flac = append(flac, make([]byte, padLen)...)
	}
	if err := os.WriteFile(path, flac, 0644); err != nil {
		t.Fatal(err)
	}

	result := ValidateDownloadedFile(path)
	if !result.IsValid {
		t.Errorf("expected valid for long FLAC (60s > 35s), got: %s", result.Reason)
	}
	if result.Duration <= 0 {
		t.Errorf("expected positive duration, got %v", result.Duration)
	}

	runtime.GC()
}

func TestValidateDownloadedFile_FLACJustBelowThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "below.flac")
	flac := createFLACBytes(44100 * 34) // 34 seconds < 35s
	padLen := int(previewMaxFileSize + 1 - int64(len(flac)))
	if padLen > 0 {
		flac = append(flac, make([]byte, padLen)...)
	}
	if err := os.WriteFile(path, flac, 0644); err != nil {
		t.Fatal(err)
	}

	result := ValidateDownloadedFile(path)
	if result.IsValid {
		t.Errorf("expected invalid for 34s FLAC (below 35s threshold)")
	}
	if result.Reason == "" {
		t.Error("expected reason for short FLAC")
	}

	runtime.GC()
}

func TestValidateDownloadedFile_FLACAtThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "at.flac")
	flac := createFLACBytes(44100 * 35) // exactly 35 seconds
	padLen := int(previewMaxFileSize + 1 - int64(len(flac)))
	if padLen > 0 {
		flac = append(flac, make([]byte, padLen)...)
	}
	if err := os.WriteFile(path, flac, 0644); err != nil {
		t.Fatal(err)
	}

	result := ValidateDownloadedFile(path)
	if !result.IsValid {
		t.Errorf("expected valid at exact 35.0s threshold, got: %s", result.Reason)
	}

	runtime.GC()
}
