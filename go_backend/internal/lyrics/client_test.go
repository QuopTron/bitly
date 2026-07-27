package lyrics

import (
	"testing"
)

func TestNewClient(t *testing.T) {
	c := NewClient()
	if c == nil {
		t.Fatal("expected non-nil client")
	}
	if len(c.providers) == 0 {
		t.Error("expected at least one provider")
	}
}

func TestNewClientWithGenius(t *testing.T) {
	c := NewClient("test-token")
	if c == nil {
		t.Fatal("expected non-nil client")
	}
	hasGenius := false
	for _, p := range c.providers {
		if p.Name() == "genius" {
			hasGenius = true
			break
		}
	}
	if !hasGenius {
		t.Error("expected Genius provider to be registered")
	}
}

func TestSetGeniusToken(t *testing.T) {
	c := NewClient()
	if c == nil {
		t.Fatal("expected non-nil client")
	}
	// Should not panic
	c.SetGeniusToken("new-token")
	hasGenius := false
	for _, p := range c.providers {
		if p.Name() == "genius" {
			hasGenius = true
			break
		}
	}
	if !hasGenius {
		t.Error("expected Genius provider after SetGeniusToken")
	}
}

func TestSetGeniusToken_Empty(t *testing.T) {
	c := NewClient()
	c.SetGeniusToken("") // should not add Genius
	for _, p := range c.providers {
		if p.Name() == "genius" {
			t.Error("expected no Genius provider with empty token")
		}
	}
}

func TestSetGeniusToken_Replace(t *testing.T) {
	c := NewClient("old-token")
	c.SetGeniusToken("new-token") // update existing
	count := 0
	for _, p := range c.providers {
		if p.Name() == "genius" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("expected exactly 1 Genius provider, got %d", count)
	}
}

func TestProviderNames(t *testing.T) {
	c := NewClient()
	names := make(map[string]bool)
	for _, p := range c.providers {
		names[p.Name()] = true
	}
	if !names["lrclib"] {
		t.Error("expected lrclib provider")
	}
}

func TestStripHTMLTags(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"<b>hello</b>", "hello"},
		{"<div>test<br/>line2</div>", "testline2"},
		{"no tags here", "no tags here"},
		{"<a href='x'>link</a> and <b>bold</b>", "link and bold"},
		{"", ""},
	}
	for _, tt := range tests {
		got := stripHTMLTags(tt.input)
		if got != tt.want {
			t.Errorf("stripHTMLTags(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestLyricsSourced(t *testing.T) {
	l := &Lyrics{
		TrackName:   "Test Song",
		ArtistName:  "Test Artist",
		PlainLyrics: "line1\nline2",
		Source:      "lrclib",
	}
	if l.Source != "lrclib" {
		t.Errorf("expected source lrclib, got %s", l.Source)
	}
	if l.PlainLyrics != "line1\nline2" {
		t.Errorf("expected lyrics, got %s", l.PlainLyrics)
	}
}
