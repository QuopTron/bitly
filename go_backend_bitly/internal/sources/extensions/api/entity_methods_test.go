package api

import "testing"

func TestGetTrack(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.GetTrack(extID, "t1")
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result")
	}
	if r.ID != "t1" {
		t.Errorf("expected id t1, got %s", r.ID)
	}

	r, err = c.GetTrack(extID, "notfound")
	if err != nil {
		t.Fatal(err)
	}
	if r != nil {
		t.Error("expected nil result for notfound")
	}

	_, err = c.GetTrack("unknown", "t1")
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}

func TestGetAlbum(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.GetAlbum(extID, "a1")
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result")
	}
	if r.ID != "a1" {
		t.Errorf("expected id a1, got %s", r.ID)
	}

	r, err = c.GetAlbum(extID, "notfound")
	if err != nil {
		t.Fatal(err)
	}
	if r != nil {
		t.Error("expected nil result for notfound")
	}

	_, err = c.GetAlbum("unknown", "a1")
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}

func TestGetArtist(t *testing.T) {
	c, extID := setupTestClient(t)
	r, err := c.GetArtist(extID, "ar1")
	if err != nil {
		t.Fatal(err)
	}
	if r == nil {
		t.Fatal("expected non-nil result")
	}
	if r.ID != "ar1" {
		t.Errorf("expected id ar1, got %s", r.ID)
	}

	r, err = c.GetArtist(extID, "notfound")
	if err != nil {
		t.Fatal(err)
	}
	if r != nil {
		t.Error("expected nil result for notfound")
	}

	_, err = c.GetArtist("unknown", "ar1")
	if err == nil {
		t.Error("expected error for unknown extension")
	}
}
