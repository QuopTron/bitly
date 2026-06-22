package metadata

import (
	"regexp"
	"strings"

	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

const artistTagModeSplitVorbis = "split_vorbis"

var artistTagSplitPattern = regexp.MustCompile(`\s*(?:,|&|\bx\b)\s*|\s+\b(?:feat(?:uring)?|ft|with)\.?\s*`)

func shouldSplitVorbisArtistTags(mode string) bool {
	return strings.EqualFold(strings.TrimSpace(mode), artistTagModeSplitVorbis)
}

func splitArtistTagValues(rawArtists string) []string {
	trimmed := strings.TrimSpace(rawArtists)
	if trimmed == "" {
		return nil
	}
	parts := artistTagSplitPattern.Split(trimmed, -1)
	values := make([]string, 0, len(parts))
	seen := make(map[string]struct{}, len(parts))
	for _, part := range parts {
		artist := strings.TrimSpace(part)
		if artist == "" {
			continue
		}
		key := strings.ToLower(artist)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		values = append(values, artist)
	}
	if len(values) > 0 {
		return values
	}
	return []string{trimmed}
}

func joinVorbisCommentValues(values []string) string {
	if len(values) == 0 {
		return ""
	}
	joined := make([]string, 0, len(values))
	seen := make(map[string]struct{}, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		key := strings.ToLower(trimmed)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		joined = append(joined, trimmed)
	}
	return strings.Join(joined, ", ")
}

func setArtistComments(cmt *flacvorbis.MetaDataBlockVorbisComment, key, value, mode string) {
	if value == "" {
		return
	}
	vals := []string{value}
	if shouldSplitVorbisArtistTags(mode) {
		vals = splitArtistTagValues(value)
	}
	if len(vals) == 0 {
		return
	}
	removeCommentKey(cmt, key)
	for _, artist := range vals {
		if strings.TrimSpace(artist) == "" {
			continue
		}
		cmt.Comments = append(cmt.Comments, key+"="+artist)
	}
}

func setOrClearArtistComments(cmt *flacvorbis.MetaDataBlockVorbisComment, key, value, mode string) {
	if value == "" {
		removeCommentKey(cmt, key)
		return
	}
	vals := []string{value}
	if shouldSplitVorbisArtistTags(mode) {
		vals = splitArtistTagValues(value)
	}
	if len(vals) == 0 {
		removeCommentKey(cmt, key)
		return
	}
	removeCommentKey(cmt, key)
	for _, artist := range vals {
		if strings.TrimSpace(artist) == "" {
			continue
		}
		cmt.Comments = append(cmt.Comments, key+"="+artist)
	}
}
