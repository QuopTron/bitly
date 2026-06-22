package playback

import (
	"encoding/json"
	"testing"
)

func track(id, name string, duration int) *PlaybackTrack {
	return &PlaybackTrack{ID: id, Name: name, Duration: duration}
}

func TestApplyAction_Play(t *testing.T) {
	ps := &PlaybackState{}
	trk := track("t1", "Song", 200000)

	applyAction(ps, PlaybackAction{Type: ActionPlay, Track: trk})

	if !ps.IsPlaying {
		t.Error("expected IsPlaying true")
	}
	if ps.CurrentTrack != trk {
		t.Error("expected CurrentTrack to be set")
	}
	if ps.Position != 0 {
		t.Errorf("expected Position 0, got %d", ps.Position)
	}
	if ps.Duration != 200000 {
		t.Errorf("expected Duration 200000, got %d", ps.Duration)
	}
}

func TestApplyAction_PlaySwitchesTrack(t *testing.T) {
	ps := &PlaybackState{}
	t1 := track("t1", "First", 1000)
	t2 := track("t2", "Second", 2000)

	applyAction(ps, PlaybackAction{Type: ActionPlay, Track: t1})
	applyAction(ps, PlaybackAction{Type: ActionPlay, Track: t2})

	if ps.CurrentTrack != t2 {
		t.Error("expected CurrentTrack to be the second track")
	}
	if len(ps.History) != 1 {
		t.Fatalf("expected 1 history entry, got %d", len(ps.History))
	}
	if ps.History[0].ID != "t1" {
		t.Errorf("history[0].ID = %q, want %q", ps.History[0].ID, "t1")
	}
}

func TestApplyAction_PlaySameTrackDoesNotDuplicateHistory(t *testing.T) {
	ps := &PlaybackState{}
	t1 := track("t1", "Same", 1000)

	applyAction(ps, PlaybackAction{Type: ActionPlay, Track: t1})
	applyAction(ps, PlaybackAction{Type: ActionPlay, Track: t1})

	if len(ps.History) != 1 {
		t.Errorf("expected 1 history entry (dedup), got %d", len(ps.History))
	}
}

func TestApplyAction_PlayNoTrack(t *testing.T) {
	ps := &PlaybackState{}
	applyAction(ps, PlaybackAction{Type: ActionPlay})

	if ps.IsPlaying {
		t.Error("expected IsPlaying false when no track")
	}
	if ps.CurrentTrack != nil {
		t.Error("expected CurrentTrack nil when no track")
	}
}

func TestApplyAction_Pause(t *testing.T) {
	ps := &PlaybackState{}
	ps.IsPlaying = true
	ps.CurrentTrack = track("t1", "Song", 1000)

	applyAction(ps, PlaybackAction{Type: ActionPause})

	if ps.IsPlaying {
		t.Error("expected IsPlaying false after pause")
	}
	if ps.CurrentTrack == nil {
		t.Error("expected CurrentTrack preserved after pause")
	}
}

func TestApplyAction_Resume(t *testing.T) {
	ps := &PlaybackState{}
	ps.CurrentTrack = track("t1", "Song", 1000)
	ps.IsPlaying = false

	applyAction(ps, PlaybackAction{Type: ActionResume})

	if !ps.IsPlaying {
		t.Error("expected IsPlaying true after resume")
	}
}

func TestApplyAction_ResumeNoTrack(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{Type: ActionResume})

	if ps.IsPlaying {
		t.Error("expected IsPlaying false when no CurrentTrack")
	}
}

func TestApplyAction_Stop(t *testing.T) {
	ps := &PlaybackState{}
	ps.IsPlaying = true
	ps.Position = 50000

	applyAction(ps, PlaybackAction{Type: ActionStop})

	if ps.IsPlaying {
		t.Error("expected IsPlaying false after stop")
	}
	if ps.Position != 0 {
		t.Errorf("expected Position 0 after stop, got %d", ps.Position)
	}
}

func TestApplyAction_Seek(t *testing.T) {
	ps := &PlaybackState{}
	ps.Duration = 100000

	applyAction(ps, PlaybackAction{Type: ActionSeek, Position: 50000})

	if ps.Position != 50000 {
		t.Errorf("expected Position 50000, got %d", ps.Position)
	}
}

