package playlist

import (
	"strings"
	"testing"
)

func TestMarshalUnmarshalRoundTrip(t *testing.T) {
	original := &XSPFPlaylist{
		Version:   "1",
		Namespace: NSXSPF,
		Title:     "Test Playlist",
		Creator:   "Tester",
		TrackList: TrackList{
			Track: []XSPFTrack{
				{
					Title:    "Song A",
					Creator:  "Artist A",
					Album:    "Album A",
					Duration: 200000,
					Identifier: "isrc:GBUM71029604",
				},
				{
					Title:    "Song B",
					Creator:  "Artist B",
					Album:    "Album B",
					Duration: 300000,
				},
			},
		},
	}

	xmlStr, err := Marshal(original)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	if !strings.HasPrefix(xmlStr, "<?xml") {
		t.Error("expected XML header")
	}
	if !strings.Contains(xmlStr, "<title>Test Playlist</title>") {
		t.Error("expected playlist title in XML")
	}
	if !strings.Contains(xmlStr, "<creator>Tester</creator>") {
		t.Error("expected creator in XML")
	}

	parsed, err := Unmarshal(xmlStr)
	if err != nil {
		t.Fatalf("Unmarshal failed: %v", err)
	}

	if parsed.Title != original.Title {
		t.Errorf("title: expected %s, got %s", original.Title, parsed.Title)
	}
	if parsed.Creator != original.Creator {
		t.Errorf("creator: expected %s, got %s", original.Creator, parsed.Creator)
	}
	if len(parsed.TrackList.Track) != 2 {
		t.Fatalf("expected 2 tracks, got %d", len(parsed.TrackList.Track))
	}
	if parsed.TrackList.Track[0].Title != "Song A" {
		t.Errorf("track 0 title: expected Song A, got %s", parsed.TrackList.Track[0].Title)
	}
	if parsed.TrackList.Track[1].Duration != 300000 {
		t.Errorf("track 1 duration: expected 300000, got %d", parsed.TrackList.Track[1].Duration)
	}
}

func TestMarshalEmptyTrackList(t *testing.T) {
	p := &XSPFPlaylist{
		Title:     "Empty",
		TrackList: TrackList{},
	}

	xmlStr, err := Marshal(p)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	if !strings.Contains(xmlStr, "<trackList></trackList>") &&
		!strings.Contains(xmlStr, "<trackList/>") {
		t.Error("expected empty trackList in XML")
	}
}

func TestMarshalDefaults(t *testing.T) {
	p := &XSPFPlaylist{
		Title: "No Version Set",
	}

	xmlStr, err := Marshal(p)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	if !strings.Contains(xmlStr, `version="1"`) {
		t.Error("expected default version='1'")
	}
	if !strings.Contains(xmlStr, NSXSPF) {
		t.Error("expected default namespace")
	}
}

func TestUnmarshalInvalidXML(t *testing.T) {
	_, err := Unmarshal("this is not xml")
	if err == nil {
		t.Error("expected error for invalid XML")
	}
}

func TestUnmarshalEmpty(t *testing.T) {
	_, err := Unmarshal("")
	if err == nil {
		t.Error("expected error for empty input")
	}
}

func TestMarshalTrackWithLocation(t *testing.T) {
	p := &XSPFPlaylist{
		Title: "Local Files",
		TrackList: TrackList{
			Track: []XSPFTrack{
				{
					Title:    "Local Song",
					Creator:  "Local Artist",
					Location: []string{"file:///music/song.flac"},
				},
			},
		},
	}

	xmlStr, err := Marshal(p)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	if !strings.Contains(xmlStr, "file:///music/song.flac") {
		t.Error("expected location in XML")
	}

	parsed, _ := Unmarshal(xmlStr)
	if len(parsed.TrackList.Track[0].Location) == 0 ||
		parsed.TrackList.Track[0].Location[0] != "file:///music/song.flac" {
		t.Error("expected location to survive round-trip")
	}
}

func TestMarshalTrackWithExtension(t *testing.T) {
	p := &XSPFPlaylist{
		Title: "With Extension",
		TrackList: TrackList{
			Track: []XSPFTrack{
				{
					Title:   "Track",
					Creator: "Artist",
					Extension: &Extension{
						Application: "bitly",
						Provider:    "deezer",
						TrackID:     "12345",
						ISRC:        "GBUM71029604",
					},
				},
			},
		},
	}

	xmlStr, err := Marshal(p)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	if !strings.Contains(xmlStr, `application="bitly"`) {
		t.Error("expected extension application='bitly'")
	}
	if !strings.Contains(xmlStr, "<provider>deezer</provider>") {
		t.Error("expected provider extension")
	}
	if !strings.Contains(xmlStr, "<trackId>12345</trackId>") {
		t.Error("expected trackId extension")
	}
}
