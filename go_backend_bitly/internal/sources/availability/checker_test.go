package availability

import (
	"testing"
)

func TestNewChecker(t *testing.T) {
	c := NewChecker()
	if c == nil {
		t.Fatal("NewChecker() returned nil")
	}
	if c.client == nil {
		t.Error("NewChecker().client is nil")
	}
	if c.resolver == nil {
		t.Error("NewChecker().resolver is nil")
	}
}

func TestCheckTrackBothEmpty(t *testing.T) {
	c := NewChecker()
	results, err := c.CheckTrack("", "")
	if err != nil {
		t.Errorf("CheckTrack('', '') returned error: %v", err)
	}
	if results == nil {
		t.Fatal("CheckTrack('', '') returned nil, want empty slice")
	}
	if len(results) != 0 {
		t.Errorf("CheckTrack('', '') returned %d results, want 0", len(results))
	}
}

func TestCheckTrackAvailabilityEmptyInputs(t *testing.T) {
	c := NewChecker()
	result, err := c.CheckTrackAvailability("", "")
	if err != nil {
		t.Errorf("CheckTrackAvailability('', '') returned error: %v", err)
	}
	if result == nil {
		t.Fatal("CheckTrackAvailability('', '') returned nil")
	}

	m, ok := result.(map[string]interface{})
	if !ok {
		t.Fatalf("result type = %T, want map[string]interface{}", result)
	}

	ts, ok := m["timestamp"]
	if !ok {
		t.Fatal("result map missing 'timestamp' key")
	}
	if _, ok := ts.(int64); !ok {
		t.Errorf("timestamp type = %T, want int64", ts)
	}
}

func TestCheckTrackAvailabilityOnlyTimestampWhenEmpty(t *testing.T) {
	c := NewChecker()
	result, _ := c.CheckTrackAvailability("", "")
	m := result.(map[string]interface{})

	if len(m) != 1 {
		t.Errorf("result map has %d keys, want 1 (only timestamp)", len(m))
	}
}

func TestAvailabilityResultAllFields(t *testing.T) {
	r := AvailabilityResult{
		Provider:  "deezer",
		TrackID:   "123456789",
		Available: true,
		Quality:   "lossless",
		URL:       "https://deezer.com/track/123456789",
	}
	if r.Provider != "deezer" {
		t.Errorf("Provider = %q, want %q", r.Provider, "deezer")
	}
	if r.TrackID != "123456789" {
		t.Errorf("TrackID = %q, want %q", r.TrackID, "123456789")
	}
	if !r.Available {
		t.Error("Available = false, want true")
	}
	if r.Quality != "lossless" {
		t.Errorf("Quality = %q, want %q", r.Quality, "lossless")
	}
	if r.URL != "https://deezer.com/track/123456789" {
		t.Errorf("URL = %q, want %q", r.URL, "https://deezer.com/track/123456789")
	}
}

func TestAvailabilityResultEmptyOptional(t *testing.T) {
	r := AvailabilityResult{
		Provider:  "tidal",
		TrackID:   "abc",
		Available: false,
	}
	if r.Quality != "" {
		t.Errorf("Quality = %q, want empty", r.Quality)
	}
	if r.URL != "" {
		t.Errorf("URL = %q, want empty", r.URL)
	}
}

func TestTrackAvailabilityConstruction(t *testing.T) {
	a := &TrackAvailability{
		SpotifyID:  "spotify:track:abc123",
		Tidal:      true,
		Amazon:     false,
		Qobuz:      true,
		Deezer:     true,
		YouTube:    false,
		TidalURL:   "https://tidal.com/track/1",
		AmazonURL:  "",
		QobuzURL:   "https://qobuz.com/track/2",
		DeezerURL:  "https://deezer.com/track/3",
		YouTubeURL: "",
		DeezerID:   "3",
		QobuzID:    "2",
		TidalID:    "1",
		YouTubeID:  "",
	}
	if a.SpotifyID != "spotify:track:abc123" {
		t.Errorf("SpotifyID = %q", a.SpotifyID)
	}
	if !a.Tidal {
		t.Error("Tidal = false, want true")
	}
	if a.Amazon {
		t.Error("Amazon = true, want false")
	}
	if !a.Deezer {
		t.Error("Deezer = false, want true")
	}
	if !a.Qobuz {
		t.Error("Qobuz = false, want true")
	}
	if a.YouTube {
		t.Error("YouTube = true, want false")
	}
}

func TestSetRegionValid(t *testing.T) {
	original := GetRegion()
	defer SetRegion(original)

	SetRegion("GB")
	if got := GetRegion(); got != "GB" {
		t.Errorf("GetRegion() = %q, want %q", got, "GB")
	}
}

func TestSetRegionTooLong(t *testing.T) {
	original := GetRegion()
	defer SetRegion(original)

	SetRegion("USA")
	if got := GetRegion(); got != "US" {
		t.Errorf("GetRegion() = %q, want %q", got, "US")
	}
}

func TestSetRegionSpecialChars(t *testing.T) {
	original := GetRegion()
	defer SetRegion(original)

	SetRegion("G!")
	if got := GetRegion(); got != "US" {
		t.Errorf("GetRegion() = %q, want %q", got, "US")
	}
}

func TestSetRegionLowercase(t *testing.T) {
	original := GetRegion()
	defer SetRegion(original)

	SetRegion("gb")
	if got := GetRegion(); got != "GB" {
		t.Errorf("GetRegion() = %q, want %q", got, "GB")
	}
}

func TestSetRegionEmpty(t *testing.T) {
	original := GetRegion()
	defer SetRegion(original)

	SetRegion("")
	if got := GetRegion(); got != "US" {
		t.Errorf("GetRegion() = %q, want %q", got, "US")
	}
}

func TestAlbumAvailabilityConstruction(t *testing.T) {
	a := &AlbumAvailability{
		SpotifyID: "album:abc",
		Deezer:    true,
		DeezerURL: "https://deezer.com/album/456",
		DeezerID:  "456",
	}
	if a.SpotifyID != "album:abc" {
		t.Errorf("SpotifyID = %q", a.SpotifyID)
	}
	if !a.Deezer {
		t.Error("Deezer = false, want true")
	}
	if a.DeezerURL != "https://deezer.com/album/456" {
		t.Errorf("DeezerURL = %q", a.DeezerURL)
	}
	if a.DeezerID != "456" {
		t.Errorf("DeezerID = %q", a.DeezerID)
	}
}
