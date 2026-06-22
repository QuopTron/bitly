package metadata

import (
	"testing"
)

func TestParseIndexPair(t *testing.T) {
	tests := []struct {
		input         string
		wantNum, wantTotal int
	}{
		{"3/12", 3, 12},
		{"3", 3, 0},
		{"", 0, 0},
		{" 3 / 12 ", 3, 12},
		{"abc", 0, 0},
		{"5/", 5, 0},
		{"0/0", 0, 0},
		{"12/24", 12, 24},
		{"  1/2  ", 1, 2},
	}
	for _, tt := range tests {
		num, total := ParseIndexPair(tt.input)
		if num != tt.wantNum || total != tt.wantTotal {
			t.Errorf("ParseIndexPair(%q) = (%d, %d), want (%d, %d)", tt.input, num, total, tt.wantNum, tt.wantTotal)
		}
	}
}

func TestParsePositiveInt(t *testing.T) {
	tests := []struct {
		input string
		want  int
	}{
		{"42", 42},
		{"0", 0},
		{"", 0},
		{"-5", -5},
		{"abc", 0},
		{"  10  ", 10},
	}
	for _, tt := range tests {
		got := ParsePositiveInt(tt.input)
		if got != tt.want {
			t.Errorf("ParsePositiveInt(%q) = %d, want %d", tt.input, got, tt.want)
		}
	}
}

func TestFormatIndexValue(t *testing.T) {
	tests := []struct {
		number, total int
		want          string
	}{
		{3, 12, "3/12"},
		{3, 0, "3"},
		{0, 12, ""},
		{0, 0, ""},
		{-1, 5, ""},
		{1, 1, "1/1"},
	}
	for _, tt := range tests {
		got := FormatIndexValue(tt.number, tt.total)
		if got != tt.want {
			t.Errorf("FormatIndexValue(%d, %d) = %q, want %q", tt.number, tt.total, got, tt.want)
		}
	}
}

