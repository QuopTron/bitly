package embedding

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

type Embedder struct {
	coverDir string
}

type EmbedRequest struct {
	AudioPath    string `json:"audio_path"`
	Title        string `json:"title,omitempty"`
	Artist       string `json:"artist,omitempty"`
	Album        string `json:"album,omitempty"`
	AlbumArtist  string `json:"album_artist,omitempty"`
	Genre        string `json:"genre,omitempty"`
	Date         string `json:"date,omitempty"`
	ISRC         string `json:"isrc,omitempty"`
	TrackNum     int    `json:"track_number,omitempty"`
	TotalTracks  int    `json:"total_tracks,omitempty"`
	DiscNum      int    `json:"disc_number,omitempty"`
	TotalDiscs   int    `json:"total_discs,omitempty"`
	Label        string `json:"label,omitempty"`
	Copyright    string `json:"copyright,omitempty"`
	Composer     string `json:"composer,omitempty"`
	Lyrics       string `json:"lyrics,omitempty"`
	CoverPath    string `json:"cover_path,omitempty"`
}

func NewEmbedder(coverDir string) *Embedder {
	return &Embedder{coverDir: coverDir}
}

func (e *Embedder) Embed(ctx context.Context, req EmbedRequest) error {
	if req.AudioPath == "" {
		return fmt.Errorf("embedding: no audio file specified")
	}
	if _, err := os.Stat(req.AudioPath); os.IsNotExist(err) {
		return fmt.Errorf("embedding: file not found: %s", req.AudioPath)
	}

	ext := strings.ToLower(filepath.Ext(req.AudioPath))

	switch ext {
	case ".flac":
		return e.embedIntoFlac(req)
	case ".mp3":
		return e.embedSidecar(req)
	case ".m4a", ".aac":
		return e.embedSidecar(req)
	case ".opus", ".ogg":
		return e.embedSidecar(req)
	default:
		return e.embedSidecar(req)
	}
}

func (e *Embedder) EmbedLyrics(ctx context.Context, audioPath, lyrics string) error {
	if audioPath == "" {
		return fmt.Errorf("embedding: no audio file specified")
	}
	if lyrics == "" {
		return nil
	}
	if _, err := os.Stat(audioPath); os.IsNotExist(err) {
		return fmt.Errorf("embedding: file not found: %s", audioPath)
	}

	ext := strings.ToLower(filepath.Ext(audioPath))
	if ext == ".flac" {
		return metadata.EmbedLyrics(audioPath, lyrics)
	}
	return writeSidecar(audioPath, ".lrc", lyrics)
}

func (e *Embedder) EmbedCover(ctx context.Context, audioPath, coverPath string) error {
	if audioPath == "" || coverPath == "" {
		return fmt.Errorf("embedding: audio path and cover path are required")
	}
	if _, err := os.Stat(audioPath); os.IsNotExist(err) {
		return fmt.Errorf("embedding: file not found: %s", audioPath)
	}
	if _, err := os.Stat(coverPath); os.IsNotExist(err) {
		return fmt.Errorf("embedding: cover not found: %s", coverPath)
	}

	ext := strings.ToLower(filepath.Ext(audioPath))
	if ext == ".flac" {
		_ = metadata.EmbedMetadata(audioPath, metadata.Metadata{}, coverPath)
		return nil
	}
	coverData, err := os.ReadFile(coverPath)
	if err != nil {
		return fmt.Errorf("embedding: read cover: %w", err)
	}
	coverExt := filepath.Ext(coverPath)
	return writeSidecar(audioPath, coverExt, string(coverData))
}