func TestApplyAction_SeekNegative(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{Type: ActionSeek, Position: -1})

	if ps.Position != 0 {
		t.Errorf("expected Position 0 for negative seek, got %d", ps.Position)
	}
}

func TestApplyAction_SeekBeyondDuration(t *testing.T) {
	ps := &PlaybackState{}
	ps.Duration = 100000

	applyAction(ps, PlaybackAction{Type: ActionSeek, Position: 200000})

	if ps.Position != 0 {
		t.Errorf("expected Position 0 for seek beyond duration, got %d", ps.Position)
	}
}

func TestApplyAction_SeekNoDurationLimit(t *testing.T) {
	ps := &PlaybackState{}
	ps.Duration = 0

	applyAction(ps, PlaybackAction{Type: ActionSeek, Position: 50000})

	if ps.Position != 50000 {
		t.Errorf("expected Position 50000 when Duration=0, got %d", ps.Position)
	}
}

func TestApplyAction_SetShuffle(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetShuffle,
		Params: map[string]interface{}{"shuffle": true},
	})

	if !ps.Shuffle {
		t.Error("expected Shuffle true")
	}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetShuffle,
		Params: map[string]interface{}{"shuffle": false},
	})

	if ps.Shuffle {
		t.Error("expected Shuffle false")
	}
}

func TestApplyAction_SetShuffleIgnoredWithoutBool(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetShuffle,
		Params: map[string]interface{}{"shuffle": "notabool"},
	})

	if ps.Shuffle {
		t.Error("expected Shuffle unchanged for non-bool param")
	}
}

func TestApplyAction_SetRepeat(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetRepeat,
		Params: map[string]interface{}{"repeat_mode": "all"},
	})

	if ps.RepeatMode != "all" {
		t.Errorf("expected RepeatMode 'all', got %q", ps.RepeatMode)
	}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetRepeat,
		Params: map[string]interface{}{"repeat_mode": "one"},
	})

	if ps.RepeatMode != "one" {
		t.Errorf("expected RepeatMode 'one', got %q", ps.RepeatMode)
	}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetRepeat,
		Params: map[string]interface{}{"repeat_mode": "off"},
	})

	if ps.RepeatMode != "off" {
		t.Errorf("expected RepeatMode 'off', got %q", ps.RepeatMode)
	}
}

func TestApplyAction_SetRepeatIgnoredWithoutString(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{
		Type:   ActionSetRepeat,
		Params: map[string]interface{}{"repeat_mode": 42},
	})

	if ps.RepeatMode != "" {
		t.Errorf("expected empty RepeatMode, got %q", ps.RepeatMode)
	}
}

func TestApplyAction_NextNormal(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One", Duration: 1000},
		{ID: "t2", Name: "Two", Duration: 2000},
	}
	ps.QueueIndex = 0
	ps.CurrentTrack = &ps.Queue[0]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionNext})

	if ps.QueueIndex != 1 {
		t.Errorf("expected QueueIndex 1, got %d", ps.QueueIndex)
	}
	if ps.CurrentTrack == nil || ps.CurrentTrack.ID != "t2" {
		t.Errorf("expected CurrentTrack t2, got %v", ps.CurrentTrack)
	}
	if !ps.IsPlaying {
		t.Error("expected IsPlaying true after next")
	}
	if ps.Position != 0 {
		t.Errorf("expected Position 0, got %d", ps.Position)
	}
}

func TestApplyAction_NextEndOfQueue(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
	}
	ps.QueueIndex = 1
	ps.CurrentTrack = &ps.Queue[1]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionNext})

	if ps.CurrentTrack != nil {
		t.Error("expected CurrentTrack nil at end of queue")
	}
	if ps.IsPlaying {
		t.Error("expected IsPlaying false at end of queue")
	}
}

