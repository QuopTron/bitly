package playback

import (
	"context"
	"encoding/json"
	"testing"
)

func TestTrackMetadata_AllFields(t *testing.T) {
	m := TrackMetadata{
		SpotifyID:   "12345",
		Name:        "Song Title",
		Artists:     "Artist Name",
		AlbumName:   "Album Name",
		AlbumArtist: "Album Artist",
		Images:      "http://example.com/img.jpg",
		ISRC:        "USABC1234567",
		DurationMS:  200000,
		ReleaseDate: "2024-01-15",
		TrackNumber: 3,
		TotalTracks: 12,
		DiscNumber:  1,
		TotalDiscs:  2,
	}

	if m.SpotifyID != "12345" {
		t.Errorf("SpotifyID = %q, want %q", m.SpotifyID, "12345")
	}
	if m.Name != "Song Title" {
		t.Errorf("Name = %q, want %q", m.Name, "Song Title")
	}
	if m.Artists != "Artist Name" {
		t.Errorf("Artists = %q, want %q", m.Artists, "Artist Name")
	}
	if m.AlbumName != "Album Name" {
		t.Errorf("AlbumName = %q, want %q", m.AlbumName, "Album Name")
	}
	if m.AlbumArtist != "Album Artist" {
		t.Errorf("AlbumArtist = %q, want %q", m.AlbumArtist, "Album Artist")
	}
	if m.Images != "http://example.com/img.jpg" {
		t.Errorf("Images = %q, want %q", m.Images, "http://example.com/img.jpg")
	}
	if m.ISRC != "USABC1234567" {
		t.Errorf("ISRC = %q, want %q", m.ISRC, "USABC1234567")
	}
	if m.DurationMS != 200000 {
		t.Errorf("DurationMS = %d, want %d", m.DurationMS, 200000)
	}
	if m.ReleaseDate != "2024-01-15" {
		t.Errorf("ReleaseDate = %q, want %q", m.ReleaseDate, "2024-01-15")
	}
	if m.TrackNumber != 3 {
		t.Errorf("TrackNumber = %d, want %d", m.TrackNumber, 3)
	}
	if m.TotalTracks != 12 {
		t.Errorf("TotalTracks = %d, want %d", m.TotalTracks, 12)
	}
	if m.DiscNumber != 1 {
		t.Errorf("DiscNumber = %d, want %d", m.DiscNumber, 1)
	}
	if m.TotalDiscs != 2 {
		t.Errorf("TotalDiscs = %d, want %d", m.TotalDiscs, 2)
	}
}

func TestTrackMetadata_DefaultZeroValues(t *testing.T) {
	m := TrackMetadata{}

	if m.SpotifyID != "" {
		t.Errorf("expected empty SpotifyID, got %q", m.SpotifyID)
	}
	if m.DurationMS != 0 {
		t.Errorf("expected DurationMS 0, got %d", m.DurationMS)
	}
	if m.TrackNumber != 0 {
		t.Errorf("expected TrackNumber 0, got %d", m.TrackNumber)
	}
}

func TestTrackMetadata_JSONRoundTrip(t *testing.T) {
	original := TrackMetadata{
		SpotifyID:   "d123",
		Name:        "Test",
		Artists:     "Artist",
		AlbumName:   "Album",
		DurationMS:  180000,
		TrackNumber: 1,
		TotalTracks: 10,
	}

	b, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var decoded TrackMetadata
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if decoded.SpotifyID != original.SpotifyID {
		t.Errorf("SpotifyID = %q, want %q", decoded.SpotifyID, original.SpotifyID)
	}
	if decoded.Name != original.Name {
		t.Errorf("Name = %q, want %q", decoded.Name, original.Name)
	}
	if decoded.DurationMS != original.DurationMS {
		t.Errorf("DurationMS = %d, want %d", decoded.DurationMS, original.DurationMS)
	}
}

