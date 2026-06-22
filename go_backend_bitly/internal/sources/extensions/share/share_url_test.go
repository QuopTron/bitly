package share

import "testing"

func TestTemplateShareURL(t *testing.T) {
	svc := newTestService(t)
	cases := []struct {
		ext, typ, id, want string
	}{
		{"test-ext", "album", "abc123", "https://ex.com/album/abc123"},
		{"test-ext", "artist", "art456", "https://ex.com/artist/art456"},
		{"test-ext", "album", "", ""},
		{"nonexistent", "album", "id", ""},
		{"test-ext", "track", "id", ""},
		{"test-ext", "album", "provider:strip:me", "https://ex.com/album/strip:me"},
	}
	for _, c := range cases {
		got := svc.templateShareURL(c.ext, c.typ, c.id)
		if got != c.want {
			t.Errorf("templateShareURL(%q,%q,%q) = %q, want %q", c.ext, c.typ, c.id, got, c.want)
		}
	}
}

func TestResolveShareURL(t *testing.T) {
	svc := newTestService(t)
	if got := svc.resolveShareURL("test-ext", nil, "album"); got != "" {
		t.Errorf("nil track: got %q, want ''", got)
	}
	track := &extTrack{
		AlbumURL: "https://ex.com/album/1",
		AlbumID:  "album123",
		ID:       "track456",
		ItemType: "track",
	}
	if got := svc.resolveShareURL("test-ext", track, "album"); got != "https://ex.com/album/1" {
		t.Errorf("album url: got %q, want %q", got, "https://ex.com/album/1")
	}
	track.AlbumURL = ""
	track.ExternalLinks = map[string]string{"album": "https://ex.com/ext-album/1"}
	if got := svc.resolveShareURL("test-ext", track, "album"); got != "https://ex.com/ext-album/1" {
		t.Errorf("external link: got %q, want %q", got, "https://ex.com/ext-album/1")
	}
	track.ExternalLinks = nil
	if got := svc.resolveShareURL("test-ext", track, "album"); got != "https://ex.com/album/album123" {
		t.Errorf("template id: got %q, want %q", got, "https://ex.com/album/album123")
	}
	track2 := &extTrack{ArtistURL: "https://ex.com/artist/1", ArtistID: "art789"}
	if got := svc.resolveShareURL("test-ext", track2, "artist"); got != "https://ex.com/artist/1" {
		t.Errorf("artist url: got %q, want %q", got, "https://ex.com/artist/1")
	}
	track2.ArtistURL = ""
	if got := svc.resolveShareURL("test-ext", track2, "artist"); got != "https://ex.com/artist/art789" {
		t.Errorf("artist template: got %q, want %q", got, "https://ex.com/artist/art789")
	}
	track2.ItemType = "artist"
	track2.ExternalURL = "https://ex.com/artist/external/1"
	if got := svc.resolveShareURL("test-ext", track2, "album"); got != "" {
		t.Errorf("no album url: got %q, want ''", got)
	}
}
