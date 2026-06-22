package metadata

import (
	"fmt"
	"os"

	flac "github.com/go-flac/go-flac/v2"
	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

// RewriteSplitArtistTags opens a FLAC file and rewrites the ARTIST and
// ALBUMARTIST Vorbis comments as multiple separate entries (one per artist).
// This is needed because FFmpeg's -metadata flag deduplicates keys, so only
// the last value survives when multiple -metadata ARTIST=X flags are used.
// The native go-flac writer correctly handles multiple Vorbis comments.
func RewriteSplitArtistTags(filePath, artist, albumArtist string) error {
	if !shouldSplitVorbisArtistTags(artistTagModeSplitVorbis) {
		return nil
	}

	f, err := flac.ParseFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to parse FLAC file: %w", err)
	}

	var cmtIdx int = -1
	var cmt *flacvorbis.MetaDataBlockVorbisComment
	for idx, metaBlock := range f.Meta {
		if metaBlock.Type == flac.VorbisComment {
			cmtIdx = idx
			cmt, err = flacvorbis.ParseFromMetaDataBlock(*metaBlock)
			if err != nil {
				return fmt.Errorf("failed to parse vorbis comment: %w", err)
			}
			break
		}
	}
	if cmt == nil {
		cmt = flacvorbis.New()
	}

	setArtistComments(cmt, "ARTIST", artist, artistTagModeSplitVorbis)
	setArtistComments(cmt, "ALBUMARTIST", albumArtist, artistTagModeSplitVorbis)

	cmtMeta := cmt.Marshal()
	if cmtIdx >= 0 {
		f.Meta[cmtIdx] = &cmtMeta
	} else {
		f.Meta = append(f.Meta, &cmtMeta)
	}

	return f.Save(filePath)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func hasMapKey(fields map[string]string, key string) bool {
	_, ok := fields[key]
	return ok
}
