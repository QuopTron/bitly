package metadata

import (
	"fmt"

	flac "github.com/go-flac/go-flac/v2"
	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

// EmbedLyrics embeds lyrics into a FLAC file.
func EmbedLyrics(filePath string, lyrics string) error {
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

	setComment(cmt, "LYRICS", lyrics)
	setComment(cmt, "UNSYNCEDLYRICS", lyrics)

	cmtBlock := cmt.Marshal()
	if cmtIdx >= 0 {
		f.Meta[cmtIdx] = &cmtBlock
	} else {
		f.Meta = append(f.Meta, &cmtBlock)
	}
	return f.Save(filePath)
}

// EmbedGenreLabel embeds genre and label tags into a FLAC file.
func EmbedGenreLabel(filePath string, genre, label string) error {
	if genre == "" && label == "" {
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

	if genre != "" {
		setComment(cmt, "GENRE", genre)
	}
	if label != "" {
		setComment(cmt, "ORGANIZATION", label)
	}

	cmtBlock := cmt.Marshal()
	if cmtIdx >= 0 {
		f.Meta[cmtIdx] = &cmtBlock
	} else {
		f.Meta = append(f.Meta, &cmtBlock)
	}
	return f.Save(filePath)
}
