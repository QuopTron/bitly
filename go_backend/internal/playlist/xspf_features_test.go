package playlist

import (
	"strings"
	"testing"
)

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
