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

// applyQuality converts the freshly downloaded/decrypted file to the requested
// quality format when lossy (high/medium/low → mp3 bitrate) using ffmpeg,
// returning the converted path. Lossless picks (flac/hifi) keep the original
// file as-is. The file is only touched if it is already playable (non-encrypted).
func (o *Orchestrator) applyQuality(itemID, filePath, outDir, quality string) string {
	if filePath == "" {
		return ""
	}
	// Transform to lossy format if quality is not lossless
	converted, err := TransformQuality(filePath, outDir, quality)
	if err == nil && converted != filePath && converted != "" {
		// Remove original file after successful conversion
		_ = os.Remove(filePath)
		filePath = converted
	}
	o.tracker.SetOutputPath(itemID, filePath)
	return filePath
}
