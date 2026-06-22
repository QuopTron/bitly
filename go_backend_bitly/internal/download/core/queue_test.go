package core

import (
	"testing"
	"time"
)

func newJob(id string, priority int, createdAt time.Time) *DownloadJob {
	return &DownloadJob{
		ID:        id,
		Priority:  priority,
		CreatedAt: createdAt,
		Status:    "pending",
	}
}

func TestNewDownloadQueue(t *testing.T) {
	q := NewDownloadQueue()
	if q == nil {
		t.Fatal("queue should not be nil")
	}
	if q.Len() != 0 {
		t.Errorf("new queue should have length 0, got %d", q.Len())
	}
}

func TestEnqueue_IncreasesLen(t *testing.T) {
	q := NewDownloadQueue()
	q.Enqueue(newJob("a", 0, time.Now()))
	if q.Len() != 1 {
		t.Errorf("expected Len=1, got %d", q.Len())
	}
	q.Enqueue(newJob("b", 0, time.Now()))
	if q.Len() != 2 {
		t.Errorf("expected Len=2, got %d", q.Len())
	}
}

func TestDequeue_ReturnsJobsInFIFOOrder(t *testing.T) {
	q := NewDownloadQueue()
	now := time.Now()

	q.Enqueue(newJob("first", 0, now))
	q.Enqueue(newJob("second", 0, now.Add(time.Second)))
	q.Enqueue(newJob("third", 0, now.Add(2*time.Second)))

	j1 := q.Dequeue()
	j2 := q.Dequeue()
	j3 := q.Dequeue()

	if j1.ID != "first" {
		t.Errorf("expected 'first', got '%s'", j1.ID)
	}
	if j2.ID != "second" {
		t.Errorf("expected 'second', got '%s'", j2.ID)
	}
	if j3.ID != "third" {
		t.Errorf("expected 'third', got '%s'", j3.ID)
	}
}

func TestDequeue_PriorityOrder(t *testing.T) {
	q := NewDownloadQueue()
	now := time.Now()

	q.Enqueue(newJob("low", 1, now))
	q.Enqueue(newJob("high", 10, now))
	q.Enqueue(newJob("medium", 5, now))

	j1 := q.Dequeue()
	j2 := q.Dequeue()
	j3 := q.Dequeue()

	if j1.ID != "high" {
		t.Errorf("expected 'high' first, got '%s'", j1.ID)
	}
	if j2.ID != "medium" {
		t.Errorf("expected 'medium' second, got '%s'", j2.ID)
	}
	if j3.ID != "low" {
		t.Errorf("expected 'low' third, got '%s'", j3.ID)
	}
}

func TestDequeue_SamePriorityPreservesCreationOrder(t *testing.T) {
	q := NewDownloadQueue()
	now := time.Now()

	q.Enqueue(newJob("z", 5, now.Add(2*time.Second)))
	q.Enqueue(newJob("a", 5, now))
	q.Enqueue(newJob("m", 5, now.Add(time.Second)))

	j1 := q.Dequeue()
	j2 := q.Dequeue()
	j3 := q.Dequeue()

	if j1.ID != "a" {
		t.Errorf("expected 'a' first (earliest), got '%s'", j1.ID)
	}
	if j2.ID != "m" {
		t.Errorf("expected 'm' second, got '%s'", j2.ID)
	}
	if j3.ID != "z" {
		t.Errorf("expected 'z' third (latest), got '%s'", j3.ID)
	}
}

func TestDequeue_MixedPriorityAndTime(t *testing.T) {
	q := NewDownloadQueue()
	now := time.Now()

	q.Enqueue(newJob("a", 1, now))
	q.Enqueue(newJob("b", 10, now.Add(time.Hour)))
	q.Enqueue(newJob("c", 5, now.Add(-time.Hour)))

	j1 := q.Dequeue()
	j2 := q.Dequeue()
	j3 := q.Dequeue()

	if j1.ID != "b" {
		t.Errorf("expected 'b' first (highest priority), got '%s'", j1.ID)
	}
	if j2.ID != "c" {
		t.Errorf("expected 'c' second (medium priority, earlier), got '%s'", j2.ID)
	}
	if j3.ID != "a" {
		t.Errorf("expected 'a' third (lowest priority), got '%s'", j3.ID)
	}
}

func TestTryDequeue_EmptyReturnsNil(t *testing.T) {
	q := NewDownloadQueue()
	job := q.TryDequeue()
	if job != nil {
		t.Error("expected nil for empty queue")
	}
}

