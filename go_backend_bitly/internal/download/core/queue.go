package core

import (
	"container/heap"
	"sync"
	"time"
)

// DownloadJob represents a single download task.
type DownloadJob struct {
	ID         string
	UserID     string
	TrackID    string
	TrackName  string
	ArtistName string
	AlbumName  string
	ISRC       string
	URL        string   `json:"url,omitempty"`        // Source URL to download from
	Lyrics     string   `json:"lyrics,omitempty"`     // Lyrics text content
	OutputDir  string   `json:"output_dir,omitempty"` // Output directory for downloaded files
	Quality    string
	Source     string
	Type       string // audio, video, cover, lyrics
	Priority   int
	Status     string // pending, downloading, completed, failed
	Progress   float64
	RetryCount int
	MaxRetries int
	CreatedAt  time.Time
	FilePath   string
	Error      string
}

// DownloadQueue is a priority queue for download jobs.
type DownloadQueue struct {
	mu   sync.Mutex
	jobs []*DownloadJob
	cond *sync.Cond
}

// NewDownloadQueue creates a new download queue.
func NewDownloadQueue() *DownloadQueue {
	q := &DownloadQueue{}
	q.cond = sync.NewCond(&q.mu)
	heap.Init(q)
	return q
}

// Enqueue adds a job to the queue.
func (q *DownloadQueue) Enqueue(job *DownloadJob) {
	q.mu.Lock()
	defer q.mu.Unlock()
	heap.Push(q, job)
	q.cond.Signal()
}

// Dequeue removes and returns the highest priority job.
func (q *DownloadQueue) Dequeue() *DownloadJob {
	q.mu.Lock()
	defer q.mu.Unlock()
	for q.Len() == 0 {
		q.cond.Wait()
	}
	return heap.Pop(q).(*DownloadJob)
}

// TryDequeue attempts to dequeue without blocking.
func (q *DownloadQueue) TryDequeue() *DownloadJob {
	q.mu.Lock()
	defer q.mu.Unlock()
	if q.Len() == 0 {
		return nil
	}
	return heap.Pop(q).(*DownloadJob)
}

// Remove removes a job by ID.
func (q *DownloadQueue) Remove(id string) {
	q.mu.Lock()
	defer q.mu.Unlock()
	for i, job := range q.jobs {
		if job.ID == id {
			heap.Remove(q, i)
			return
		}
	}
}

// Len returns the number of jobs in the queue.
func (q *DownloadQueue) Len() int { return len(q.jobs) }

// Less compares jobs by priority (higher priority = sooner).
func (q *DownloadQueue) Less(i, j int) bool {
	if q.jobs[i].Priority != q.jobs[j].Priority {
		return q.jobs[i].Priority > q.jobs[j].Priority
	}
	return q.jobs[i].CreatedAt.Before(q.jobs[j].CreatedAt)
}

// Swap swaps two jobs.
func (q *DownloadQueue) Swap(i, j int) {
	q.jobs[i], q.jobs[j] = q.jobs[j], q.jobs[i]
}

// Push adds an item to the heap.
func (q *DownloadQueue) Push(x interface{}) {
	q.jobs = append(q.jobs, x.(*DownloadJob))
}

// Pop removes the last item from the heap.
func (q *DownloadQueue) Pop() interface{} {
	old := q.jobs
	n := len(old)
	item := old[n-1]
	old[n-1] = nil
	q.jobs = old[:n-1]
	return item
}
