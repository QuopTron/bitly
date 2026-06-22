package share

import "testing"

func TestNormalizeLooseTitle(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"", ""},
		{"  ", ""},
		{"Hello World", "hello world"},
		{"  Hello/World_Test ", "hello world test"},
		{"Café", "café"},
		{"ABC-123", "abc 123"},
		{"A|B&C+D.E", "a b c d e"},
		{"a\\b/c", "a b c"},
	}
	for _, tc := range tests {
		got := normalizeLooseTitle(tc.input)
		if got != tc.want {
			t.Errorf("normalizeLooseTitle(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestNormalizeLooseArtistName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"", ""},
		{"  ", ""},
		{"Mötley Crüe", "motley crue"},
		{"Straße", "strasse"},
		{"Ænima", "aenima"},
		{"Œuvre", "oeuvre"},
		{"Beyoncé", "beyonce"},
		{"Artist-Name", "artist name"},
	}
	for _, tc := range tests {
		got := normalizeLooseArtistName(tc.input)
		if got != tc.want {
			t.Errorf("normalizeLooseArtistName(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestFirstNonEmptyString(t *testing.T) {
	if got := firstNonEmptyString("", "", "pick", "skip"); got != "pick" {
		t.Errorf("got %q, want %q", got, "pick")
	}
	if got := firstNonEmptyString("", "", ""); got != "" {
		t.Errorf("got %q, want ''", got)
	}
	if got := firstNonEmptyString("direct"); got != "direct" {
		t.Errorf("got %q, want %q", got, "direct")
	}
}

func TestIsItemType(t *testing.T) {
	tests := []struct {
		itemType string
		match    string
		want     bool
	}{
		{"album", "album", true},
		{"ALBUM", "album", true},
		{"  album  ", "album", true},
		{"artist", "album", false},
		{"track", "track", true},
		{"", "album", false},
	}
	for _, tc := range tests {
		got := isItemType(&extTrack{ItemType: tc.itemType}, tc.match)
		if got != tc.want {
			t.Errorf("isItemType(%q, %q) = %v, want %v", tc.itemType, tc.match, got, tc.want)
		}
	}
}

func TestCollectionItemName(t *testing.T) {
	if got := collectionItemName(nil, false); got != "" {
		t.Errorf("nil track: got %q, want ''", got)
	}
	track := &extTrack{Name: "T1", Artists: "Artist A", AlbumName: "Album Y", ItemType: "album"}
	if got := collectionItemName(track, false); got != "T1" {
		t.Errorf("album: got %q, want %q", got, "T1")
	}
	track.ItemType = "track"
	if got := collectionItemName(track, false); got != "Album Y" {
		t.Errorf("track: got %q, want %q", got, "Album Y")
	}
	if got := collectionItemName(track, true); got != "Artist A" {
		t.Errorf("artist name for track: got %q, want %q", got, "Artist A")
	}
	track.ItemType = "artist"
	if got := collectionItemName(track, true); got != "T1" {
		t.Errorf("artist: got %q, want %q", got, "T1")
	}
}

func TestCollectionID(t *testing.T) {
	track := &extTrack{ID: "id123", ItemType: "artist"}
	if got := collectionID(track, "artist"); got != "id123" {
		t.Errorf("matching type: got %q, want %q", got, "id123")
	}
	if got := collectionID(track, "album"); got != "" {
		t.Errorf("non-matching: got %q, want ''", got)
	}
}
