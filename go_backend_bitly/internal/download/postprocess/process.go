package postprocess

import (
	"context"
	"fmt"
	"log"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/embedding"
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/formats"
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

func (p *Processor) Process(ctx context.Context, req PostProcessRequest) (*PostProcessResult, error) {
	result := &PostProcessResult{
		AudioFilePath: req.AudioFilePath,
		CoverPath:     req.CoverPath,
		LyricsPath:    req.LyricsPath,
	}

	currentPath := req.AudioFilePath

	if req.TargetFormat != "" {
		ext := strings.TrimPrefix(filepath.Ext(currentPath), ".")
		if !strings.EqualFold(ext, req.TargetFormat) {
			log.Printf("[PostProcess] Converting %s -> %s", ext, req.TargetFormat)
			convResult, err := p.converter.Convert(ctx, formats.ConvertRequest{
				SourceFile:   currentPath,
				TargetFormat: req.TargetFormat,
				Quality:      "best",
			})
			if err != nil {
				return nil, fmt.Errorf("postprocess: format conversion: %w", err)
			}
			result.AudioFilePath = convResult.OutputFile

			if req.DeleteSource && currentPath != convResult.OutputFile {
				if err := metadata.DeleteFileAndCleanupFolder(currentPath); err != nil {
					log.Printf("[PostProcess] Warning: could not delete source %s: %v", currentPath, err)
				}
			}
			currentPath = convResult.OutputFile
		}
	}

	ext := strings.ToLower(filepath.Ext(currentPath))
	if ext == ".flac" && req.Tags.Title != "" {
		log.Printf("[PostProcess] Embedding metadata into %s", currentPath)
		if err := p.embedder.Embed(ctx, embedding.EmbedRequest{
			AudioPath:   currentPath,
			Title:       req.Tags.Title,
			Artist:      req.Tags.Artist,
			Album:       req.Tags.Album,
			AlbumArtist: req.Tags.AlbumArtist,
			Genre:       req.Tags.Genre,
			Date:        req.Tags.Date,
			ISRC:        req.Tags.ISRC,
			TrackNum:    req.Tags.TrackNumber,
			TotalTracks: req.Tags.TotalTracks,
			DiscNum:     req.Tags.DiscNumber,
			TotalDiscs:  req.Tags.TotalDiscs,
			Label:       req.Tags.Label,
			Copyright:   req.Tags.Copyright,
			Composer:    req.Tags.Composer,
			Lyrics:      req.Tags.Lyrics,
			CoverPath:   req.CoverPath,
		}); err != nil {
			log.Printf("[PostProcess] Warning: metadata embed: %v", err)
		}
	} else if ext != ".flac" && req.Tags.Title != "" {
		if req.CoverPath != "" {
			if err := p.embedder.EmbedCover(ctx, currentPath, req.CoverPath); err != nil {
				log.Printf("[PostProcess] Warning: cover embed for %s: %v", ext, err)
			}
		}
		if req.Tags.Lyrics != "" {
			if err := p.embedder.EmbedLyrics(ctx, currentPath, req.Tags.Lyrics); err != nil {
				log.Printf("[PostProcess] Warning: lyrics embed for %s: %v", ext, err)
			}
		}
	}

	if req.DeleteSource && req.AudioFilePath != result.AudioFilePath {
		if err := metadata.DeleteFileAndCleanupFolder(req.AudioFilePath); err != nil {
			log.Printf("[PostProcess] Warning: cleanup: %v", err)
		}
	}

	log.Printf("[PostProcess] Complete: %s", result.AudioFilePath)
	return result, nil
}
