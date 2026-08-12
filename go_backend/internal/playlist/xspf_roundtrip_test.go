package playlist

import (
	"strings"
	"testing"
)

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
