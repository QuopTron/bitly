package core

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/audio"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/video"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/cover"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/strategies/lyrics"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/postprocess"
)

func (p *WorkerPool) SetAudioStrategy(s *audio.Strategy) {
	p.audioStrat = s
}

func (p *WorkerPool) SetVideoStrategy(s *video.Strategy) {
	p.videoStrat = s
}

func (p *WorkerPool) SetCoverStrategy(s *cover.Strategy) {
	p.coverStrat = s
}

func (p *WorkerPool) SetLyricsStrategy(s *lyrics.Strategy) {
	p.lyricsStrat = s
}

func (p *WorkerPool) SetPostProcessor(pp *postprocess.Processor) {
	p.postProcessor = pp
}
