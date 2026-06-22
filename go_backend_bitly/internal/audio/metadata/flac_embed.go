package metadata

import (
	"fmt"
	"os"

	flac "github.com/go-flac/go-flac/v2"
	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

// EmbedMetadata embeds tags and optional cover art into a FLAC file.
func EmbedMetadata(filePath string, meta Metadata, coverPath string) error {
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

	writeVorbisMeta(cmt, meta)

	cmtBlock := cmt.Marshal()
	if cmtIdx >= 0 {
		f.Meta[cmtIdx] = &cmtBlock
	} else {
		f.Meta = append(f.Meta, &cmtBlock)
	}

	if coverPath != "" {
		if fileExists(coverPath) {
			coverData, err := os.ReadFile(coverPath)
			if err == nil {
				cmtBlock, err := embedCoverBlock(f, coverData)
				if err != nil {
					return err
				}
				f.Meta = append(f.Meta, &cmtBlock)
			}
		}
	}

	return f.Save(filePath)
}

// EmbedMetadataWithCoverData embeds tags and cover data directly.
func EmbedMetadataWithCoverData(filePath string, meta Metadata, coverData []byte) error {
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

	writeVorbisMeta(cmt, meta)

	cmtBlock := cmt.Marshal()
	if cmtIdx >= 0 {
		f.Meta[cmtIdx] = &cmtBlock
	} else {
		f.Meta = append(f.Meta, &cmtBlock)
	}

	if len(coverData) > 0 {
		picBlock, err := buildPictureBlock("", coverData)
		if err != nil {
			return fmt.Errorf("failed to create picture block: %w", err)
		}
		for i := len(f.Meta) - 1; i >= 0; i-- {
			if f.Meta[i].Type == flac.Picture {
				f.Meta = append(f.Meta[:i], f.Meta[i+1:]...)
			}
		}
		f.Meta = append(f.Meta, &picBlock)
	}

	return f.Save(filePath)
}
