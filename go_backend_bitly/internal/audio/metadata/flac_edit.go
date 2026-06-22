package metadata

import (
	"fmt"
	"os"
	"strings"

	flac "github.com/go-flac/go-flac/v2"
	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

// EditFlacFields updates only the Vorbis Comment keys present in the fields map.
// Empty values remove the key; absent keys are left untouched.
func EditFlacFields(filePath string, fields map[string]string) error {
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

	artistMode := fields["artist_tag_mode"]
	editFlacSimpleKeys(cmt, fields)
	editFlacAliasCleanup(cmt, fields)
	editFlacArtistFields(cmt, fields, artistMode)
	editFlacTrackDiscFields(cmt, fields)
	editFlacLyricsField(cmt, fields)

	cmtBlock := cmt.Marshal()
	if cmtIdx >= 0 {
		f.Meta[cmtIdx] = &cmtBlock
	} else {
		f.Meta = append(f.Meta, &cmtBlock)
	}

	coverPath := strings.TrimSpace(fields["cover_path"])
	if coverPath != "" && fileExists(coverPath) {
		coverData, err := os.ReadFile(coverPath)
		if err == nil && len(coverData) > 0 {
			picBlock, err := buildPictureBlock("", coverData)
			if err == nil {
				for i := len(f.Meta) - 1; i >= 0; i-- {
					if f.Meta[i].Type == flac.Picture {
						f.Meta = append(f.Meta[:i], f.Meta[i+1:]...)
					}
				}
				f.Meta = append(f.Meta, &picBlock)
			}
		}
	}

	return f.Save(filePath)
}

func editFlacSimpleKeys(cmt *flacvorbis.MetaDataBlockVorbisComment, fields map[string]string) {
	simpleKeys := map[string]string{
		"title":                 "TITLE",
		"album":                 "ALBUM",
		"date":                  "DATE",
		"isrc":                  "ISRC",
		"genre":                 "GENRE",
		"label":                 "ORGANIZATION",
		"copyright":             "COPYRIGHT",
		"composer":              "COMPOSER",
		"comment":               "COMMENT",
		"replaygain_track_gain": "REPLAYGAIN_TRACK_GAIN",
		"replaygain_track_peak": "REPLAYGAIN_TRACK_PEAK",
		"replaygain_album_gain": "REPLAYGAIN_ALBUM_GAIN",
		"replaygain_album_peak": "REPLAYGAIN_ALBUM_PEAK",
	}
	for fieldKey, vorbisKey := range simpleKeys {
		if v, ok := fields[fieldKey]; ok {
			setOrClearComment(cmt, vorbisKey, v)
		}
	}
}

func editFlacAliasCleanup(cmt *flacvorbis.MetaDataBlockVorbisComment, fields map[string]string) {
	aliasCleanup := map[string][]string{
		"label": {"LABEL", "PUBLISHER"},
		"date":  {"YEAR"},
	}
	for fieldKey, aliases := range aliasCleanup {
		if _, ok := fields[fieldKey]; ok {
			for _, alias := range aliases {
				removeCommentKey(cmt, alias)
			}
		}
	}
}

func editFlacArtistFields(cmt *flacvorbis.MetaDataBlockVorbisComment, fields map[string]string, artistMode string) {
	if v, ok := fields["artist"]; ok {
		setOrClearArtistComments(cmt, "ARTIST", v, artistMode)
	}
	if v, ok := fields["album_artist"]; ok {
		setOrClearArtistComments(cmt, "ALBUMARTIST", v, artistMode)
		removeCommentKey(cmt, "ALBUM ARTIST")
		removeCommentKey(cmt, "ALBUM_ARTIST")
	}
}

func editFlacLyricsField(cmt *flacvorbis.MetaDataBlockVorbisComment, fields map[string]string) {
	if v, ok := fields["lyrics"]; ok {
		if v != "" {
			setOrClearComment(cmt, "LYRICS", v)
			setOrClearComment(cmt, "UNSYNCEDLYRICS", v)
		} else {
			removeCommentKey(cmt, "LYRICS")
			removeCommentKey(cmt, "UNSYNCEDLYRICS")
		}
	}
}
