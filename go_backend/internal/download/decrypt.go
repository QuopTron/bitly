package download

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ffmpegBinPath is the resolved ffmpeg binary path (set at backend init, or
// lazily via PATH). Empty means ffmpeg is unavailable, so decryption is skipped.
var ffmpegBinPath string

// SetFFmpegPath records the bundled ffmpeg binary so the download pipeline can
// decrypt provider streams (e.g. amazon's mov_key) into playable files.
func SetFFmpegPath(p string) { ffmpegBinPath = p }

// ffmpegPath returns a usable ffmpeg binary path or "".
func ffmpegPath() string {
	if ffmpegBinPath != "" {
		if _, err := os.Stat(ffmpegBinPath); err == nil {
			return ffmpegBinPath
		}
	}
	if p, err := exec.LookPath("ffmpeg"); err == nil {
		return p
	}
	return ""
}

// FFmpegPath exposes the resolved ffmpeg binary path ("" if unavailable).
func FFmpegPath() string { return ffmpegPath() }

// decryptStream decrypts an encrypted/DRM stream file ([inputPath]) with
// ffmpeg's -decryption_key into a playable file in [outDir], returning the
// decrypted path. [outExt] selects the output container (".flac" for flac
// content, ".mp4" for eac3/ac4/opus); empty defaults to ".mp4". On any failure
// it removes partial output and returns an error so the caller can fall back
// (reject this provider, try the next one).
func decryptStream(inputPath, key, outDir, outExt string) (string, error) {
	if key == "" {
		return "", fmt.Errorf("no decryption key")
	}
	bin := ffmpegPath()
	if bin == "" {
		return "", fmt.Errorf("ffmpeg no disponible para descifrar")
	}
	if outExt == "" {
		outExt = ".mp4"
	}
	if !strings.HasPrefix(outExt, ".") {
		outExt = "." + outExt
	}
	base := strings.TrimSuffix(filepath.Base(inputPath), filepath.Ext(inputPath))
	if base == "" {
		base = "track"
	}
	outFile := filepath.Join(outDir, base+".decrypted"+outExt)
	args := []string{
		"-y",
		"-decryption_key", key,
		"-i", inputPath,
		"-c", "copy",
		outFile,
	}
	cmd := exec.Command(bin, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		_ = os.Remove(outFile)
		return "", fmt.Errorf("descifrado ffmpeg fallido: %s: %w", string(output), err)
	}
	return outFile, nil
}