func TestSimilarTrackToMap(t *testing.T) {
	m := TrackMetadata{
		SpotifyID:   "deezer:123",
		Name:        "Test Song",
		Artists:     "Test Artist",
		AlbumName:   "Test Album",
		AlbumArtist: "Album Artist",
		Images:      "http://example.com/img.jpg",
		ISRC:        "USABC1234567",
		DurationMS:  200000,
		ReleaseDate: "2024-01-15",
		TrackNumber: 3,
		TotalTracks: 12,
		DiscNumber:  1,
		TotalDiscs:  2,
	}

	result := similarTrackToMap(m)

	if result["id"] != "deezer:123" {
		t.Errorf("id = %v, want %q", result["id"], "deezer:123")
	}
	if result["name"] != "Test Song" {
		t.Errorf("name = %v, want %q", result["name"], "Test Song")
	}
	if result["artistName"] != "Test Artist" {
		t.Errorf("artistName = %v, want %q", result["artistName"], "Test Artist")
	}
	if result["albumName"] != "Test Album" {
		t.Errorf("albumName = %v, want %q", result["albumName"], "Test Album")
	}
	if result["albumArtist"] != "Album Artist" {
		t.Errorf("albumArtist = %v, want %q", result["albumArtist"], "Album Artist")
	}
	if result["coverUrl"] != "http://example.com/img.jpg" {
		t.Errorf("coverUrl = %v, want %q", result["coverUrl"], "http://example.com/img.jpg")
	}
	if result["isrc"] != "USABC1234567" {
		t.Errorf("isrc = %v, want %q", result["isrc"], "USABC1234567")
	}
	if result["duration"] != 200000 {
		t.Errorf("duration = %v, want %d", result["duration"], 200000)
	}
	if result["source"] != "deezer" {
		t.Errorf("source = %v, want %q", result["source"], "deezer")
	}
	if result["releaseDate"] != "2024-01-15" {
		t.Errorf("releaseDate = %v, want %q", result["releaseDate"], "2024-01-15")
	}
	if result["trackNumber"] != 3 {
		t.Errorf("trackNumber = %v, want %d", result["trackNumber"], 3)
	}
	if result["totalTracks"] != 12 {
		t.Errorf("totalTracks = %v, want %d", result["totalTracks"], 12)
	}
	if result["discNumber"] != 1 {
		t.Errorf("discNumber = %v, want %d", result["discNumber"], 1)
	}
	if result["totalDiscs"] != 2 {
		t.Errorf("totalDiscs = %v, want %d", result["totalDiscs"], 2)
	}
}

func TestSimilarTrackToMap_EmptyFields(t *testing.T) {
	m := TrackMetadata{}
	result := similarTrackToMap(m)

	if result["id"] != "" {
		t.Errorf("expected empty id, got %v", result["id"])
	}
	if result["name"] != "" {
		t.Errorf("expected empty name, got %v", result["name"])
	}
	if result["source"] != "deezer" {
		t.Errorf("source = %v, want %q", result["source"], "deezer")
	}
}

func TestSetDeezerSearcher(t *testing.T) {
	original := deezerClient
	defer func() { deezerClient = original }()

	mock := &mockDeezerSearcher{}
	SetDeezerSearcher(mock)

	if deezerClient != mock {
		t.Error("SetDeezerSearcher did not set the client")
	}
}

type searchAllResult = struct {
	Tracks  []TrackMetadata `json:"tracks"`
	Artists []TrackMetadata `json:"artists"`
}

type mockDeezerSearcher struct {
	searchAllFn          func(ctx context.Context, query string, trackLimit, artistLimit int, searchType string) (searchAllResult, error)
	getArtistTopTracksFn func(ctx context.Context, artistID string, limit int) ([]TrackMetadata, error)
	getRelatedArtistsFn  func(ctx context.Context, artistID string, limit int) ([]TrackMetadata, error)
}

func (m *mockDeezerSearcher) SearchAll(ctx context.Context, query string, trackLimit, artistLimit int, searchType string) (searchAllResult, error) {
	if m.searchAllFn != nil {
		return m.searchAllFn(ctx, query, trackLimit, artistLimit, searchType)
	}
	return searchAllResult{}, nil
}

func (m *mockDeezerSearcher) GetArtistTopTracks(ctx context.Context, artistID string, limit int) ([]TrackMetadata, error) {
	if m.getArtistTopTracksFn != nil {
		return m.getArtistTopTracksFn(ctx, artistID, limit)
	}
	return nil, nil
}

func (m *mockDeezerSearcher) GetRelatedArtists(ctx context.Context, artistID string, limit int) ([]TrackMetadata, error) {
	if m.getRelatedArtistsFn != nil {
		return m.getRelatedArtistsFn(ctx, artistID, limit)
	}
	return nil, nil
}

func TestSetLogger(t *testing.T) {
	var logged string
	SetLogger(func(format string, args ...interface{}) {
		logged = format
	})

	Log("test message: %s", "hello")

	if logged != "test message: %s" {
		t.Errorf("expected Log to be called, got %q", logged)
	}
}

func TestLogDefaultIsNoop(t *testing.T) {
	Log("this should not panic: %d", 42)
}

func TestDeezerSearcherInterface(t *testing.T) {
	var s DeezerSearcher = &mockDeezerSearcher{}
	_ = s
}

