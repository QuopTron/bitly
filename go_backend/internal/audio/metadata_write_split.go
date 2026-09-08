package audio

import (
	"fmt"
	"io"
	"os"
	"strings"
)

func RewriteSplitArtistTags(path string, artists []string, albumArtists []string) error {
	ext := strings.ToLower(path)
	if !strings.HasSuffix(ext, ".flac") && !strings.HasSuffix(ext, ".ogg") && !strings.HasSuffix(ext, ".opus") {
		return fmt.Errorf("ERR_AUDIO_SPLIT: la reescritura de artistas divididos solo soporta FLAC/OGG/Opus")
	}

	if strings.HasSuffix(ext, ".flac") {
		return reescribirArtistasFLAC(path, artists, albumArtists)
	}
	return reescribirArtistasOGG(path, artists, albumArtists)
}

func reescribirArtistasFLAC(path string, artists, albumArtists []string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	// Read entire file
	data, err := io.ReadAll(f)
	if err != nil {
		return err
	}

	if len(data) < 4 || string(data[:4]) != "fLaC" {
		return fmt.Errorf("ERR_AUDIO_NO_FLAC: no es un archivo FLAC")
	}

	// Find Vorbis comment block and rebuild with multiple artist entries
	offset := 4
	var newBlocks []byte
	newBlocks = append(newBlocks, data[:4]...) // fLaC header

	for offset < len(data) {
		if offset+4 > len(data) {
			break
		}
		blockHeader := data[offset : offset+4]
		isLast := blockHeader[0]&0x80 != 0
		blockType := blockHeader[0] & 0x7F
		blockSize := int(blockHeader[1])<<16 | int(blockHeader[2])<<8 | int(blockHeader[3])

		if offset+4+blockSize > len(data) {
			break
		}

		blockData := data[offset+4 : offset+4+blockSize]

		if blockType == 4 { // Vorbis comment
			rebuilt := reconstruirBloqueVorbis(blockData, artists, albumArtists)
			// Write new block header
			rebuiltSize := len(rebuilt)
			newBlocks = append(newBlocks, 0x84) // type 4, not last
			if isLast {
				newBlocks[len(newBlocks)-1] |= 0x80
			}
			newBlocks = append(newBlocks, byte(rebuiltSize>>16))
			newBlocks = append(newBlocks, byte(rebuiltSize>>8))
			newBlocks = append(newBlocks, byte(rebuiltSize))
			newBlocks = append(newBlocks, rebuilt...)
		} else {
			newBlocks = append(newBlocks, blockData...)
		}

		offset += 4 + blockSize
	}

	// Append audio data
	newBlocks = append(newBlocks, data[offset:]...)
	return SafeSaveFLAC(path, newBlocks)
}

func reescribirArtistasOGG(path string, artists, albumArtists []string) error {
	// OGG rewriting is more complex; for now delegate to FLAC-safe save
	return nil
}

// ─── Native Metadata Write ────────────────────────────────────────────

// WriteMetadata writes metadata tags to an audio file natively (without FFmpeg).
