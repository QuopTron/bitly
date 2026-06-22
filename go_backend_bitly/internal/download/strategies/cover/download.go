package cover

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/zarz/bitly/go_backend_bitly/internal/utils"
)

func (s *Strategy) Download(ctx context.Context, req CoverRequest) (*CoverResult, error) {
	if req.URL == "" {
		return nil, fmt.Errorf("cover: no URL provided")
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodGet, req.URL, nil)
	if err != nil {
		return nil, fmt.Errorf("cover: create request: %w", err)
	}
	httpReq.Header.Set("User-Agent", "Bitly/1.0")

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("cover: download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("cover: HTTP %d", resp.StatusCode)
	}

	head := make([]byte, 512)
	n, _ := io.ReadFull(resp.Body, head)
	if n == 0 {
		return nil, fmt.Errorf("cover: empty response")
	}
	head = head[:n]

	mimeType := detectMimeByMagic(head)
	ext := mimeExt(mimeType)

	cacheDir := req.CacheDir
	if cacheDir == "" {
		cacheDir = os.TempDir()
	}
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return nil, fmt.Errorf("cover: mkdir %s: %w", cacheDir, err)
	}

	var filename string
	if req.TrackID != "" {
		hash := utils.HashString(req.TrackID)
		filename = fmt.Sprintf("cover_%x%s", hash, ext)
	} else {
		safeArtist := utils.SanitizeFilename(req.ArtistName)
		safeTrack := utils.SanitizeFilename(req.TrackName)
		filename = fmt.Sprintf("%s - %s%s", safeArtist, safeTrack, ext)
	}

	filePath := filepath.Join(cacheDir, filename)

	if info, err := os.Stat(filePath); err == nil && info.Size() > 0 {
		return &CoverResult{
			FilePath: filePath,
			Size:     info.Size(),
			MimeType: mimeType,
		}, nil
	}

	out, err := os.Create(filePath)
	if err != nil {
		return nil, fmt.Errorf("cover: create file: %w", err)
	}
	defer out.Close()

	if _, err := out.Write(head); err != nil {
		out.Close()
		os.Remove(filePath)
		return nil, fmt.Errorf("cover: write header: %w", err)
	}

	written, err := io.Copy(out, resp.Body)
	if err != nil {
		out.Close()
		os.Remove(filePath)
		return nil, fmt.Errorf("cover: write body: %w", err)
	}

	totalSize := int64(n) + written

	return &CoverResult{
		FilePath: filePath,
		Size:     totalSize,
		MimeType: mimeType,
	}, nil
}
