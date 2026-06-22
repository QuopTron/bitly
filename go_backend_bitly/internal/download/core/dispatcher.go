package core

import (
	"context"
	"fmt"
	"log"
	"path/filepath"

	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/audio"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/video"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/cover"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/postprocess"
)

func (p *WorkerPool) downloadAudio(ctx context.Context, job *DownloadJob) error {
	if job.ISRC != "" {
		dir := job.OutputDir
		if dir == "" && job.FilePath != "" {
			dir = filepath.Dir(job.FilePath)
		}
		if dir != "" {
			existing, err := CheckISRCExists(dir, job.ISRC)
			if err == nil && existing != "" {
				job.FilePath = existing
				log.Printf("[Worker] Track already downloaded (ISRC match): %s -> %s", job.ISRC, existing)
				return nil
			}
		}
	}

	outputFile := job.FilePath
	if outputFile == "" && job.OutputDir != "" {
		outputFile = filepath.Join(job.OutputDir, job.TrackID+".flac")
	}
	if outputFile == "" {
		return fmt.Errorf("worker: no file path or output dir for audio job %s", job.ID)
	}

	result, err := p.audioStrat.Download(ctx, audio.AudioRequest{
		URL:      job.URL,
		TrackID:  job.TrackID,
		FilePath: outputFile,
	})
	if err != nil {
		return fmt.Errorf("audio download: %w", err)
	}
	job.FilePath = result.FilePath

	if p.postProcessor != nil {
		ppReq := postprocess.PostProcessRequest{
			AudioFilePath: result.FilePath,
			TargetFormat:  "",
			DeleteSource:  false,
		}
		if _, err := p.postProcessor.Process(ctx, ppReq); err != nil {
			log.Printf("[Worker] Post-process warning for %s: %v", job.ID, err)
		}
	}

	return nil
}

func (p *WorkerPool) downloadVideo(ctx context.Context, job *DownloadJob) error {
	outputDir := job.OutputDir
	if outputDir == "" && job.FilePath != "" {
		outputDir = filepath.Dir(job.FilePath)
	}
	if outputDir == "" {
		outputDir = "."
	}

	result, err := p.videoStrat.Download(ctx, video.VideoRequest{
		TrackName: job.TrackName,
		Artist:    job.ArtistName,
		OutputDir: outputDir,
		Format:    "",
	})
	if err != nil {
		return fmt.Errorf("video download: %w", err)
	}
	job.FilePath = result.FilePath
	return nil
}

func (p *WorkerPool) downloadCover(ctx context.Context, job *DownloadJob) error {
	cacheDir := job.OutputDir
	if cacheDir == "" && job.FilePath != "" {
		cacheDir = filepath.Dir(job.FilePath)
	}
	if cacheDir == "" {
		cacheDir = "."
	}

	result, err := p.coverStrat.Download(ctx, cover.CoverRequest{
		URL:        job.URL,
		TrackID:    job.TrackID,
		CacheDir:   cacheDir,
		TrackName:  job.TrackName,
		ArtistName: job.ArtistName,
	})
	if err != nil {
		return fmt.Errorf("cover download: %w", err)
	}
	job.FilePath = result.FilePath
	return nil
}

func (p *WorkerPool) downloadLyrics(ctx context.Context, job *DownloadJob) error {
	if job.Lyrics == "" {
		return fmt.Errorf("worker: no lyrics content for job %s", job.ID)
	}

	outputDir := job.OutputDir
	if outputDir == "" && job.FilePath != "" {
		outputDir = filepath.Dir(job.FilePath)
	}
	if outputDir == "" {
		outputDir = "."
	}

	result, err := p.lyricsStrat.SaveLyrics(ctx, lyrics.LyricsRequest{
		TrackID:    job.TrackID,
		TrackName:  job.TrackName,
		ArtistName: job.ArtistName,
		OutputDir:  outputDir,
	}, job.Lyrics)
	if err != nil {
		return fmt.Errorf("lyrics save: %w", err)
	}
	job.FilePath = result.FilePath
	return nil
}
