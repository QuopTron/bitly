package share

import "testing"

func TestNormalizeShareURL(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"", ""},
		{"  ", ""},
		{"not-a-url", ""},
		{"http://example.com", "http://example.com"},
		{"https://example.com/album/123", "https://example.com/album/123"},
		{"  https://example.com  ", "https://example.com"},
	}
	for _, tc := range tests {
		got := normalizeShareURL(tc.input)
		if got != tc.want {
			t.Errorf("normalizeShareURL(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestStripProviderPrefix(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"", ""},
		{"no-prefix", "no-prefix"},
		{"provider:abc123", "abc123"},
		{"a:b:c", "b:c"},
		{":", ":"},
		{"spotify:track:123", "track:123"},
	}
	for _, tc := range tests {
		got := stripProviderPrefix(tc.input)
		if got != tc.want {
			t.Errorf("stripProviderPrefix(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestURLFromExternalLinks(t *testing.T) {
	if got := urlFromExternalLinks(nil, "album"); got != "" {
		t.Errorf("nil map: got %q, want ''", got)
	}
	if got := urlFromExternalLinks(map[string]string{}, "album"); got != "" {
		t.Errorf("empty map: got %q, want ''", got)
	}
	links := map[string]string{
		"album":  "https://example.com/album/1",
		"artist": "not-a-url",
	}
	if got := urlFromExternalLinks(links, "album"); got != "https://example.com/album/1" {
		t.Errorf("album link: got %q, want %q", got, "https://example.com/album/1")
	}
	if got := urlFromExternalLinks(links, "artist"); got != "" {
		t.Errorf("invalid artist url: got %q, want ''", got)
	}
}
