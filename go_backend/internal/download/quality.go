package download

import (
	"os"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/convert"
)

// lossyBitrateForQuality maps the user-facing lossy quality tokens to an mp3
// bitrate. Lossless picks (flac/hifi/empty) return "" meaning "keep as-is".
func lossyBitrateForQuality(q string) string {
	switch strings.ToLower(strings.TrimSpace(q)) {
	case "high":
		return "192k"
	case "medium":
		return "128k"
	case "low":
		return "64k"
	}
	return ""
}

// TransformQuality converts [filePath] to the requested quality when it is
// lossy (high/medium/low → mp3 bitrate) using ffmpeg, returning the converted
// path. Lossless picks (flac/hifi) or any failure return the original path so
// download/playback is never blocked by quality transformation.
func TransformQuality(filePath, outDir, quality string) (string, error) {
	bitrate := lossyBitrateForQuality(quality)
	if bitrate == "" {
		return filePath, nil
	}
	ff := FFmpegPath()
	if ff == "" {
		return filePath, nil
	}
	out, err := convert.Convert(convert.Config{
		FFmpegPath: ff,
		OutputDir:  outDir,
		Format:     "mp3",
		Bitrate:    bitrate,
	}, filePath)
	if err != nil || out == nil {
		return filePath, nil
	}
	return out.OutputPath, nil
}

// applyQuality transforms a freshly downloaded/decrypted playable file to the
// user's requested quality and records the final path in the tracker. Returns
// the final file path. It must only be called on playable (non-encrypted)
// files.
func (o *Orchestrator) applyQuality(itemID, filePath, outDir, quality string) string {
	if filePath == "" {
		return ""
	}
	final, err := TransformQuality(filePath, outDir, quality)
	if err == nil && final != "" && final != filePath {
		_ = os.Remove(filePath)
	}
	if final == "" {
		final = filePath
	}
	o.tracker.SetOutputPath(itemID, final)
	return final
}
