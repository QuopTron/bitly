package httpclient

import (
	"sync"
	"testing"
	"time"
)

func TestNewRateLimiter(t *testing.T) {
	rl := NewRateLimiter(5, time.Second)
	if rl == nil {
		t.Fatal("NewRateLimiter returned nil")
	}
	if rl.maxRequests != 5 {
		t.Errorf("expected maxRequests 5, got %d", rl.maxRequests)
	}
	if rl.window != time.Second {
		t.Errorf("expected window 1s, got %v", rl.window)
	}
	if cap(rl.timestamps) != 5 {
		t.Errorf("expected timestamps cap 5, got %d", cap(rl.timestamps))
	}
}

func TestNewRateLimiter_ZeroMaxRequests(t *testing.T) {
	rl := NewRateLimiter(0, time.Second)
	if rl == nil {
		t.Fatal("NewRateLimiter returned nil")
	}
}

func TestRateLimiter_TryAcquire_UnderLimit(t *testing.T) {
	rl := NewRateLimiter(3, time.Minute)
	for i := 0; i < 3; i++ {
		if !rl.TryAcquire() {
			t.Errorf("TryAcquire attempt %d should return true (under limit)", i)
		}
	}
}

func TestRateLimiter_TryAcquire_ExactLimit(t *testing.T) {
	rl := NewRateLimiter(1, time.Minute)
	if !rl.TryAcquire() {
		t.Error("TryAcquire should return true for the only slot")
	}
	if rl.TryAcquire() {
		t.Error("TryAcquire should return false when at limit")
	}
}

func TestRateLimiter_TryAcquire_OverLimit(t *testing.T) {
	rl := NewRateLimiter(2, time.Minute)
	rl.TryAcquire()
	rl.TryAcquire()
	if rl.TryAcquire() {
		t.Error("TryAcquire should return false when over limit")
	}
}

func TestRateLimiter_Available_Initially(t *testing.T) {
	rl := NewRateLimiter(10, time.Minute)
	if n := rl.Available(); n != 10 {
		t.Errorf("expected 10 available, got %d", n)
	}
}

func TestRateLimiter_Available_AfterAcquire(t *testing.T) {
	rl := NewRateLimiter(5, time.Minute)
	rl.TryAcquire()
	rl.TryAcquire()
	if n := rl.Available(); n != 3 {
		t.Errorf("expected 3 available, got %d", n)
	}
}

func TestRateLimiter_Available_AtLimit(t *testing.T) {
	rl := NewRateLimiter(3, time.Minute)
	rl.TryAcquire()
	rl.TryAcquire()
	rl.TryAcquire()
	if n := rl.Available(); n != 0 {
		t.Errorf("expected 0 available, got %d", n)
	}
}

func TestRateLimiter_TimestampsCleanup(t *testing.T) {
	rl := NewRateLimiter(3, 50*time.Millisecond)
	rl.TryAcquire()
	rl.TryAcquire()
	rl.TryAcquire()
	if rl.TryAcquire() {
		t.Error("should be rate limited before window expires")
	}

	time.Sleep(80 * time.Millisecond)

	if !rl.TryAcquire() {
		t.Error("should have available slot after window passes")
	}
}

func TestRateLimiter_Available_AfterWindowPasses(t *testing.T) {
	rl := NewRateLimiter(2, 50*time.Millisecond)
	rl.TryAcquire()
	rl.TryAcquire()
	if n := rl.Available(); n != 0 {
		t.Errorf("expected 0 available before expiry, got %d", n)
	}

	time.Sleep(80 * time.Millisecond)

	if n := rl.Available(); n != 2 {
		t.Errorf("expected 2 available after expiry, got %d", n)
	}
}

func TestRateLimiter_WaitForSlot_NoBlocking(t *testing.T) {
	rl := NewRateLimiter(5, time.Minute)
	start := time.Now()
	rl.WaitForSlot()
	elapsed := time.Since(start)
	if elapsed > 50*time.Millisecond {
		t.Errorf("WaitForSlot should return immediately when under limit, took %v", elapsed)
	}
}

func TestRateLimiter_WaitForSlot_BlocksWhenFull(t *testing.T) {
	rl := NewRateLimiter(1, 100*time.Millisecond)
	rl.WaitForSlot()

	start := time.Now()
	rl.WaitForSlot()
	elapsed := time.Since(start)

	if elapsed < 80*time.Millisecond {
		t.Errorf("WaitForSlot should block until window passes, got %v", elapsed)
	}
}

func TestRateLimiter_WaitForSlot_Concurrent(t *testing.T) {
	rl := NewRateLimiter(5, 50*time.Millisecond)
	var wg sync.WaitGroup

	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			rl.WaitForSlot()
		}(i)
	}

	wg.Wait()

	if rl.TryAcquire() {
		t.Error("all slots should be taken")
	}
}

func TestRateLimiter_TryAcquire_ConcurrentSafe(t *testing.T) {
	rl := NewRateLimiter(100, time.Minute)
	var wg sync.WaitGroup
	acquired := make(chan bool, 200)

	for i := 0; i < 200; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			acquired <- rl.TryAcquire()
		}()
	}

	wg.Wait()
	close(acquired)

	successCount := 0
	for a := range acquired {
		if a {
			successCount++
		}
	}

	if successCount != 100 {
		t.Errorf("expected exactly 100 acquires, got %d", successCount)
	}
}

func TestRateLimiter_Available_ConcurrentSafe(t *testing.T) {
	rl := NewRateLimiter(50, time.Minute)
	var wg sync.WaitGroup

	for i := 0; i < 30; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			rl.TryAcquire()
		}()
	}

	wg.Wait()

	avail := rl.Available()
	if avail != 20 {
		t.Errorf("expected 20 available after 30 acquires, got %d", avail)
	}
}

func TestSongLinkRateLimiter(t *testing.T) {
	if SongLinkRateLimiter == nil {
		t.Fatal("SongLinkRateLimiter should not be nil")
	}
	if SongLinkRateLimiter.maxRequests != 9 {
		t.Errorf("expected maxRequests 9, got %d", SongLinkRateLimiter.maxRequests)
	}
	if SongLinkRateLimiter.window != time.Minute {
		t.Errorf("expected window 1m, got %v", SongLinkRateLimiter.window)
	}
}

func TestSongLinkRateLimiter_AcceptsRequests(t *testing.T) {
	for i := 0; i < 9; i++ {
		if !SongLinkRateLimiter.TryAcquire() {
			t.Fatalf("TryAcquire %d should succeed", i)
		}
	}
}

func TestSongLinkRateLimiter_BlocksAtLimit(t *testing.T) {
	rl := NewRateLimiter(9, time.Minute)
	for i := 0; i < 9; i++ {
		rl.TryAcquire()
	}
	if rl.TryAcquire() {
		t.Error("should be blocked at limit")
	}
}
