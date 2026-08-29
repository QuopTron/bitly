package download

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
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

// decryptionKeyCandidates returns the plausible -decryption_key forms for a
// provider key. FFmpeg's MOV/MP4 demuxer hex-decodes the binary decryption_key
// option and rejects any length other than 16 bytes ("Invalid decryption key
// len"), and does NOT accept a 0x prefix ("Error setting option"). Providers
// may return the key as plain hex, 0x-prefixed hex, or base64 of the raw bytes,
// so we normalize and emit only unprefixed 32-hex-char (16-byte) candidates.
var hexOnly = regexp.MustCompile(`^[0-9a-fA-F]+$`)

func decryptionKeyCandidates(rawKey string) []string {
	out := map[string]struct{}{}
	addHex := func(k string) {
		k = strings.ToLower(strings.TrimSpace(k))
		if len(k) != 32 || !hexOnly.MatchString(k) {
			return
		}
		out[k] = struct{}{}
	}

	trimmed := strings.TrimSpace(rawKey)
	if trimmed == "" {
		return nil
	}

	noPrefix := trimmed
	if len(trimmed) >= 2 && (strings.HasPrefix(trimmed, "0x") || strings.HasPrefix(trimmed, "0X")) {
		noPrefix = trimmed[2:]
	}

	compact := strings.Map(func(r rune) rune {
		if (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F') {
			return r
		}
		return -1
	}, noPrefix)
	addHex(compact)

	if b, err := base64.StdEncoding.DecodeString(strings.ReplaceAll(noPrefix, " ", "")); err == nil {
		addHex(hex.EncodeToString(b))
	}

	addHex(noPrefix)
	if len(trimmed) == 32 || len(trimmed) == 16 {
		addHex(trimmed)
	}

	if len(out) == 0 {
		return nil
	}
	res := make([]string, 0, len(out))
	for k := range out {
		res = append(res, k)
	}
	return res
}

// isPlainAudioFile reports whether [path] starts with a recognizable plain
// audio container header: FLAC ("fLaC"), MP3 ("ID3"), Ogg/Opus ("OggS") or
// WAV ("RIFF"). Providers sometimes mark a download as encrypted and supply a
// decryption key even when the served stream is actually a plain, playable
// file (e.g. amazon/zarz returning a plain FLAC with a stale key). Such files
// must be served directly — feeding them to the mov-key decryptor only fails
// with "moov atom not found" because there is no MP4 to decrypt.
func isPlainAudioFile(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 4)
	n, _ := f.Read(buf)
	if n < 4 {
		return false
	}
	head := string(buf[:n])
	// Prefix match: ID3's 4th byte is the tag version, and MP4 ("ftyp") must
	// never match these plain-audio magics.
	switch {
	case strings.HasPrefix(head, "fLaC"),
		strings.HasPrefix(head, "ID3"),
		strings.HasPrefix(head, "OggS"),
		strings.HasPrefix(head, "RIFF"):
		return true
	}
	return false
}

// decryptStream decrypts an encrypted/DRM stream file ([inputPath]) with
// ffmpeg's -decryption_key into a playable file in [outDir], returning the
// decrypted path. [outExt] selects the output container (".flac" for flac
// content, ".mp4" for eac3/ac4/opus); empty defaults to ".mp4". [inFormat]
// forces the MOV/MP4 demuxer (the input may carry a .flac name while actually
// holding an encrypted MP4), so any provider's encrypted download decrypts
// correctly. On any failure it removes partial output and returns an error so
// the caller can fall back (reject this provider, try the next one).
func decryptStream(inputPath, key, outDir, outExt, inFormat string) (string, error) {
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
	if inFormat == "" {
		inFormat = "mov"
	}
	base := strings.TrimSuffix(filepath.Base(inputPath), filepath.Ext(inputPath))
	if base == "" {
		base = "track"
	}

	keys := decryptionKeyCandidates(key)
	for i, k := range keys {
		outFile := filepath.Join(outDir, fmt.Sprintf("%s.decrypted%s", base, outExt))
		if i > 0 {
			outFile = filepath.Join(outDir, fmt.Sprintf("%s.decrypted%d%s", base, i, outExt))
		}
		args := []string{
			"-y",
			"-decryption_key", k,
			"-f", inFormat,
			"-i", inputPath,
			"-map", "0:a",
			"-c", "copy",
			outFile,
		}
		log.Printf("[decrypt] ffmpeg cmd: %s %s", bin, strings.Join(args, " "))
		cmd := exec.Command(bin, args...)
		output, err := cmd.CombinedOutput()
		if err == nil {
			// Validate minimum output file size (10KB) to catch empty/truncated outputs
			if info, serr := os.Stat(outFile); serr == nil && info.Size() < 10240 {
				log.Printf("[decrypt] output too small (%d bytes), treating as failure", info.Size())
				_ = os.Remove(outFile)
				if i == len(keys)-1 {
					return "", fmt.Errorf("descifrado ffmpeg output demasiado pequeño: %d bytes (%s): %s", info.Size(), fileFingerprint(inputPath), string(output))
				}
				continue
			}
			log.Printf("[decrypt] success: %s (%d bytes)", outFile, func() int64 {
				if info, err := os.Stat(outFile); err == nil { return info.Size() }; return 0
			}())
			return outFile, nil
		}
		log.Printf("[decrypt] attempt %d failed: %s", i, string(output))
		_ = os.Remove(outFile)
		if i == len(keys)-1 {
			return "", fmt.Errorf("descifrado ffmpeg fallido: %s (%s): %w", string(output), fileFingerprint(inputPath), err)
		}
	}
	return "", fmt.Errorf("sin clave para descifrar")
}

// fileFingerprint summarizes a file for diagnostics: its size plus the first
// 16 bytes as hex, so a failed decrypt shows what was actually downloaded
// (a valid encrypted MP4 starts with "0000001866747970" i.e. an ftyp box;
// an HTML error page, a plain FLAC ("664c6143"), or a truncated file are
// immediately recognizable).
func fileFingerprint(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Sprintf("size? open: %v", err)
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return fmt.Sprintf("size? stat: %v", err)
	}
	buf := make([]byte, 16)
	n, _ := f.Read(buf)
	return fmt.Sprintf("size=%d head=%s", st.Size(), hex.EncodeToString(buf[:n]))
}
