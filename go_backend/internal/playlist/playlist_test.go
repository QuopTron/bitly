package playlist

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestNewPlaylist(t *testing.T) {
	pl := New("My Playlist", "User", nil)
	if pl.Name != "My Playlist" {
		t.Errorf("expected 'My Playlist', got %s", pl.Name)
	}
	if pl.Creator != "User" {
		t.Errorf("expected 'User', got %s", pl.Creator)
	}
	if pl.ID == "" {
		t.Error("expected non-empty ID")
	}
	if pl.TrackCount != 0 {
		t.Errorf("expected 0, got %d", pl.TrackCount)
	}
}

func TestNewPlaylistWithTracks(t *testing.T) {
	tracks := []PlaylistTrack{
		{Title: "Song A", Artist: "Artist A", Duration: 200000},
		{Title: "Song B", Artist: "Artist B", Duration: 300000},
	}
	pl := New("Test", "Tester", tracks)
	if pl.TrackCount != 2 {
		t.Errorf("expected 2 tracks, got %d", pl.TrackCount)
	}
}

func TestFromTrackResults(t *testing.T) {
	results := []provider.TrackResult{
		{ID: "1", Title: "Song A", Artist: "Artist A", Album: "Album A",
			Duration: 200000, ISRC: "ISRC001", CoverURL: "http://cover", Provider: "deezer"},
		{ID: "2", Title: "Song B", Artist: "Artist B", Album: "Album B",
			Duration: 300000, ISRC: "ISRC002"},
	}

	tracks := FromTrackResults(results)
	if len(tracks) != 2 {
		t.Fatalf("expected 2 tracks, got %d", len(tracks))
	}
	if tracks[0].Title != "Song A" || tracks[0].Artist != "Artist A" {
		t.Errorf("track 0: expected Song A / Artist A, got %s / %s", tracks[0].Title, tracks[0].Artist)
	}
	if tracks[0].ISRC != "ISRC001" {
		t.Errorf("track 0 ISRC: expected ISRC001, got %s", tracks[0].ISRC)
	}
	if tracks[0].Provider != "deezer" {
		t.Errorf("track 0 provider: expected deezer, got %s", tracks[0].Provider)
	}
}

func TestFromTrackResultsEmpty(t *testing.T) {
	tracks := FromTrackResults(nil)
	if tracks == nil || len(tracks) != 0 {
		t.Errorf("expected empty slice for nil input")
	}
	tracks = FromTrackResults([]provider.TrackResult{})
	if len(tracks) != 0 {
		t.Errorf("expected empty slice for empty input")
	}
}

func TestFromXSPF(t *testing.T) {
	x := &XSPFPlaylist{
		Title:   "Imported",
		Creator: "User",
		TrackList: TrackList{
			Track: []XSPFTrack{
				{
					Title:    "Song X",
					Creator:  "Artist X",
					Album:    "Album X",
					Duration: 400000,
					Image:    "http://cover",
					Identifier: "isrc:ISRC003",
					Extension: &Extension{
						Application: "bitly",
						Provider:    "qobuz",
						TrackID:     "67890",
					},
				},
			},
		},
	}

	pl := FromXSPF(x)
	if pl.Name != "Imported" {
		t.Errorf("expected 'Imported', got %s", pl.Name)
	}
	if pl.TrackCount != 1 {
		t.Errorf("expected 1 track, got %d", pl.TrackCount)
	}
	if pl.Tracks[0].ISRC != "isrc:ISRC003" {
		t.Errorf("expected 'isrc:ISRC003', got %s", pl.Tracks[0].ISRC)
	}
	if pl.Tracks[0].Provider != "qobuz" {
		t.Errorf("expected 'qobuz', got %s", pl.Tracks[0].Provider)
	}
}

func TestFromXSPFNoExtension(t *testing.T) {
	x := &XSPFPlaylist{
		Title: "No Ext",
		TrackList: TrackList{
			Track: []XSPFTrack{
				{Title: "Song", Creator: "Artist", Duration: 100000},
			},
		},
	}

	pl := FromXSPF(x)
	if pl.TrackCount != 1 {
		t.Errorf("expected 1 track, got %d", pl.TrackCount)
	}
	if pl.Tracks[0].Provider != "" {
		t.Errorf("expected empty provider, got %s", pl.Tracks[0].Provider)
	}
}

func TestFromXSPFEmptyTrackList(t *testing.T) {
	x := &XSPFPlaylist{Title: "Empty"}
	pl := FromXSPF(x)
	if pl.TrackCount != 0 {
		t.Errorf("expected 0 tracks, got %d", pl.TrackCount)
	}
}
