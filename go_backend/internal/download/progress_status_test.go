package download

import (
	"encoding/json"
	"testing"
)

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