func TestTryDequeue_NonEmptyReturnsJob(t *testing.T) {
	q := NewDownloadQueue()
	q.Enqueue(newJob("test", 0, time.Now()))

	job := q.TryDequeue()
	if job == nil {
		t.Fatal("expected a job, got nil")
	}
	if job.ID != "test" {
		t.Errorf("expected 'test', got '%s'", job.ID)
	}
	if q.Len() != 0 {
		t.Errorf("expected empty queue after TryDequeue, Len=%d", q.Len())
	}
}

func TestRemove_RemovesByID(t *testing.T) {
	q := NewDownloadQueue()
	q.Enqueue(newJob("keep", 0, time.Now()))
	q.Enqueue(newJob("remove", 0, time.Now()))
	q.Enqueue(newJob("also-keep", 0, time.Now()))

	q.Remove("remove")

	if q.Len() != 2 {
		t.Errorf("expected Len=2 after remove, got %d", q.Len())
	}

	ids := make(map[string]bool)
	ids[q.Dequeue().ID] = true
	ids[q.Dequeue().ID] = true

	if ids["remove"] {
		t.Error("removed job should not be dequeued")
	}
	if !ids["keep"] || !ids["also-keep"] {
		t.Error("remaining jobs should be dequeued")
	}
}

func TestRemove_NonExistentID(t *testing.T) {
	q := NewDownloadQueue()
	q.Enqueue(newJob("a", 0, time.Now()))

	q.Remove("nonexistent")

	if q.Len() != 1 {
		t.Errorf("expected Len=1, got %d", q.Len())
	}
}

func TestRemove_FirstAndLast(t *testing.T) {
	q := NewDownloadQueue()
	q.Enqueue(newJob("first", 0, time.Now()))
	q.Enqueue(newJob("middle", 0, time.Now()))
	q.Enqueue(newJob("last", 0, time.Now()))

	q.Remove("first")
	q.Remove("last")

	j := q.Dequeue()
	if j.ID != "middle" {
		t.Errorf("expected 'middle', got '%s'", j.ID)
	}
}

func TestLen_AfterOps(t *testing.T) {
	q := NewDownloadQueue()

	q.Enqueue(newJob("a", 0, time.Now()))
	q.Enqueue(newJob("b", 0, time.Now()))
	if q.Len() != 2 {
		t.Fatalf("expected Len=2 after 2 enqueues, got %d", q.Len())
	}

	q.Dequeue()
	if q.Len() != 1 {
		t.Errorf("expected Len=1 after dequeue, got %d", q.Len())
	}

	q.TryDequeue()
	if q.Len() != 0 {
		t.Errorf("expected Len=0 after TryDequeue, got %d", q.Len())
	}

	q.Enqueue(newJob("c", 0, time.Now()))
	if q.Len() != 1 {
		t.Errorf("expected Len=1 after final enqueue, got %d", q.Len())
	}
}

func TestDownloadJob_DefaultValues(t *testing.T) {
	job := &DownloadJob{ID: "test"}
	if job.Status != "" {
		t.Errorf("expected empty Status, got '%s'", job.Status)
	}
	if job.Priority != 0 {
		t.Errorf("expected Priority=0, got %d", job.Priority)
	}
	if job.RetryCount != 0 {
		t.Errorf("expected RetryCount=0, got %d", job.RetryCount)
	}
	if job.MaxRetries != 0 {
		t.Errorf("expected MaxRetries=0, got %d", job.MaxRetries)
	}
	if job.Progress != 0 {
		t.Errorf("expected Progress=0, got %f", job.Progress)
	}
}

