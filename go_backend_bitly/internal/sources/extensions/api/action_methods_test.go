package api

import "testing"

func TestCheckAvailability(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.CheckAvailability(extID, "valid", "track", "artist", nil)
	if err != nil {
		t.Fatal(err)
	}
	if !r.Available {
		t.Error("expected available")
	}
	if r.TrackID != "t1" {
		t.Errorf("expected track_id t1, got %s", r.TrackID)
	}

	r, err = c.CheckAvailability(extID, "invalid", "track", "artist", nil)
	if err != nil {
		t.Fatal(err)
	}
	if r.Available {
		t.Error("expected unavailable")
	}

	extra := map[string]string{"upc": "123"}
	r, err = c.CheckAvailability(extID, "valid", "track", "artist", extra)
	if err != nil {
		t.Fatal(err)
	}
	if !r.Available {
		t.Error("expected available with extra IDs")
	}

	_, err = c.CheckAvailability("unknown", "isrc", "t", "a", nil)
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}

func TestGetDownloadURL(t *testing.T) {
	c, extID := setupTestClient(t)
	url, err := c.GetDownloadURL(extID, "t1", "high")
	if err != nil {
		t.Fatal(err)
	}
	if url != "https://dl.example.com/t1" {
		t.Errorf("unexpected url: %s", url)
	}

	_, err = c.GetDownloadURL(extID, "fail", "high")
	if err == nil {
		t.Error("expected error for null return")
	}

	_, err = c.GetDownloadURL("unknown", "t1", "high")
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}

func TestDownload(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.Download(extID, "t1", "high", "/tmp")
	if err != nil {
		t.Fatal(err)
	}
	if !r.Success {
		t.Error("expected success")
	}
	if r.FilePath != "/tmp/test.mp3" {
		t.Errorf("unexpected path: %s", r.FilePath)
	}

	r, err = c.Download(extID, "fail", "high", "/tmp")
	if err != nil {
		t.Fatal(err)
	}
	if r.Success {
		t.Error("expected failure")
	}
	if r.Error != "failed" {
		t.Errorf("unexpected error: %s", r.Error)
	}

	r, err = c.Download("unknown", "t1", "high", "/tmp")
	if err != nil {
		t.Fatal(err)
	}
	if r.Success {
		t.Error("expected failure for unknown extension")
	}
	if r.Error == "" {
		t.Error("expected error message for unknown extension")
	}
}
