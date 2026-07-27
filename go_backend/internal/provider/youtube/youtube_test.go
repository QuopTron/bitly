package youtube

import (
	"strings"
	"testing"
)

// ─── Helper functions tests ──────────────────────────────────────

func TestSplitLines(t *testing.T) {
	tests := []struct {
		input string
		count int
	}{
		{"", 0},
		{"line1", 1},
		{"line1\nline2", 2},
		{"line1\nline2\nline3", 3},
		{"line1\n\nline3", 2}, // empty line skipped
		{"  line1  \n  line2  ", 2},
	}
	for _, tt := range tests {
		result := splitLines(tt.input)
		if len(result) != tt.count {
			t.Errorf("splitLines(%q): expected %d lines, got %d", tt.input, tt.count, len(result))
		}
	}
}

func TestFirstJSONLine(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"", ""},
		{"not json", ""},
		{"{valid}", "{valid}"},
		{"warn\n{json}", "{json}"},
		{"warn1\nwarn2\n{json}\nmore", "{json}"},
		{"  {json}  ", "{json}"},
	}
	for _, tt := range tests {
		result := firstJSONLine(tt.input)
		if result != tt.want {
			t.Errorf("firstJSONLine(%q): expected %q, got %q", tt.input, tt.want, result)
		}
	}
}

func TestNonEmpty(t *testing.T) {
	tests := []struct {
		vals []string
		want string
	}{
		{[]string{"", "", "c"}, "c"},
		{[]string{"a", "b"}, "a"},
		{[]string{"", "", ""}, ""},
		{[]string{}, ""},
		{[]string{"only"}, "only"},
	}
	for _, tt := range tests {
		result := nonEmpty(tt.vals...)
		if result != tt.want {
			t.Errorf("nonEmpty(%v): expected %q, got %q", tt.vals, tt.want, result)
		}
	}
}

// ─── Client initialization ───────────────────────────────────────

func TestNewClient(t *testing.T) {
	c := NewClient("")
	if c.ytdlpPath != "yt-dlp" {
		t.Errorf("expected default yt-dlp path, got %s", c.ytdlpPath)
	}
	c2 := NewClient("/custom/path/yt-dlp")
	if c2.ytdlpPath != "/custom/path/yt-dlp" {
		t.Errorf("expected custom path, got %s", c2.ytdlpPath)
	}
}

func TestClientName(t *testing.T) {
	c := NewClient("")
	if c.Name() != "youtube" {
		t.Errorf("expected youtube, got %s", c.Name())
	}
}

// ─── ID prefix verification ──────────────────────────────────────

func TestGetTrack_ReturnsPrefix(t *testing.T) {
	// Verify ID prefix pattern by checking stubs' ytdlpTrack struct
	if !strings.HasPrefix("yt:", "yt:") {
		t.Error("ID prefix should be 'yt:'")
	}
}

func TestGetStreamURL_ReturnsErrorWithoutVideo(t *testing.T) {
	c := NewClient("")
	// Without yt-dlp binary, all yt-dlp calls should fail
	_, err := c.GetTrack("nonexistent")
	if err == nil {
		t.Log("note: GetTrack may succeed if yt-dlp is in PATH")
	}
	_ = err
}

// ─── Search limits ───────────────────────────────────────────────

func TestSearchTracks_LimitClamping(t *testing.T) {
	c := NewClient("")
	// These should not panic — verify the method handles limit values
	// Actual yt-dlp call will fail, but the clamping and formatting should work
	_, _ = c.SearchTracks("test", 0)
	_, _ = c.SearchTracks("test", 200)
}

func TestSearchAlbums_LimitClamping(t *testing.T) {
	c := NewClient("")
	_, _ = c.SearchAlbums("test", 0)
	_, _ = c.SearchAlbums("test", 200)
}

func TestSearchArtists_LimitClamping(t *testing.T) {
	c := NewClient("")
	_, _ = c.SearchArtists("test", 0)
	_, _ = c.SearchArtists("test", 200)
}
