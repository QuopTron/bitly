package playback

import (
	"encoding/json"
	"testing"
)

func TestPlaybackTrack_AllFields(t *testing.T) {
	track := PlaybackTrack{
		ID:         "spotify:track:abc123",
		Name:       "Bohemian Rhapsody",
		ArtistName: "Queen",
		AlbumName:  "A Night at the Opera",
		CoverURL:   "https://example.com/cover.jpg",
		ISRC:       "GBAMB7500001",
		Duration:   354000,
		LocalPath:  "/music/queen/bohemian_rhapsody.mp3",
		Source:     "local",
		Service:    "spotify",
	}

	if track.ID != "spotify:track:abc123" {
		t.Errorf("ID = %q, want %q", track.ID, "spotify:track:abc123")
	}
	if track.Name != "Bohemian Rhapsody" {
		t.Errorf("Name = %q, want %q", track.Name, "Bohemian Rhapsody")
	}
	if track.ArtistName != "Queen" {
		t.Errorf("ArtistName = %q, want %q", track.ArtistName, "Queen")
	}
	if track.AlbumName != "A Night at the Opera" {
		t.Errorf("AlbumName = %q, want %q", track.AlbumName, "A Night at the Opera")
	}
	if track.CoverURL != "https://example.com/cover.jpg" {
		t.Errorf("CoverURL = %q, want %q", track.CoverURL, "https://example.com/cover.jpg")
	}
	if track.ISRC != "GBAMB7500001" {
		t.Errorf("ISRC = %q, want %q", track.ISRC, "GBAMB7500001")
	}
	if track.Duration != 354000 {
		t.Errorf("Duration = %d, want %d", track.Duration, 354000)
	}
	if track.LocalPath != "/music/queen/bohemian_rhapsody.mp3" {
		t.Errorf("LocalPath = %q, want %q", track.LocalPath, "/music/queen/bohemian_rhapsody.mp3")
	}
	if track.Source != "local" {
		t.Errorf("Source = %q, want %q", track.Source, "local")
	}
	if track.Service != "spotify" {
		t.Errorf("Service = %q, want %q", track.Service, "spotify")
	}
}

func TestPlaybackTrack_DefaultFields(t *testing.T) {
	track := PlaybackTrack{ID: "1", Name: "Minimal"}

	if track.ArtistName != "" {
		t.Errorf("expected empty ArtistName, got %q", track.ArtistName)
	}
	if track.AlbumName != "" {
		t.Errorf("expected empty AlbumName, got %q", track.AlbumName)
	}
}

func TestPlaybackTrack_JSONRoundTrip(t *testing.T) {
	original := PlaybackTrack{
		ID:         "t1",
		Name:       "Test",
		ArtistName: "Artist",
		Duration:   180000,
	}
	b, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var decoded PlaybackTrack
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if decoded.ID != original.ID {
		t.Errorf("ID = %q, want %q", decoded.ID, original.ID)
	}
	if decoded.Name != original.Name {
		t.Errorf("Name = %q, want %q", decoded.Name, original.Name)
	}
	if decoded.ArtistName != original.ArtistName {
		t.Errorf("ArtistName = %q, want %q", decoded.ArtistName, original.ArtistName)
	}
	if decoded.Duration != original.Duration {
		t.Errorf("Duration = %d, want %d", decoded.Duration, original.Duration)
	}
}

func TestPlaybackState_InitialZeroValues(t *testing.T) {
	ps := &PlaybackState{}

	if ps.IsPlaying != false {
		t.Error("expected IsPlaying to be false")
	}
	if ps.CurrentTrack != nil {
		t.Error("expected CurrentTrack to be nil")
	}
	if ps.Position != 0 {
		t.Errorf("expected Position 0, got %d", ps.Position)
	}
	if ps.Duration != 0 {
		t.Errorf("expected Duration 0, got %d", ps.Duration)
	}
	if ps.Volume != 0 {
		t.Errorf("expected Volume 0, got %f", ps.Volume)
	}
	if ps.Shuffle != false {
		t.Error("expected Shuffle to be false")
	}
	if ps.RepeatMode != "" {
		t.Errorf("expected empty RepeatMode, got %q", ps.RepeatMode)
	}
	if ps.Queue != nil {
		t.Error("expected Queue to be nil")
	}
	if ps.QueueIndex != 0 {
		t.Errorf("expected QueueIndex 0, got %d", ps.QueueIndex)
	}
	if ps.History != nil {
		t.Error("expected History to be nil")
	}
	if ps.Timestamp != 0 {
		t.Errorf("expected Timestamp 0, got %d", ps.Timestamp)
	}
}

