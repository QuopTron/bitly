package share

import "testing"

func TestBestAlbumTrack(t *testing.T) {
	if got := bestAlbumTrack(nil, "album", "artist"); got != nil {
		t.Error("expected nil for nil tracks")
	}
	tracks := []extTrack{
		{Name: "T1", Artists: "Artist A", AlbumName: "Target", AlbumArtist: "Artist A"},
		{Name: "T2", Artists: "Artist B", AlbumName: "Other", ItemType: "album"},
		{Name: "Target", Artists: "Artist A", AlbumName: "Ignored", ItemType: "album"},
	}
	got := bestAlbumTrack(tracks, "Target", "Artist A")
	if got == nil || got.Name != "Target" {
		t.Errorf("expected 'Target' (exact album + artist + album type), got %v", got)
	}
	tracks2 := []extTrack{
		{Name: "T1", Artists: "Artist A", AlbumName: "Different", AlbumArtist: "Artist B"},
		{Name: "Targ", Artists: "Artist A", AlbumName: "X", ItemType: "album"},
	}
	got2 := bestAlbumTrack(tracks2, "Target", "Artist A")
	if got2 == nil || got2.Name != "Targ" {
		t.Errorf("expected 'Targ' (partial match + album type), got %v", got2)
	}
	tracks3 := []extTrack{{Name: "T1", Artists: "Z", AlbumName: "X", AlbumArtist: "Y"}}
	if got3 := bestAlbumTrack(tracks3, "Target", "Artist A"); got3 != nil {
		t.Errorf("expected nil for no match, got %v", got3)
	}
}

func TestBestArtistTrack(t *testing.T) {
	if got := bestArtistTrack(nil, "artist"); got != nil {
		t.Error("expected nil for nil tracks")
	}
	tracks := []extTrack{
		{Name: "T1", Artists: "Artist X", ItemType: "track"},
		{Name: "Other", Artists: "Artist Y", ItemType: "artist"},
		{Name: "Artist X", Artists: "Artist X", ItemType: "artist"},
	}
	got := bestArtistTrack(tracks, "Artist X")
	if got == nil || got.Name != "Artist X" {
		t.Errorf("expected 'Artist X' (exact match + artist type), got %v", got)
	}
	tracks2 := []extTrack{
		{Name: "Artist Xtra", Artists: "X", ItemType: "artist"},
		{Name: "Other", Artists: "Other", ItemType: "track"},
	}
	got2 := bestArtistTrack(tracks2, "Artist X")
	if got2 == nil || got2.Name != "Artist Xtra" {
		t.Errorf("expected 'Artist Xtra' (partial match), got %v", got2)
	}
	tracks3 := []extTrack{{Name: "T1", Artists: "Z", ItemType: "track"}}
	if got3 := bestArtistTrack(tracks3, "Target"); got3 != nil {
		t.Errorf("expected nil for no match, got %v", got3)
	}
}

func TestParseExtTracks(t *testing.T) {
	if got := parseExtTracks("invalid"); got != nil {
		t.Error("expected nil for invalid JSON")
	}
	if got := parseExtTracks("[]"); got != nil {
		t.Error("expected nil for empty array")
	}
	if got := parseExtTracks(`[{"id":"1","name":"Track1","artists":"A","album_name":"Album1"}]`); got == nil {
		t.Error("expected tracks for valid array")
	} else if len(got) != 1 || got[0].ID != "1" {
		t.Errorf("unexpected result: %+v", got)
	}
	if got := parseExtTracks(`{"tracks":[{"id":"2","name":"Track2","artists":"B","album_name":"Album2"}],"total":1}`); got == nil {
		t.Error("expected tracks for wrapper")
	} else if len(got) != 1 || got[0].ID != "2" {
		t.Errorf("unexpected result: %+v", got)
	}
}

func TestResultsCacheable(t *testing.T) {
	svc := newTestService(t)
	if !svc.resultsCacheable(nil) {
		t.Error("expected true for nil")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{}) {
		t.Error("expected true for empty")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{{Found: true}}) {
		t.Error("expected true for all found")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{{Found: false, Error: ""}}) {
		t.Error("expected true for empty error")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{{Found: false, Error: "no results"}}) {
		t.Error("expected true for no results")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{{Found: false, Error: "unsupported collection type"}}) {
		t.Error("expected true for unsupported type")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{{Found: false, Error: "album not found"}}) {
		t.Error("expected true for 'not found' suffix")
	}
	if !svc.resultsCacheable([]CrossExtensionShareResult{{Found: false, Error: "album found without shareable link"}}) {
		t.Error("expected true for found without link")
	}
	if svc.resultsCacheable([]CrossExtensionShareResult{{Found: false, Error: "network error"}}) {
		t.Error("expected false for other error")
	}
}