func TestApplyAction_NextEndOfQueueRepeatAll(t *testing.T) {
	ps := &PlaybackState{}
	ps.RepeatMode = "all"
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One", Duration: 1000},
		{ID: "t2", Name: "Two", Duration: 2000},
	}
	ps.QueueIndex = 1
	ps.CurrentTrack = &ps.Queue[1]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionNext})

	if ps.QueueIndex != 0 {
		t.Errorf("expected QueueIndex 0 (wrap), got %d", ps.QueueIndex)
	}
	if !ps.IsPlaying {
		t.Error("expected IsPlaying true with repeat all")
	}
}

func TestApplyAction_NextRepeatOne(t *testing.T) {
	ps := &PlaybackState{}
	ps.RepeatMode = "one"
	ps.CurrentTrack = track("t1", "Repeat", 1000)
	ps.Position = 50000
	ps.IsPlaying = true
	ps.Queue = []PlaybackTrack{{ID: "t1", Name: "Repeat", Duration: 1000}}

	applyAction(ps, PlaybackAction{Type: ActionNext})

	if ps.Position != 0 {
		t.Errorf("expected Position reset to 0, got %d", ps.Position)
	}
	if !ps.IsPlaying {
		t.Error("expected IsPlaying true with repeat one")
	}
}

func TestApplyAction_NextEmptyQueue(t *testing.T) {
	ps := &PlaybackState{}
	ps.CurrentTrack = track("t1", "Only", 1000)
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionNext})

	if ps.CurrentTrack != nil {
		t.Error("expected CurrentTrack nil with empty queue")
	}
	if ps.IsPlaying {
		t.Error("expected IsPlaying false with empty queue")
	}
	if len(ps.History) != 1 {
		t.Errorf("expected track moved to history, got %d entries", len(ps.History))
	}
}

func TestApplyAction_NextShuffle(t *testing.T) {
	ps := &PlaybackState{}
	ps.Shuffle = true
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
		{ID: "t3", Name: "Three"},
	}
	ps.QueueIndex = 0
	ps.CurrentTrack = &ps.Queue[0]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionNext})

	if ps.CurrentTrack == nil {
		t.Fatal("expected CurrentTrack non-nil with shuffle")
	}
	if ps.CurrentTrack.ID == ps.Queue[0].ID {
		t.Error("expected shuffle to pick a different track index")
	}
	if !ps.IsPlaying {
		t.Error("expected IsPlaying true with shuffle")
	}
	if ps.Position != 0 {
		t.Errorf("expected Position 0, got %d", ps.Position)
	}
}

func TestApplyAction_PreviousFromHistory(t *testing.T) {
	ps := &PlaybackState{}
	t1 := track("t1", "First", 1000)
	t2 := track("t2", "Second", 2000)
	ps.Queue = []PlaybackTrack{*t1, *t2}
	ps.QueueIndex = 1
	ps.CurrentTrack = t2
	ps.History = append(ps.History, *t1)

	applyAction(ps, PlaybackAction{Type: ActionPrevious})

	if ps.CurrentTrack == nil || ps.CurrentTrack.ID != "t1" {
		t.Errorf("expected CurrentTrack t1, got %v", ps.CurrentTrack)
	}
	if !ps.IsPlaying {
		t.Error("expected IsPlaying true after previous")
	}
	if len(ps.History) != 0 {
		t.Errorf("expected history popped, got %d entries", len(ps.History))
	}
}

func TestApplyAction_PreviousWithoutHistory(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One"},
		{ID: "t2", Name: "Two"},
	}
	ps.QueueIndex = 1
	ps.CurrentTrack = &ps.Queue[1]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionPrevious})

	if ps.QueueIndex != 0 {
		t.Errorf("expected QueueIndex 0, got %d", ps.QueueIndex)
	}
	if ps.CurrentTrack == nil || ps.CurrentTrack.ID != "t1" {
		t.Errorf("expected CurrentTrack t1, got %v", ps.CurrentTrack)
	}
}

func TestApplyAction_PreviousAtStartNoHistory(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One"},
	}
	ps.QueueIndex = 0
	ps.CurrentTrack = &ps.Queue[0]

	applyAction(ps, PlaybackAction{Type: ActionPrevious})

	if ps.CurrentTrack.ID != "t1" {
		t.Error("expected CurrentTrack unchanged at start without history")
	}
}

