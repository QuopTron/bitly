package playlist

import (
	"strings"
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

func TestToXSPF(t *testing.T) {
	pl := New("Export Test", "Me", []PlaylistTrack{
		{Title: "Track 1", Artist: "Art 1", Album: "Alb 1", Duration: 100000,
			ISRC: "ISRC001", Provider: "deezer", TrackID: "123"},
		{Title: "Track 2", Artist: "Art 2", Duration: 200000,
			Location: "file:///music/song.flac"},
	})

	x := pl.ToXSPF()
	if x.Title != "Export Test" {
		t.Errorf("expected 'Export Test', got %s", x.Title)
	}
	if len(x.TrackList.Track) != 2 {
		t.Fatalf("expected 2 tracks, got %d", len(x.TrackList.Track))
	}
	if x.TrackList.Track[0].Extension == nil || x.TrackList.Track[0].Extension.Provider != "deezer" {
		t.Error("track 0 should have deezer extension")
	}
	if len(x.TrackList.Track[1].Location) == 0 || x.TrackList.Track[1].Location[0] != "file:///music/song.flac" {
		t.Error("track 1 should have location")
	}
}

func TestExportXML(t *testing.T) {
	pl := New("XML Export", "Tester", []PlaylistTrack{
		{Title: "Song", Artist: "Artist", Album: "Album", Duration: 150000},
	})

	xmlStr, err := pl.ExportXML()
	if err != nil {
		t.Fatalf("ExportXML failed: %v", err)
	}
	if !strings.HasPrefix(xmlStr, "<?xml") {
		t.Error("expected XML header")
	}
	if !strings.Contains(xmlStr, "<title>XML Export</title>") {
		t.Error("expected playlist title in XML")
	}
}

func TestPlaylistRoundTrip(t *testing.T) {
	original := New("Round Trip", "Tester", []PlaylistTrack{
		{Title: "Song A", Artist: "Artist A", Album: "Album A", Duration: 100000, ISRC: "ISRC001"},
		{Title: "Song B", Artist: "Artist B", Duration: 200000},
	})

	// Playlist → XSPF → XSPFPlaylist → Playlist
	x := original.ToXSPF()
	xmlStr, _ := Marshal(x)
	parsedX, _ := Unmarshal(xmlStr)
	result := FromXSPF(parsedX)

	if result.Name != original.Name {
		t.Errorf("name: expected %s, got %s", original.Name, result.Name)
	}
	if result.TrackCount != original.TrackCount {
		t.Errorf("track count: expected %d, got %d", original.TrackCount, result.TrackCount)
	}
	if result.Tracks[0].Title != original.Tracks[0].Title {
		t.Errorf("track title: expected %s, got %s", original.Tracks[0].Title, result.Tracks[0].Title)
	}
}