func TestPlaybackState_MutexSerialization(t *testing.T) {
	ps := &PlaybackState{}

	ps.Lock()
	ps.IsPlaying = true
	ps.Unlock()

	ps.RLock()
	playing := ps.IsPlaying
	ps.RUnlock()

	if !playing {
		t.Error("expected IsPlaying to be true after lock/unlock")
	}
}

func TestPlaybackAction_WithTrack(t *testing.T) {
	track := &PlaybackTrack{ID: "t1", Name: "Test"}
	action := PlaybackAction{Type: ActionPlay, Track: track}

	if action.Type != ActionPlay {
		t.Errorf("Type = %q, want %q", action.Type, ActionPlay)
	}
	if action.Track != track {
		t.Error("Track pointer mismatch")
	}
	if action.Position != 0 {
		t.Errorf("expected Position 0, got %d", action.Position)
	}
	if action.Tracks != nil {
		t.Error("expected Tracks to be nil")
	}
	if action.Params != nil {
		t.Error("expected Params to be nil")
	}
}

func TestPlaybackAction_WithTracks(t *testing.T) {
	tracks := []PlaybackTrack{
		{ID: "t1", Name: "A"},
		{ID: "t2", Name: "B"},
	}
	action := PlaybackAction{Type: ActionSetQueue, Tracks: tracks}

	if action.Type != ActionSetQueue {
		t.Errorf("Type = %q, want %q", action.Type, ActionSetQueue)
	}
	if len(action.Tracks) != 2 {
		t.Errorf("expected 2 tracks, got %d", len(action.Tracks))
	}
}

func TestPlaybackAction_WithPosition(t *testing.T) {
	action := PlaybackAction{Type: ActionSeek, Position: 50000}

	if action.Type != ActionSeek {
		t.Errorf("Type = %q, want %q", action.Type, ActionSeek)
	}
	if action.Position != 50000 {
		t.Errorf("Position = %d, want %d", action.Position, 50000)
	}
}

func TestPlaybackAction_WithParams(t *testing.T) {
	action := PlaybackAction{
		Type:   ActionSetShuffle,
		Params: map[string]interface{}{"shuffle": true},
	}

	if action.Type != ActionSetShuffle {
		t.Errorf("Type = %q, want %q", action.Type, ActionSetShuffle)
	}
	shuffle, ok := action.Params["shuffle"].(bool)
	if !ok || !shuffle {
		t.Error("expected Params[shuffle] = true")
	}
}

func TestPlaybackAction_JSONRoundTrip(t *testing.T) {
	action := PlaybackAction{
		Type: ActionPlay,
		Track: &PlaybackTrack{
			ID: "t1", Name: "Song", ArtistName: "Artist", Duration: 200000,
		},
		Position: 0,
	}

	b, err := json.Marshal(action)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var decoded PlaybackAction
	if err := json.Unmarshal(b, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if decoded.Type != action.Type {
		t.Errorf("Type = %q, want %q", decoded.Type, action.Type)
	}
	if decoded.Track == nil {
		t.Fatal("Track is nil")
	}
	if decoded.Track.ID != action.Track.ID {
		t.Errorf("Track.ID = %q, want %q", decoded.Track.ID, action.Track.ID)
	}
}

func TestQueue_SetReplace(t *testing.T) {
	ps := &PlaybackState{}
	tracks := []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
		{ID: "t3", Name: "Three"},
	}

	applyAction(ps, PlaybackAction{Type: ActionSetQueue, Tracks: tracks})

	if len(ps.Queue) != 3 {
		t.Fatalf("expected 3 queued tracks, got %d", len(ps.Queue))
	}
	if ps.QueueIndex != 0 {
		t.Errorf("expected QueueIndex 0, got %d", ps.QueueIndex)
	}
	if ps.Queue[0].ID != "t1" {
		t.Errorf("Queue[0].ID = %q, want %q", ps.Queue[0].ID, "t1")
	}
}