func TestApplyAction_PreviousRestoresCurrentToQueue(t *testing.T) {
	ps := &PlaybackState{}
	t1 := track("t1", "First", 1000)
	t2 := track("t2", "Second", 2000)
	t3 := track("t3", "Third", 3000)
	ps.Queue = []PlaybackTrack{*t1}
	ps.QueueIndex = 0
	ps.CurrentTrack = t3
	ps.History = append(ps.History, *t2, *t1)

	applyAction(ps, PlaybackAction{Type: ActionPrevious})
	// CurrentTrack t3 not in queue — should be inserted at QueueIndex
	found := false
	for _, tr := range ps.Queue {
		if tr.ID == "t3" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected previous CurrentTrack t3 re-inserted into queue")
	}
}

func TestApplyAction_TrackCompleted(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One", Duration: 1000},
		{ID: "t2", Name: "Two", Duration: 2000},
	}
	ps.QueueIndex = 0
	ps.CurrentTrack = &ps.Queue[0]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionTrackCompleted})

	if ps.QueueIndex != 1 {
		t.Errorf("expected QueueIndex 1, got %d", ps.QueueIndex)
	}
	if ps.CurrentTrack == nil || ps.CurrentTrack.ID != "t2" {
		t.Errorf("expected CurrentTrack t2, got %v", ps.CurrentTrack)
	}
	if len(ps.History) != 1 {
		t.Errorf("expected 1 history entry, got %d", len(ps.History))
	}
	if ps.History[0].ID != "t1" {
		t.Errorf("history[0].ID = %q, want %q", ps.History[0].ID, "t1")
	}
}

func TestApplyAction_TrackCompletedEndOfQueue(t *testing.T) {
	ps := &PlaybackState{}
	ps.Queue = []PlaybackTrack{
		{ID: "t1", Name: "One"},
	}
	ps.QueueIndex = 0
	ps.CurrentTrack = &ps.Queue[0]
	ps.IsPlaying = true

	applyAction(ps, PlaybackAction{Type: ActionTrackCompleted})

	if ps.CurrentTrack != nil {
		t.Error("expected CurrentTrack nil at end of queue")
	}
	if ps.IsPlaying {
		t.Error("expected IsPlaying false at end of queue")
	}
	if len(ps.History) != 1 {
		t.Errorf("expected 1 history entry, got %d", len(ps.History))
	}
}

func TestApplyAction_TrackCompletedRepeatOne(t *testing.T) {
	ps := &PlaybackState{}
	ps.RepeatMode = "one"
	ps.CurrentTrack = track("t1", "Repeat", 1000)
	ps.Position = 90000
	ps.IsPlaying = true
	ps.Queue = []PlaybackTrack{{ID: "t1", Name: "Repeat", Duration: 1000}}

	applyAction(ps, PlaybackAction{Type: ActionTrackCompleted})

	if ps.Position != 0 {
		t.Errorf("expected Position reset to 0, got %d", ps.Position)
	}
	if !ps.IsPlaying {
		t.Error("expected IsPlaying true with repeat one")
	}
}

func TestApplyAction_TrackCompletedNoCurrentTrack(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{Type: ActionTrackCompleted})
	// should not panic; nothing to advance
}

func TestApplyAction_TimestampUpdated(t *testing.T) {
	ps := &PlaybackState{}

	applyAction(ps, PlaybackAction{Type: ActionPause})

	if ps.Timestamp == 0 {
		t.Error("expected Timestamp to be set after action")
	}
}

