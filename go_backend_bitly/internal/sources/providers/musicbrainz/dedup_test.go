package musicbrainz

import (
	"sync"
	"testing"
	"time"
)

func TestDedup(t *testing.T) {
	c := GetClient()
	c.inflight = make(map[inFlightKey]chan inFlightResult)

	key := inFlightKey{isrc: "US123", queryType: "genre"}
	var mu sync.Mutex
	callCount := 0

	fn := func() (string, error) {
		mu.Lock()
		callCount++
		mu.Unlock()
		time.Sleep(50 * time.Millisecond)
		return "result", nil
	}

	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, err := c.dedup(key, fn)
			if err != nil {
				t.Error(err)
			}
			if r != "result" {
				t.Errorf("got %q", r)
			}
		}()
	}
	wg.Wait()

	mu.Lock()
	if callCount != 1 {
		t.Errorf("expected 1 call, got %d", callCount)
	}
	mu.Unlock()
}

func TestWaitForCooldown_NoCooldown(t *testing.T) {
	c := GetClient()
	c.mu.Lock()
	c.cooldown = time.Time{}
	c.mu.Unlock()
	c.waitForCooldown()
}

func TestFetchGenreByISRC_InvalidInput(t *testing.T) {
	c := GetClient()
	_, err := c.FetchGenreByISRC("")
	if err == nil {
		t.Fatal("expected error for empty ISRC")
	}
}

func TestFetchAlbumArtistByISRC_InvalidInput(t *testing.T) {
	c := GetClient()
	_, err := c.FetchAlbumArtistByISRC("", "Album")
	if err == nil {
		t.Fatal("expected error for empty ISRC")
	}
}

func TestConstants(t *testing.T) {
	if apiBase != "https://musicbrainz.org/ws/2" {
		t.Errorf("apiBase = %q", apiBase)
	}
}
