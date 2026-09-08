package download

import (
	"os"
	"os/exec"
)

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

// decryptionKeyCandidates returns the plausible -decryption_key forms for a
// provider key. FFmpeg's MOV/MP4 demuxer hex-decodes the binary decryption_key
// option and rejects any length other than 16 bytes ("Invalid decryption key
// len"), and does NOT accept a 0x prefix ("Error setting option"). Providers
// may return the key as plain hex, 0x-prefixed hex, or base64 of the raw bytes,
// so we normalize and emit only unprefixed 32-hex-char (16-byte) candidates.
