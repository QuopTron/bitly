package api

import "testing"

func TestSearchTracks(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.SearchTracks(extID, "test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(r) != 1 {
		t.Fatalf("expected 1 result, got %d", len(r))
	}
	if r[0].Name != "Test" {
		t.Errorf("unexpected name: %s", r[0].Name)
	}

	r, err = c.SearchTracks(extID, "wrapper", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(r) != 1 {
		t.Fatalf("expected 1 result from wrapper, got %d", len(r))
	}
	if r[0].Name != "WT" {
		t.Errorf("unexpected name: %s", r[0].Name)
	}

	r, err = c.SearchTracks(extID, "none", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(r) != 0 {
		t.Error("expected 0 results for empty query")
	}

	r, err = c.SearchTracks(extID, "err", 5)
	if err != nil {
		t.Fatal(err)
	}
	if r != nil {
		t.Error("expected nil for null return")
	}

	_, err = c.SearchTracks("unknown", "test", 5)
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}
