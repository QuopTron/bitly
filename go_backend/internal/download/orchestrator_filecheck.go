package download

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// isPlayableCachedFile validates that [path] holds an audio file media_kit can
// decode. The file's extension must MATCH the actual container: providers have
// produced mp4 containers labeled .flac (encrypted or with corrupt flac frames)
// that decode into silence/errors, and re-serving those would block playback
// forever. mp4/m4a files are additionally rejected when they carry a protection
// de proteccion (sinf/enca/encv) o una marca de cifrado comun (cmfc/cenc) —
// esas necesitan una clave + ffmpeg y nunca podrian decodificarse en el reproductor.
func esArchivoCacheReproducible(path string) bool {
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(path), "."))
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	head := make([]byte, 16)
	n, err := io.ReadFull(f, head)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return false
	}
	head = head[:n]
	switch ext {
	case "flac":
		return bytes.HasPrefix(head, []byte("fLaC"))
	case "mp3":
		return bytes.HasPrefix(head, []byte("ID3")) ||
			(len(head) >= 2 && head[0] == 0xFF && head[1]&0xE0 == 0xE0)
	case "ogg", "opus":
		return bytes.HasPrefix(head, []byte("OggS"))
	case "wav":
		return bytes.HasPrefix(head, []byte("RIFF"))
	case "m4a", "mp4", "aac", "m4b":
		if len(head) < 8 || !bytes.HasPrefix(head[4:], []byte("ftyp")) {
			return false
		}
		if bytes.Contains(head, []byte("cmfc")) || bytes.Contains(head, []byte("cenc")) {
			return false
		}
		return !archivoContieneAlguno(path, []byte("sinf"), []byte("enca"), []byte("encv"))
	}
	return false
}

// fileContainsAny reports whether any needle occurs anywhere in the file,
// scanning in bounded 64KiB chunks (with overlap) so large cached files are
// checked without being loaded fully into memory.
func archivoContieneAlguno(path string, needles ...[]byte) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	maxNeedle := 0
	for _, needle := range needles {
		if len(needle) > maxNeedle {
			maxNeedle = len(needle)
		}
	}
	if maxNeedle == 0 {
		return false
	}
	const chunkSize = 64 * 1024
	buf := make([]byte, chunkSize+maxNeedle)
	carry := 0
	for {
		n, err := f.Read(buf[carry:])
		total := carry + n
		if total > 0 {
			for _, needle := range needles {
				if bytes.Contains(buf[:total], needle) {
					return true
				}
			}
		}
		if err != nil {
			return false
		}
		keep := maxNeedle - 1
		if total >= keep {
			copy(buf, buf[total-keep:total])
			carry = keep
		} else {
			carry = total
		}
	}
}

// detectExt infers a file extension from a stream URL's query or path.
func detectarExt(urlStr string) string {
	lower := strings.ToLower(urlStr)
	switch {
	case strings.Contains(lower, ".flac"):
		return ".flac"
	case strings.Contains(lower, ".mp3"):
		return ".mp3"
	case strings.Contains(lower, ".m4a"):
		return ".m4a"
	case strings.Contains(lower, ".opus"):
		return ".opus"
	case strings.Contains(lower, ".ogg"):
		return ".ogg"
	default:
		return ".mp3"
	}
}