func TestQueue_SetReplacePreservesIndex(t *testing.T) {
	ps := &PlaybackState{}
	initial := []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
		{ID: "t3", Name: "Three"},
	}
	ps.Queue = initial
	ps.QueueIndex = 1

	replacement := []PlaybackTrack{
		{ID: "t4", Name: "Four"},
		{ID: "t2", Name: "Two"},
		{ID: "t5", Name: "Five"},
	}
	applyAction(ps, PlaybackAction{Type: ActionSetQueue, Tracks: replacement})

	if ps.QueueIndex != 1 {
		t.Errorf("expected QueueIndex 1 (matched t2), got %d", ps.QueueIndex)
	}
}

func TestQueue_SetReplaceIndexNotFound(t *testing.T) {
	ps := &PlaybackState{}
	initial := []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
	}
	ps.Queue = initial
	ps.QueueIndex = 1

	replacement := []PlaybackTrack{
		{ID: "t3", Name: "Three"},
		{ID: "t4", Name: "Four"},
	}
	applyAction(ps, PlaybackAction{Type: ActionSetQueue, Tracks: replacement})

	if ps.QueueIndex != 0 {
		t.Errorf("expected QueueIndex 0 (fallback), got %d", ps.QueueIndex)
	}
}

func TestQueue_AddToQueue(t *testing.T) {
	ps := &PlaybackState{}
	applyAction(ps, PlaybackAction{Type: ActionAddToQueue, Tracks: []PlaybackTrack{
		{ID: "t1", Name: "One"},
	}})
	applyAction(ps, PlaybackAction{Type: ActionAddToQueue, Tracks: []PlaybackTrack{
		{ID: "t2", Name: "Two"},
	}})

	if len(ps.Queue) != 2 {
		t.Fatalf("expected 2 queued tracks, got %d", len(ps.Queue))
	}
	if ps.Queue[1].ID != "t2" {
		t.Errorf("Queue[1].ID = %q, want %q", ps.Queue[1].ID, "t2")
	}
}

func TestQueue_RemoveFromQueue(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
		{ID: "t3", Name: "Three"},
	}
	ps.QueueIndex = 2

	applyAction(ps, PlaybackAction{
		Type:   ActionRemoveFromQueue,
		Params: map[string]interface{}{"index": 1},
	})

	if len(ps.Queue) != 2 {
		t.Fatalf("expected 2 tracks after removal, got %d", len(ps.Queue))
	}
	if ps.Queue[0].ID != "t1" || ps.Queue[1].ID != "t3" {
		t.Error("unexpected queue order after removal")
	}
	if ps.QueueIndex != 1 {
		t.Errorf("expected QueueIndex 1 (adjusted), got %d", ps.QueueIndex)
	}
}

func TestQueue_RemoveFromQueueOutOfBounds(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{{ID: "t1"}}

	applyAction(ps, PlaybackAction{
		Type:   ActionRemoveFromQueue,
		Params: map[string]interface{}{"index": 5},
	})

	if len(ps.Queue) != 1 {
		t.Errorf("expected queue unchanged, got %d items", len(ps.Queue))
	}
}

func TestQueue_RemoveFromQueueNegativeIndex(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{{ID: "t1"}}

	applyAction(ps, PlaybackAction{
		Type:   ActionRemoveFromQueue,
		Params: map[string]interface{}{"index": -1},
	})

	if len(ps.Queue) != 1 {
		t.Error("expected queue unchanged with negative index")
	}
}

func TestQueue_RemoveFromQueueFloat64Index(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1"},
		{ID: "t2"},
	}

	applyAction(ps, PlaybackAction{
		Type:   ActionRemoveFromQueue,
		Params: map[string]interface{}{"index": float64(0)},
	})

	if len(ps.Queue) != 1 || ps.Queue[0].ID != "t2" {
		t.Error("expected float64 index to work as int")
	}
}

func TestQueue_ClearQueue(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{{ID: "t1"}, {ID: "t2"}}
	ps.QueueIndex = 0

	applyAction(ps, PlaybackAction{Type: ActionClearQueue})

	if len(ps.Queue) != 0 {
		t.Errorf("expected empty queue, got %d items", len(ps.Queue))
	}
	if ps.QueueIndex != -1 {
		t.Errorf("expected QueueIndex -1 after clear, got %d", ps.QueueIndex)
	}
}

