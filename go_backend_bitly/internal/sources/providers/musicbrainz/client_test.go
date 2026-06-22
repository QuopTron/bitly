package musicbrainz

import "testing"

func TestGetClient(t *testing.T) {
	c := GetClient()
	if c == nil {
		t.Fatal("expected non-nil Client")
	}
	if c.rl == nil {
		t.Error("expected non-nil rate limiter")
	}
}

func TestGetClient_Singleton(t *testing.T) {
	c1 := GetClient()
	c2 := GetClient()
	if c1 != c2 {
		t.Error("GetClient should return the same instance")
	}
}
