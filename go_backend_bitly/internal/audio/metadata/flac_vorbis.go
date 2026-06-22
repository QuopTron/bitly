package metadata

import (
	"strings"

	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

func setComment(cmt *flacvorbis.MetaDataBlockVorbisComment, key, value string) {
	if value == "" {
		return
	}
	removeCommentKey(cmt, key)
	cmt.Comments = append(cmt.Comments, key+"="+value)
}

func setOrClearComment(cmt *flacvorbis.MetaDataBlockVorbisComment, key, value string) {
	if value == "" {
		removeCommentKey(cmt, key)
		return
	}
	removeCommentKey(cmt, key)
	cmt.Comments = append(cmt.Comments, key+"="+value)
}

func removeCommentKey(cmt *flacvorbis.MetaDataBlockVorbisComment, key string) {
	keyUpper := strings.ToUpper(key)
	for i := len(cmt.Comments) - 1; i >= 0; i-- {
		comment := cmt.Comments[i]
		eqIdx := strings.Index(comment, "=")
		if eqIdx > 0 {
			existingKey := strings.ToUpper(comment[:eqIdx])
			if existingKey == keyUpper {
				cmt.Comments = append(cmt.Comments[:i], cmt.Comments[i+1:]...)
			}
		}
	}
}

func getComment(cmt *flacvorbis.MetaDataBlockVorbisComment, key string) string {
	values := getCommentValues(cmt, key)
	if len(values) == 0 {
		return ""
	}
	return values[0]
}

func getJoinedComment(cmt *flacvorbis.MetaDataBlockVorbisComment, key string) string {
	return joinVorbisCommentValues(getCommentValues(cmt, key))
}

func getCommentValues(cmt *flacvorbis.MetaDataBlockVorbisComment, key string) []string {
	keyUpper := strings.ToUpper(key) + "="
	values := make([]string, 0, 1)
	for _, comment := range cmt.Comments {
		if len(comment) > len(key) {
			commentUpper := strings.ToUpper(comment[:len(key)+1])
			if commentUpper == keyUpper {
				values = append(values, comment[len(key)+1:])
			}
		}
	}
	return values
}