func TestSyncQueueState(t *testing.T) {
	stateJSON := `{
		"tracks": [{"id":"t1","name":"A"},{"id":"t2","name":"B"}],
		"current_index": 1,
		"shuffle": true,
		"repeat_mode": "all"
	}`

	result := SyncQueueState(stateJSON)

	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(result), &resp); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if resp["success"] != true {
		t.Errorf("expected success=true, got %v", resp)
	}

	ps := Get()
	ps.RLock()
	defer ps.RUnlock()

	if len(ps.Queue) != 2 {
		t.Errorf("expected 2 tracks, got %d", len(ps.Queue))
	}
	if ps.QueueIndex != 1 {
		t.Errorf("expected QueueIndex 1, got %d", ps.QueueIndex)
	}
	if !ps.Shuffle {
		t.Error("expected Shuffle true")
	}
	if ps.RepeatMode != "all" {
		t.Errorf("expected RepeatMode 'all', got %q", ps.RepeatMode)
	}
}

func TestSyncQueueState_InvalidJSON(t *testing.T) {
	result := SyncQueueState("{invalid}")

	if result != `{"success":false,"error":"Invalid state data: invalid character 'i' looking for beginning of object key string"}` {
		t.Errorf("unexpected error response: %s", result)
	}
}

func TestTrackFromDownload(t *testing.T) {
	requestJSON := `{
		"spotifyId": "s123",
		"trackName": "Test Song",
		"artistName": "Test Artist",
		"albumName": "Test Album",
		"coverUrl": "http://example.com/cover.jpg",
		"isrc": "USABC1234567",
		"durationMs": 200000,
		"service": "spotify",
		"source": "download"
	}`

	track, err := TrackFromDownload(requestJSON)
	if err != nil {
		t.Fatalf("TrackFromDownload error: %v", err)
	}

	if track.ID != "s123" {
		t.Errorf("ID = %q, want %q", track.ID, "s123")
	}
	if track.Name != "Test Song" {
		t.Errorf("Name = %q, want %q", track.Name, "Test Song")
	}
	if track.ArtistName != "Test Artist" {
		t.Errorf("ArtistName = %q, want %q", track.ArtistName, "Test Artist")
	}
	if track.AlbumName != "Test Album" {
		t.Errorf("AlbumName = %q, want %q", track.AlbumName, "Test Album")
	}
	if track.CoverURL != "http://example.com/cover.jpg" {
		t.Errorf("CoverURL = %q, want %q", track.CoverURL, "http://example.com/cover.jpg")
	}
	if track.ISRC != "USABC1234567" {
		t.Errorf("ISRC = %q, want %q", track.ISRC, "USABC1234567")
	}
	if track.Duration != 200000 {
		t.Errorf("Duration = %d, want %d", track.Duration, 200000)
	}
	if track.Service != "spotify" {
		t.Errorf("Service = %q, want %q", track.Service, "spotify")
	}
	if track.Source != "download" {
		t.Errorf("Source = %q, want %q", track.Source, "download")
	}
}

func TestTrackFromDownload_InvalidJSON(t *testing.T) {
	_, err := TrackFromDownload("{invalid}")
	if err == nil {
		t.Fatal("expected error for invalid JSON, got nil")
	}
}

func TestConstantValues(t *testing.T) {
	tests := []struct {
		got  string
		want string
	}{
		{ActionPlay, "play"},
		{ActionPause, "pause"},
		{ActionResume, "resume"},
		{ActionStop, "stop"},
		{ActionSeek, "seek"},
		{ActionNext, "next"},
		{ActionPrevious, "previous"},
		{ActionSetQueue, "set_queue"},
		{ActionAddToQueue, "add_to_queue"},
		{ActionRemoveFromQueue, "remove_from_queue"},
		{ActionClearQueue, "clear_queue"},
		{ActionSetShuffle, "set_shuffle"},
		{ActionSetRepeat, "set_repeat"},
		{ActionTrackCompleted, "track_completed"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("constant = %q, want %q", tt.got, tt.want)
		}
	}
}

func TestGetQueueJSON(t *testing.T) {
	ps := Get()
	ps.Lock()
	ps.Queue = []PlaybackTrack{{ID: "t1", Name: "One"}, {ID: "t2", Name: "Two"}}
	ps.QueueIndex = 0
	ps.CurrentTrack = &ps.Queue[0]
	ps.Unlock()

	result := GetQueueJSON()

	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(result), &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed["queue_index"] != float64(0) {
		t.Errorf("queue_index = %v, want 0", parsed["queue_index"])
	}
}