func TestCleanGenre(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Rock", "Rock"},
		{"", ""},
		{"(0)Blues", "Blues"},
		{"(9)Jazz", "Jazz"},
		{"(17)Rock", "Rock"},
		{"(999)Unknown Genre", "(999)Unknown Genre"},
		{"Pop", "Pop"},
		{"(invalid)Rock", "(invalid)Rock"},
		{"(0)", "Blues"},
	}
	for _, tt := range tests {
		got := CleanGenre(tt.input)
		if got != tt.want {
			t.Errorf("CleanGenre(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestFirstTextValue(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"hello\x00world", "hello"},
		{"hello", "hello"},
		{"\x00world", ""},
		{"", ""},
		{"abc\x00def\x00ghi", "abc"},
	}
	for _, tt := range tests {
		got := FirstTextValue(tt.input)
		if got != tt.want {
			t.Errorf("FirstTextValue(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestGetCoverFromSpotify(t *testing.T) {
	tests := []struct {
		url        string
		maxQuality bool
		want       string
	}{
		{"", false, ""},
		{"", true, ""},
		{"https://i.scdn.co/image/ab67616d00001e02abc123", false,
			"https://i.scdn.co/image/ab67616d0000b273abc123"},
		{"https://i.scdn.co/image/ab67616d0000b273abc123", false,
			"https://i.scdn.co/image/ab67616d0000b273abc123"},
		{"https://i.scdn.co/image/ab67616d00001e02abc123", true,
			"https://i.scdn.co/image/ab67616d000082c1abc123"},
		{"https://example.com/cover.jpg", false, "https://example.com/cover.jpg"},
	}
	for _, tt := range tests {
		got := GetCoverFromSpotify(tt.url, tt.maxQuality)
		if got != tt.want {
			t.Errorf("GetCoverFromSpotify(%q, %v) = %q, want %q", tt.url, tt.maxQuality, got, tt.want)
		}
	}
}

func TestConvertSmallToMedium(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"https://i.scdn.co/image/ab67616d00001e02abc123",
			"https://i.scdn.co/image/ab67616d0000b273abc123"},
		{"https://i.scdn.co/image/ab67616d0000b273abc123",
			"https://i.scdn.co/image/ab67616d0000b273abc123"},
		{"https://example.com/cover.jpg", "https://example.com/cover.jpg"},
		{"", ""},
	}
	for _, tt := range tests {
		got := convertSmallToMedium(tt.input)
		if got != tt.want {
			t.Errorf("convertSmallToMedium(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestUpgradeToMaxQuality(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"https://i.scdn.co/image/ab67616d0000b273abc123",
			"https://i.scdn.co/image/ab67616d000082c1abc123"},
		{"https://cdn-images.dzcdn.net/cover/200x200-000000-80-0-0.jpg",
			"https://cdn-images.dzcdn.net/cover/1800x1800-000000-80-0-0.jpg"},
		{"https://resources.tidal.com/images/320x320.jpg",
			"https://resources.tidal.com/images/origin.jpg"},
		{"https://static.qobuz.com/images/covers/64/123456789_64.jpg",
			"https://static.qobuz.com/images/covers/64/123456789_max.jpg"},
		{"https://example.com/other.jpg", "https://example.com/other.jpg"},
		{"", ""},
	}
	for _, tt := range tests {
		got := upgradeToMaxQuality(tt.input)
		if got != tt.want {
			t.Errorf("upgradeToMaxQuality(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestUpgradeDeezerCover(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"https://cdn-images.dzcdn.net/cover/200x200-000000-80-0-0.jpg",
			"https://cdn-images.dzcdn.net/cover/1800x1800-000000-80-0-0.jpg"},
		{"https://cdn-images.dzcdn.net/cover/500x500-111111-75-0-0.jpg",
			"https://cdn-images.dzcdn.net/cover/1800x1800-000000-80-0-0.jpg"},
		{"https://example.com/other.jpg", "https://example.com/other.jpg"},
	}
	for _, tt := range tests {
		got := upgradeDeezerCover(tt.input)
		if got != tt.want {
			t.Errorf("upgradeDeezerCover(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestUpgradeTidalCover(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"https://resources.tidal.com/images/320x320.jpg",
			"https://resources.tidal.com/images/origin.jpg"},
		{"https://resources.tidal.com/images/1280x1280.jpg",
			"https://resources.tidal.com/images/origin.jpg"},
		{"https://example.com/other.jpg", "https://example.com/other.jpg"},
	}
	for _, tt := range tests {
		got := upgradeTidalCover(tt.input)
		if got != tt.want {
			t.Errorf("upgradeTidalCover(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestUpgradeQobuzCover(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"https://static.qobuz.com/images/covers/64/123456789_64.jpg",
			"https://static.qobuz.com/images/covers/64/123456789_max.jpg"},
		{"https://static.qobuz.com/images/covers/64/abcdef_320.jpg",
			"https://static.qobuz.com/images/covers/64/abcdef_max.jpg"},
		{"https://example.com/other.jpg", "https://example.com/other.jpg"},
	}
	for _, tt := range tests {
		got := upgradeQobuzCover(tt.input)
		if got != tt.want {
			t.Errorf("upgradeQobuzCover(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestFilepathExt(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"song.flac", ".flac"},
		{"song.mp3", ".mp3"},
		{"/path/to/song.m4a", ".m4a"},
		{"C:\\music\\song.opus", ".opus"},
		{"noext", ""},
		{".hidden", ".hidden"},
		{"song.", "."},
	}
	for _, tt := range tests {
		got := filepathExt(tt.input)
		if got != tt.want {
			t.Errorf("filepathExt(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestFnvHash(t *testing.T) {
	tests := []struct {
		input string
	}{
		{""},
		{"test"},
		{"hello"},
		{"abc|123|456"},
		{"different"},
	}
	// FNV-1a 64-bit is deterministic: same input always gives same output
	results := make(map[string]uint64)
	for _, tt := range tests {
		got := fnvHash(tt.input)
		if prev, exists := results[tt.input]; exists {
			if got != prev {
				t.Errorf("fnvHash(%q) inconsistent: %d vs %d", tt.input, got, prev)
			}
		}
		results[tt.input] = got
	}
	// Different inputs should produce different hashes (collision unlikely in this small set)
	seen := make(map[uint64]bool)
	for _, h := range results {
		if seen[h] {
			t.Errorf("hash collision detected")
		}
		seen[h] = true
	}
}

func TestAudioMetadataZeroValues(t *testing.T) {
	var m AudioMetadata
	if m.Title != "" || m.Artist != "" || m.Album != "" {
		t.Error("expected zero values for string fields")
	}
	if m.TrackNumber != 0 || m.TotalTracks != 0 {
		t.Error("expected zero TrackNumber and TotalTracks")
	}
}

func TestAudioQualityZeroValues(t *testing.T) {
	var q AudioQuality
	if q.BitDepth != 0 || q.SampleRate != 0 || q.Duration != 0 {
		t.Error("expected zero values for AudioQuality")
	}
	if q.Codec != "" {
		t.Error("expected empty Codec")
	}
}

func TestParseIndexPairEdgeCases(t *testing.T) {
	// Very long numbers
	num, total := ParseIndexPair("999999/999999")
	if num != 999999 || total != 999999 {
		t.Errorf("ParseIndexPair(999999/999999) = (%d, %d)", num, total)
	}
	// Negative numbers
	num, total = ParseIndexPair("-1/-2")
	if num != -1 || total != -2 {
		t.Errorf("ParseIndexPair(-1/-2) = (%d, %d)", num, total)
	}
}

func TestFirstTextValueNoNull(t *testing.T) {
	input := "simple text without null"
	got := FirstTextValue(input)
	if got != input {
		t.Errorf("FirstTextValue(%q) = %q, want %q", input, got, input)
	}
}

func TestFirstTextValueMultipleNulls(t *testing.T) {
	input := "first\x00second\x00third"
	got := FirstTextValue(input)
	if got != "first" {
		t.Errorf("FirstTextValue(%q) = %q, want %q", input, got, "first")
	}
}