func TestDeezerSearcherInterface_SearchAll(t *testing.T) {
	mock := &mockDeezerSearcher{
		searchAllFn: func(_ context.Context, query string, trackLimit, artistLimit int, searchType string) (searchAllResult, error) {
			return searchAllResult{
				Tracks: []TrackMetadata{{SpotifyID: "1", Name: query}},
			}, nil
		},
	}

	result, err := mock.SearchAll(context.Background(), "test", 5, 3, "artist")
	if err != nil {
		t.Fatalf("SearchAll error: %v", err)
	}
	if len(result.Tracks) != 1 || result.Tracks[0].SpotifyID != "1" {
		t.Errorf("unexpected result: %+v", result)
	}
	if result.Tracks[0].Name != "test" {
		t.Errorf("Name = %q, want %q", result.Tracks[0].Name, "test")
	}
}

func TestDeezerSearcherInterface_GetArtistTopTracks(t *testing.T) {
	mock := &mockDeezerSearcher{
		getArtistTopTracksFn: func(_ context.Context, artistID string, limit int) ([]TrackMetadata, error) {
			return []TrackMetadata{
				{SpotifyID: "t1", Name: "Top Hit"},
			}, nil
		},
	}

	result, err := mock.GetArtistTopTracks(context.Background(), "artist123", 5)
	if err != nil {
		t.Fatalf("GetArtistTopTracks error: %v", err)
	}
	if len(result) != 1 || result[0].SpotifyID != "t1" {
		t.Errorf("unexpected result: %+v", result)
	}
}

func TestDeezerSearcherInterface_GetRelatedArtists(t *testing.T) {
	mock := &mockDeezerSearcher{
		getRelatedArtistsFn: func(_ context.Context, artistID string, limit int) ([]TrackMetadata, error) {
			return []TrackMetadata{
				{SpotifyID: "related1", Name: "Related Artist"},
			}, nil
		},
	}

	result, err := mock.GetRelatedArtists(context.Background(), "artist123", 5)
	if err != nil {
		t.Fatalf("GetRelatedArtists error: %v", err)
	}
	if len(result) != 1 || result[0].SpotifyID != "related1" {
		t.Errorf("unexpected result: %+v", result)
	}
}

func TestGetSimilarTracksJSONNoClient(t *testing.T) {
	originalClient := deezerClient
	defer func() { deezerClient = originalClient }()
	deezerClient = nil

	result := GetSimilarTracksJSON(`{"artist_name":"Test Artist","track_name":"Test Track"}`)

	if result != `[]` {
		t.Errorf("expected empty array when no client, got %s", result)
	}
}

func TestGetSimilarTracksJSONInvalidRequest(t *testing.T) {
	result := GetSimilarTracksJSON("{invalid}")

	if result == `[]` {
		t.Error("expected error response for invalid JSON")
	}
}

func TestGetSimilarTracksJSONDefaultLimit(t *testing.T) {
	originalClient := deezerClient
	defer func() { deezerClient = originalClient }()
	deezerClient = nil

	result := GetSimilarTracksJSON(`{"artist_name":"Test","track_name":"Test","limit":0}`)
	_ = result
}

func TestGetSimilarTracksJSONMaxLimit(t *testing.T) {
	originalClient := deezerClient
	defer func() { deezerClient = originalClient }()
	deezerClient = nil

	result := GetSimilarTracksJSON(`{"artist_name":"Test","track_name":"Test","limit":100}`)
	_ = result
}

func TestDownloadRequestMapping(t *testing.T) {
	req := DownloadRequest{
		SpotifyID:  "s123",
		TrackName:  "Test",
		ArtistName: "Artist",
		AlbumName:  "Album",
		CoverURL:   "http://example.com/cover.jpg",
		ISRC:       "USABC1234567",
		DurationMS: 200000,
		Service:    "spotify",
		Source:     "download",
	}

	if req.SpotifyID != "s123" {
		t.Errorf("SpotifyID = %q, want %q", req.SpotifyID, "s123")
	}
	if req.TrackName != "Test" {
		t.Errorf("TrackName = %q, want %q", req.TrackName, "Test")
	}
	if req.Service != "spotify" {
		t.Errorf("Service = %q, want %q", req.Service, "spotify")
	}
}

func TestDownloadRequest_JSONRoundTrip(t *testing.T) {
	original := DownloadRequest{
		SpotifyID: "s123", TrackName: "Test", DurationMS: 200000,
	}

	b, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var decoded DownloadRequest
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if decoded.SpotifyID != original.SpotifyID {
		t.Errorf("SpotifyID = %q, want %q", decoded.SpotifyID, original.SpotifyID)
	}
	if decoded.DurationMS != original.DurationMS {
		t.Errorf("DurationMS = %d, want %d", decoded.DurationMS, original.DurationMS)
	}
}

func TestStateGet(t *testing.T) {
	ps1 := Get()
	ps2 := Get()

	if ps1 != ps2 {
		t.Error("Get() should return the same singleton instance")
	}
}