func TestDownloadJob_FieldAccess(t *testing.T) {
	now := time.Now()
	job := &DownloadJob{
		ID:         "job-1",
		UserID:     "user-42",
		TrackID:    "track-99",
		TrackName:  "Never Gonna Give You Up",
		ArtistName: "Rick Astley",
		AlbumName:  "Whenever You Need Somebody",
		ISRC:       "USRC48700001",
		URL:        "https://example.com/audio",
		Lyrics:     "Never gonna give you up...",
		OutputDir:  "/tmp/downloads",
		Quality:    "flac",
		Source:     "youtube",
		Type:       "audio",
		Priority:   5,
		Status:     "pending",
		Progress:   0.5,
		RetryCount: 1,
		MaxRetries: 3,
		CreatedAt:  now,
		FilePath:   "/tmp/downloads/track.flac",
		Error:      "",
	}

	if job.ID != "job-1" {
		t.Errorf("ID: got '%s'", job.ID)
	}
	if job.UserID != "user-42" {
		t.Errorf("UserID: got '%s'", job.UserID)
	}
	if job.TrackID != "track-99" {
		t.Errorf("TrackID: got '%s'", job.TrackID)
	}
	if job.TrackName != "Never Gonna Give You Up" {
		t.Errorf("TrackName: got '%s'", job.TrackName)
	}
	if job.ArtistName != "Rick Astley" {
		t.Errorf("ArtistName: got '%s'", job.ArtistName)
	}
	if job.AlbumName != "Whenever You Need Somebody" {
		t.Errorf("AlbumName: got '%s'", job.AlbumName)
	}
	if job.ISRC != "USRC48700001" {
		t.Errorf("ISRC: got '%s'", job.ISRC)
	}
	if job.URL != "https://example.com/audio" {
		t.Errorf("URL: got '%s'", job.URL)
	}
	if job.Lyrics != "Never gonna give you up..." {
		t.Errorf("Lyrics: got '%s'", job.Lyrics)
	}
	if job.OutputDir != "/tmp/downloads" {
		t.Errorf("OutputDir: got '%s'", job.OutputDir)
	}
	if job.Quality != "flac" {
		t.Errorf("Quality: got '%s'", job.Quality)
	}
	if job.Source != "youtube" {
		t.Errorf("Source: got '%s'", job.Source)
	}
	if job.Type != "audio" {
		t.Errorf("Type: got '%s'", job.Type)
	}
	if job.Priority != 5 {
		t.Errorf("Priority: got %d", job.Priority)
	}
	if job.Status != "pending" {
		t.Errorf("Status: got '%s'", job.Status)
	}
	if job.Progress != 0.5 {
		t.Errorf("Progress: got %f", job.Progress)
	}
	if job.RetryCount != 1 {
		t.Errorf("RetryCount: got %d", job.RetryCount)
	}
	if job.MaxRetries != 3 {
		t.Errorf("MaxRetries: got %d", job.MaxRetries)
	}
	if !job.CreatedAt.Equal(now) {
		t.Errorf("CreatedAt: got %v", job.CreatedAt)
	}
	if job.FilePath != "/tmp/downloads/track.flac" {
		t.Errorf("FilePath: got '%s'", job.FilePath)
	}
	if job.Error != "" {
		t.Errorf("Error: got '%s'", job.Error)
	}
}

func TestDequeue_BlockingBehavior(t *testing.T) {
	q := NewDownloadQueue()
	done := make(chan *DownloadJob, 1)

	go func() {
		job := q.Dequeue()
		done <- job
	}()

	time.Sleep(50 * time.Millisecond)

	select {
	case <-done:
		t.Fatal("Dequeue should block on empty queue")
	default:
	}

	q.Enqueue(newJob("unblock", 0, time.Now()))

	select {
	case job := <-done:
		if job.ID != "unblock" {
			t.Errorf("expected 'unblock', got '%s'", job.ID)
		}
	case <-time.After(time.Second):
		t.Fatal("Dequeue did not unblock after Enqueue")
	}
}

func TestTryDequeue_AfterDequeueAll(t *testing.T) {
	q := NewDownloadQueue()
	q.Enqueue(newJob("a", 0, time.Now()))
	q.TryDequeue()
	job := q.TryDequeue()
	if job != nil {
		t.Error("expected nil when queue is empty")
	}
}

func TestDequeue_Stress(t *testing.T) {
	q := NewDownloadQueue()
	const n = 100

	for i := 0; i < n; i++ {
		q.Enqueue(newJob(string(rune('a'+i%26))+string(rune('0'+i/10%10)), 0, time.Now()))
	}

	for i := 0; i < n; i++ {
		job := q.Dequeue()
		if job == nil {
			t.Fatalf("expected job at iteration %d", i)
		}
	}

	if q.Len() != 0 {
		t.Errorf("expected empty queue, Len=%d", q.Len())
	}
}

func TestDequeue_PriorityStress(t *testing.T) {
	q := NewDownloadQueue()
	const n = 50

	for i := 0; i < n; i++ {
		job := newJob(string(rune('a'+i%26))+string(rune('0'+i/10%10)), i%10, time.Now())
		q.Enqueue(job)
	}

	for prevPriority := 10; q.Len() > 0; {
		job := q.Dequeue()
		if job == nil {
			t.Fatal("unexpected nil job")
		}
		if job.Priority > prevPriority {
			t.Errorf("priority decreased: %d -> %d", prevPriority, job.Priority)
		}
		prevPriority = job.Priority
	}
}
