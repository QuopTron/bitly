package download

import (
	"encoding/json"
	"testing"
)

func TestTrackerAddGet(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Song A", "deezer")

	p := tr.Get("track_1")
	if p == nil {
		t.Fatal("expected progress entry")
	}
	if p.ItemID != "track_1" {
		t.Errorf("expected track_1, got %s", p.ItemID)
	}
	if p.Title != "Song A" {
		t.Errorf("expected Song A, got %s", p.Title)
	}
	if p.Provider != "deezer" {
		t.Errorf("expected deezer, got %s", p.Provider)
	}
	if p.Status != StatusQueued {
		t.Errorf("expected queued status, got %v", p.Status)
	}
}

func TestTrackerGetMissing(t *testing.T) {
	tr := NewTracker()
	p := tr.Get("nonexistent")
	if p != nil {
		t.Error("expected nil for missing entry")
	}
}

func TestTrackerRemove(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Song", "deezer")
	tr.Remove("track_1")

	if tr.Get("track_1") != nil {
		t.Error("expected nil after remove")
	}
}

func TestTrackerGetAll(t *testing.T) {
	tr := NewTracker()
	tr.Add("1", "A", "deezer")
	tr.Add("2", "B", "qobuz")

	all := tr.GetAll()
	if len(all) != 2 {
		t.Errorf("expected 2 entries, got %d", len(all))
	}
}

func TestTrackerGetAllEmpty(t *testing.T) {
	tr := NewTracker()
	all := tr.GetAll()
	if len(all) != 0 {
		t.Errorf("expected 0 entries, got %d", len(all))
	}
}

func TestTrackerUpdate(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Song", "deezer")
	tr.Update("track_1", StatusDownloading, 0.5)

	p := tr.Get("track_1")
	if p.Status != StatusDownloading {
		t.Errorf("expected downloading, got %v", p.Status)
	}
	if p.Progress != 0.5 {
		t.Errorf("expected 0.5 progress, got %f", p.Progress)
	}
}

func TestTrackerSetError(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Song", "deezer")
	tr.SetError("track_1", "connection failed")

	p := tr.Get("track_1")
	if p.Status != StatusFailed {
		t.Errorf("expected failed, got %v", p.Status)
	}
	if p.Error != "connection failed" {
		t.Errorf("expected error message, got %s", p.Error)
	}
}

func TestTrackerSetOutputPath(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Song", "deezer")
	tr.SetOutputPath("track_1", "/music/song.flac")

	p := tr.Get("track_1")
	if p.Status != StatusCompleted {
		t.Errorf("expected completed, got %v", p.Status)
	}
	if p.OutputPath != "/music/song.flac" {
		t.Errorf("expected /music/song.flac, got %s", p.OutputPath)
	}
	if p.Progress != 1.0 {
		t.Errorf("expected 1.0 progress, got %f", p.Progress)
	}
}

func TestTrackerSetEncryptedOutput(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Song", "amazon")
	tr.SetEncryptedOutput("track_1", "/music/song.flac", "deadbeef", ".flac", "mov")

	p := tr.Get("track_1")
	if p.Status != StatusCompleted {
		t.Errorf("expected completed, got %v", p.Status)
	}
	if p.Progress != 1.0 {
		t.Errorf("expected 1.0 progress, got %f", p.Progress)
	}
	if !p.Encrypted || !p.ClientDecrypt {
		t.Errorf("expected encrypted + clientDecrypt flags")
	}
	if p.DecryptionKey != "deadbeef" || p.OutputExtension != ".flac" {
		t.Errorf("decryption info not stored: %+v", p)
	}
	if p.OutputPath != "/music/song.flac" {
		t.Errorf("expected /music/song.flac, got %s", p.OutputPath)
	}
}

func TestStatusStrings(t *testing.T) {
	tests := []struct {
		status Status
		str    string
	}{
		{StatusQueued, "queued"},
		{StatusDownloading, "downloading"},
		{StatusProcessing, "processing"},
		{StatusCompleted, "completed"},
		{StatusFailed, "failed"},
		{StatusCancelled, "cancelled"},
	}

	for _, tt := range tests {
		if tt.status.String() != tt.str {
			t.Errorf("expected %s, got %s", tt.str, tt.status.String())
		}
	}
}

// TestStatusMarshalJSON verifies the progress status serializes as its string
// form (the Flutter DownloadCubit polling contract), NOT the raw int enum.
func TestStatusMarshalJSON(t *testing.T) {
	tr := NewTracker()
	tr.Add("track_1", "Tu Boda", "deezer")
	tr.Update("track_1", StatusCompleted, 1.0)
	tr.SetOutputPath("track_1", "/music/song.flac")
	p := tr.Get("track_1")
	data, err := json.Marshal(p)
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}
	var m map[string]interface{}
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}
	if got, ok := m["status"]; !ok {
		t.Fatal("status field missing")
	} else if got != "completed" {
		t.Errorf("expected status \"completed\", got %v (%T)", got, got)
	}
}
