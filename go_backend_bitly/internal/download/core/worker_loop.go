package core

import (
	"context"
	"fmt"
	"log"
)

func (p *WorkerPool) worker(id int) {
	defer p.wg.Done()
	log.Printf("[Worker %d] started", id)

	for !p.stopped {
		job := p.queue.Dequeue()
		if job == nil {
			continue
		}

		if IsDownloadCancelled(job.ID) {
			job.Status = "cancelled"
			job.Progress = 0
			log.Printf("[Worker %d] job %s was already cancelled, skipping", id, job.ID)
			continue
		}

		job.Status = "downloading"
		log.Printf("[Worker %d] processing %s job: %s (%s)", id, job.Type, job.TrackName, job.ID)

		ctx := InitDownloadCancel(job.ID)

		err := p.dispatchJob(ctx, job)

		if err != nil {
			if err == context.Canceled || IsDownloadCancelled(job.ID) {
				job.Status = "cancelled"
				job.Error = "cancelled"
				ClearDownloadCancel(job.ID)
				log.Printf("[Worker %d] job %s was cancelled during download", id, job.ID)
				continue
			}

			if job.RetryCount < job.MaxRetries {
				job.RetryCount++
				job.Status = "pending"
				job.Error = err.Error()
				log.Printf("[Worker %d] job %s failed (retry %d/%d): %v", id, job.ID, job.RetryCount, job.MaxRetries, err)
				p.queue.Enqueue(job)
				ClearDownloadCancel(job.ID)
				continue
			}

			job.Status = "failed"
			job.Error = err.Error()
			job.Progress = 0
			ClearDownloadCancel(job.ID)
			log.Printf("[Worker %d] job %s failed after %d retries: %v", id, job.ID, job.MaxRetries, err)
		} else {
			job.Status = "completed"
			job.Progress = 100
			ClearDownloadCancel(job.ID)
			log.Printf("[Worker %d] job %s completed", id, job.ID)
		}
	}
}

func (p *WorkerPool) dispatchJob(ctx context.Context, job *DownloadJob) error {
	switch job.Type {
	case "audio":
		return p.downloadAudio(ctx, job)
	case "video":
		return p.downloadVideo(ctx, job)
	case "cover":
		return p.downloadCover(ctx, job)
	case "lyrics":
		return p.downloadLyrics(ctx, job)
	default:
		return fmt.Errorf("worker: unknown job type: %s", job.Type)
	}
}
