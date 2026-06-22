package metadata

import (
	"bytes"
	"fmt"
	stdimage "image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"strings"

	flac "github.com/go-flac/go-flac/v2"
	flacpicture "github.com/go-flac/flacpicture/v2"
)

// DetectCoverMIME detects the MIME type of cover data via magic bytes.
func DetectCoverMIME(coverPath string, coverData []byte) string {
	if len(coverData) >= 8 && coverData[0] == 0x89 && coverData[1] == 0x50 &&
		coverData[2] == 0x4E && coverData[3] == 0x47 &&
		coverData[4] == 0x0D && coverData[5] == 0x0A &&
		coverData[6] == 0x1A && coverData[7] == 0x0A {
		return "image/png"
	}
	if len(coverData) >= 3 && coverData[0] == 0xFF && coverData[1] == 0xD8 && coverData[2] == 0xFF {
		return "image/jpeg"
	}
	if len(coverData) >= 6 {
		header := string(coverData[:6])
		if header == "GIF87a" || header == "GIF89a" {
			return "image/gif"
		}
	}
	if len(coverData) >= 12 && string(coverData[:4]) == "RIFF" && string(coverData[8:12]) == "WEBP" {
		return "image/webp"
	}

	if coverPath != "" {
		switch {
		case strings.HasSuffix(strings.ToLower(coverPath), ".png"):
			return "image/png"
		case strings.HasSuffix(strings.ToLower(coverPath), ".jpg"),
			strings.HasSuffix(strings.ToLower(coverPath), ".jpeg"):
			return "image/jpeg"
		case strings.HasSuffix(strings.ToLower(coverPath), ".webp"):
			return "image/webp"
		case strings.HasSuffix(strings.ToLower(coverPath), ".gif"):
			return "image/gif"
		}
	}

	return "image/jpeg"
}

func buildPictureBlock(coverPath string, coverData []byte) (flac.MetaDataBlock, error) {
	if len(coverData) == 0 {
		return flac.MetaDataBlock{}, fmt.Errorf("empty cover data")
	}

	mime := DetectCoverMIME(coverPath, coverData)
	picture := &flacpicture.MetadataBlockPicture{
		PictureType: flacpicture.PictureTypeFrontCover,
		MIME:        mime,
		Description: "Front Cover",
		ImageData:   coverData,
	}

	if cfg, format, err := stdimage.DecodeConfig(bytes.NewReader(coverData)); err == nil {
		picture.Width = uint32(cfg.Width)
		picture.Height = uint32(cfg.Height)
		switch format {
		case "png":
			picture.ColorDepth = 32
		case "jpeg":
			picture.ColorDepth = 24
		default:
			picture.ColorDepth = 0
		}
	}

	return picture.Marshal(), nil
}

func embedCoverBlock(f *flac.File, coverData []byte) (flac.MetaDataBlock, error) {
	for i := len(f.Meta) - 1; i >= 0; i-- {
		if f.Meta[i].Type == flac.Picture {
			f.Meta = append(f.Meta[:i], f.Meta[i+1:]...)
		}
	}
	picBlock, err := buildPictureBlock("", coverData)
	if err != nil {
		return flac.MetaDataBlock{}, err
	}
	return picBlock, nil
}

// ExtractCoverArt extracts cover art from a FLAC file.
func ExtractCoverArt(filePath string) ([]byte, error) {
	f, err := flac.ParseFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse FLAC file: %w", err)
	}

	for _, metaBlock := range f.Meta {
		if metaBlock.Type == flac.Picture {
			pic, err := flacpicture.ParseFromMetaDataBlock(*metaBlock)
			if err != nil {
				continue
			}
			if pic.PictureType == flacpicture.PictureTypeFrontCover && len(pic.ImageData) > 0 {
				return pic.ImageData, nil
			}
		}
	}
	for _, metaBlock := range f.Meta {
		if metaBlock.Type == flac.Picture {
			pic, err := flacpicture.ParseFromMetaDataBlock(*metaBlock)
			if err != nil {
				continue
			}
			if len(pic.ImageData) > 0 {
				return pic.ImageData, nil
			}
		}
	}

	return nil, fmt.Errorf("no cover art found in file")
}
