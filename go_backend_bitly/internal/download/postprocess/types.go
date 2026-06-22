package postprocess

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/formats"
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/embedding"
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

type Processor struct {
	converter  *formats.Converter
	embedder   *embedding.Embedder
	ffmpegPath string
}

type PostProcessRequest struct {
	AudioFilePath string            `json:"audio_file_path"`
	CoverPath     string            `json:"cover_path,omitempty"`
	LyricsPath    string            `json:"lyrics_path,omitempty"`
	TargetFormat  string            `json:"target_format,omitempty"`
	Tags          metadata.Metadata `json:"tags,omitempty"`
	DeleteSource  bool              `json:"delete_source"`
}

type PostProcessResult struct {
	AudioFilePath string `json:"audio_file_path"`
	CoverPath     string `json:"cover_path,omitempty"`
	LyricsPath    string `json:"lyrics_path,omitempty"`
}

func NewProcessor(ffmpegPath string) *Processor {
	conv := formats.NewConverter(ffmpegPath)
	return &Processor{
		converter:  conv,
		embedder:   embedding.NewEmbedder(""),
		ffmpegPath: ffmpegPath,
	}
}
