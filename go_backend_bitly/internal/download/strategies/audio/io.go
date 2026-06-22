package audio

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func (s *Strategy) writeFromResponse(ctx context.Context, req AudioRequest, resp *http.Response) (*AudioResult, error) {
	out, err := os.Create(req.FilePath)
	if err != nil {
		return nil, fmt.Errorf("create file: %w", err)
	}
	defer out.Close()

	written, err := s.copyWithContext(ctx, out, resp.Body)
	if err != nil {
		out.Close()
		os.Remove(req.FilePath)
		return nil, fmt.Errorf("write: %w", err)
	}

	return &AudioResult{
		FilePath:     req.FilePath,
		Size:         written,
		Format:       detectFormat(req),
		BytesWritten: written,
	}, nil
}

func (s *Strategy) appendFromResponse(ctx context.Context, req AudioRequest, resp *http.Response) (*AudioResult, error) {
	out, err := os.OpenFile(req.FilePath, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return nil, fmt.Errorf("open for append: %w", err)
	}
	defer out.Close()

	written, err := s.copyWithContext(ctx, out, resp.Body)
	if err != nil {
		return nil, fmt.Errorf("append write: %w", err)
	}

	fi, statErr := os.Stat(req.FilePath)
	totalSize := written
	if statErr == nil {
		totalSize = fi.Size()
	}

	return &AudioResult{
		FilePath:     req.FilePath,
		Size:         totalSize,
		Format:       detectFormat(req),
		BytesWritten: written,
	}, nil
}

func (s *Strategy) copyWithContext(ctx context.Context, dst io.Writer, src io.Reader) (int64, error) {
	buf := make([]byte, 128*1024)
	var total int64
	for {
		select {
		case <-ctx.Done():
			return total, ctx.Err()
		default:
		}

		n, readErr := src.Read(buf)
		if n > 0 {
			wn, writeErr := dst.Write(buf[:n])
			if wn > 0 {
				total += int64(wn)
			}
			if writeErr != nil {
				return total, fmt.Errorf("write: %w", writeErr)
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return total, fmt.Errorf("read: %w", readErr)
		}
	}
	return total, nil
}

func detectFormat(req AudioRequest) string {
	if req.Format != "" {
		return req.Format
	}
	ext := filepath.Ext(req.FilePath)
	if ext != "" {
		return strings.TrimPrefix(strings.ToLower(ext), ".")
	}
	return "flac"
}

func ParseContentRange(header string) (start, end, total int64, err error) {
	parts := strings.SplitN(strings.TrimPrefix(header, "bytes "), "/", 2)
	if len(parts) != 2 {
		return 0, 0, 0, fmt.Errorf("invalid content-range: %s", header)
	}
	total, err = strconv.ParseInt(parts[1], 10, 64)
	if err != nil {
		return 0, 0, 0, fmt.Errorf("invalid total: %w", err)
	}
	rangeParts := strings.SplitN(parts[0], "-", 2)
	if len(rangeParts) != 2 {
		return 0, 0, 0, fmt.Errorf("invalid range: %s", parts[0])
	}
	start, _ = strconv.ParseInt(rangeParts[0], 10, 64)
	end, _ = strconv.ParseInt(rangeParts[1], 10, 64)
	return start, end, total, nil
}
