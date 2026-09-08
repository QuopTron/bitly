package download

import (
	"log"
	"os"
	"strings"
)

func esArchivoAudioPlano(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 12)
	n, _ := f.Read(buf)
	if n < 4 {
		return false
	}
	head := string(buf[:4])
	switch {
	case strings.HasPrefix(head, "fLaC"),
		strings.HasPrefix(head, "ID3"),
		strings.HasPrefix(head, "OggS"),
		strings.HasPrefix(head, "RIFF"):
		return true
	}
	// MP4/M4A container: [size:4][ftyp:4][brand:...] — ftyp is at offset 4.
	if n >= 8 && string(buf[4:8]) == "ftyp" {
		return true
	}
	return false
}

// isPlayableAudioFile validates that a file on disk is a real playable audio
// container. Rejects MPEG-TS streams disguised as .mp3 (SoundCloud HLS),
// zero-byte files, and other garbage. Must be called after the file is
// finalized (renamed from .tmp) so the file is complete.
func esArchivoAudioReproducible(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		log.Printf("[playable-check] %s: open error: %v", path, err)
		return false
	}
	defer f.Close()
	buf := make([]byte, 12)
	n, _ := f.Read(buf)
	if n < 4 {
		log.Printf("[playable-check] %s: file too small (%d bytes)", path, n)
		return false
	}
	head := string(buf[:n])
	// Known playable containers
	if strings.HasPrefix(head, "fLaC") || strings.HasPrefix(head, "ID3") ||
		strings.HasPrefix(head, "OggS") || strings.HasPrefix(head, "RIFF") {
		log.Printf("[playable-check] %s: ACCEPTED (head=%q, n=%d)", path, head, n)
		return true
	}
	// MP4/M4A: [size:4][ftyp:4][brand:...] — ftyp is at offset 4, not 0.
	if n >= 8 && string(buf[4:8]) == "ftyp" {
		log.Printf("[playable-check] %s: ACCEPTED (ftyp at offset 4, n=%d)", path, n)
		return true
	}
	// WebM/Matroska (TIDAL .opus)
	if n >= 4 && buf[0] == 0x1A && buf[1] == 0x45 && buf[2] == 0xDF && buf[3] == 0xA3 {
		return true
	}
	// MPEG sync word (MP3 frame sync: 0xFF 0xFB/0xF3/0xF2)
	if n >= 2 && buf[0] == 0xFF && (buf[1]&0xE0) == 0xE0 {
		return true
	}
	// MPEG-TS starts with 0x47 (sync byte) — this is NOT a standalone
	// playable file, it's a transport stream fragment (SoundCloud HLS).
	log.Printf("[playable-check] %s: REJECTED (head=%q hex=%02x%02x%02x%02x, n=%d)", path, head, buf[0], buf[1], buf[2], buf[3], n)
	return false
}

// isHLSManifest checks if a file is an M3U8/HLS playlist manifest instead of
// actual audio. SoundCloud sometimes returns HLS streams whose URL points to a
// text manifest (starting with #EXTM3U or #EXT-X-) rather than binary audio.
// These must NOT be marked as "encrypted for client decrypt" because they are
// not DRM content — they're just playlists pointing to separate segments.
func esManifiestoHLS(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 16)
	n, _ := f.Read(buf)
	if n < 7 {
		return false
	}
	// Busca #EXTM3U (cabecera M3U8) — primeros 7 bytes
	if string(buf[:7]) == "#EXTM3U" {
		return true
	}
	// Busca #EXT-X- (etiquetas de lista HLS variante)
	if n >= 7 && string(buf[:7]) == "#EXT-X-" {
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
// el caller puede fall back (reject este proveedor, try el siguiente uno).
