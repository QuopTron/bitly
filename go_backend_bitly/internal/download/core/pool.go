package core

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/audio"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/video"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/cover"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/postprocess"
	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type WorkerPool struct {
	size       int
	queue      *DownloadQueue
	stopped    bool
	wg         sync.WaitGroup

	audioStrat    *audio.Strategy
	videoStrat    *video.Strategy
	coverStrat    *cover.Strategy
	lyricsStrat   *lyrics.Strategy
	postProcessor *postprocess.Processor
}

func NewWorkerPool(size int, queue *DownloadQueue, ffmpegPath, ytdlpPath string) *WorkerPool {
	if ffmpegPath == "" {
		ffmpegPath = "ffmpeg"
	}
	if ytdlpPath == "" {
		ytdlpPath = "yt-dlp"
	}

	return &WorkerPool{
		size:         size,
		queue:        queue,
		audioStrat:   audio.NewStrategy(httpclient.GetDownloadClient(), 3),
		videoStrat:   video.NewStrategy(ytdlpPath, 5*time.Minute),
		coverStrat:   cover.NewStrategy(httpclient.GetSharedClient()),
		lyricsStrat:  lyrics.NewStrategy(),
		postProcessor: postprocess.NewProcessor(ffmpegPath),
	}
}

func (p *WorkerPool) Start() {
	for i := 0; i < p.size; i++ {
		p.wg.Add(1)
		go p.worker(i)
	}
}

func (p *WorkerPool) Stop() {
	p.stopped = true
	p.wg.Wait()
}