func TestActionHelpers_PlayTrack(t *testing.T) {
	result := PlayTrack(`{"id":"t1","name":"Test","duration":1000}`)

	if result != `{"success":true,"action":"play"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_PlayTrackInvalidJSON(t *testing.T) {
	result := PlayTrack("{invalid}")

	if result == `{"success":true,"action":"play"}` {
		t.Error("expected error for invalid JSON")
	}
}

func TestActionHelpers_Pause(t *testing.T) {
	result := Pause()
	if result != `{"success":true,"action":"pause"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_Resume(t *testing.T) {
	result := Resume()
	if result != `{"success":true,"action":"resume"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_Stop(t *testing.T) {
	result := Stop()
	if result != `{"success":true,"action":"stop"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_Seek(t *testing.T) {
	result := Seek(50000)
	expected := `{"success":true,"action":"seek","position":50000}`
	if result != expected {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_Next(t *testing.T) {
	result := Next()
	if result != `{"success":true,"action":"next"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_Previous(t *testing.T) {
	result := Previous()
	if result != `{"success":true,"action":"previous"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_SetQueue(t *testing.T) {
	result := SetQueue(`[{"id":"t1","name":"A"},{"id":"t2","name":"B"}]`)
	if result != `{"success":true,"action":"set_queue","count":2}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_SetQueueInvalidJSON(t *testing.T) {
	result := SetQueue("{invalid}")
	if result == `{"success":true,"action":"set_queue"}` {
		t.Error("expected error for invalid JSON")
	}
}

func TestActionHelpers_AddToQueue(t *testing.T) {
	result := AddToQueue(`[{"id":"t1","name":"A"}]`)
	if result != `{"success":true,"action":"add_to_queue","count":1}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_AddToQueueInvalidJSON(t *testing.T) {
	result := AddToQueue("{invalid}")
	if result == `{"success":true,"action":"add_to_queue"}` {
		t.Error("expected error for invalid JSON")
	}
}

func TestActionHelpers_RemoveFromQueue(t *testing.T) {
	result := RemoveFromQueue(0)
	if result != `{"success":true,"action":"remove_from_queue"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_RemoveFromQueueNegativeIndex(t *testing.T) {
	result := RemoveFromQueue(-1)
	if result == `{"success":true,"action":"remove_from_queue"}` {
		t.Error("expected error for negative index")
	}
}

func TestActionHelpers_ClearQueue(t *testing.T) {
	result := ClearQueue()
	if result != `{"success":true,"action":"clear_queue"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_SetShuffle(t *testing.T) {
	result := SetShuffle(true)
	if result != `{"success":true,"action":"set_shuffle","shuffle":true}` {
		t.Errorf("unexpected result: %s", result)
	}

	result = SetShuffle(false)
	if result != `{"success":true,"action":"set_shuffle","shuffle":false}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_SetRepeat(t *testing.T) {
	result := SetRepeat("all")
	if result != `{"success":true,"action":"set_repeat","mode":"all"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestActionHelpers_TrackCompleted(t *testing.T) {
	result := TrackCompleted()
	if result != `{"success":true,"action":"track_completed"}` {
		t.Errorf("unexpected result: %s", result)
	}
}

func TestGetStateJSON(t *testing.T) {
	ps := Get()
	ps.Lock()
	ps.IsPlaying = true
	ps.CurrentTrack = &PlaybackTrack{ID: "t1", Name: "State Test"}
	ps.Unlock()

	result := GetStateJSON()

	var state PlaybackState
	if err := json.Unmarshal([]byte(result), &state); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}
}

func TestGetHistoryJSON(t *testing.T) {
	ps := Get()
	ps.Lock()
	ps.History = []PlaybackTrack{
		{ID: "t1", Name: "Old"},
		{ID: "t2", Name: "Newer"},
		{ID: "t3", Name: "Latest"},
	}
	ps.Unlock()

	result := GetHistoryJSON(2)

	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(result), &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed["total"] != float64(3) {
		t.Errorf("total = %v, want 3", parsed["total"])
	}
	if parsed["returned"] != float64(2) {
		t.Errorf("returned = %v, want 2", parsed["returned"])
	}
}

func TestGetHistoryJSONNegativeLimit(t *testing.T) {
	ps := Get()
	ps.Lock()
	ps.History = []PlaybackTrack{{ID: "t1"}}
	ps.Unlock()

	result := GetHistoryJSON(-1)

	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(result), &parsed); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if parsed["total"] != float64(1) {
		t.Errorf("total = %v, want 1", parsed["total"])
	}
}

func TestSetPosition(t *testing.T) {
	SetPosition(75000)

	ps := Get()
	ps.RLock()
	defer ps.RUnlock()

	if ps.Position != 75000 {
		t.Errorf("expected Position 75000, got %d", ps.Position)
	}
	if ps.Timestamp == 0 {
		t.Error("expected Timestamp set")
	}
}
