package metadata

import (
	flacvorbis "github.com/go-flac/flacvorbis/v2"
)

func editFlacTrackDiscFields(cmt *flacvorbis.MetaDataBlockVorbisComment, fields map[string]string) {
	if _, ok := fields["track_number"]; ok || hasMapKey(fields, "track_total") {
		currentNum, currentTotal := ParseIndexPair(getComment(cmt, "TRACKNUMBER"))
		if currentNum == 0 && currentTotal == 0 {
			currentNum, currentTotal = ParseIndexPair(getComment(cmt, "TRACK"))
		}
		if v, ok := fields["track_number"]; ok {
			currentNum = ParsePositiveInt(v)
		}
		if v, ok := fields["track_total"]; ok {
			currentTotal = ParsePositiveInt(v)
		}
		if currentNum > 0 {
			setOrClearComment(cmt, "TRACKNUMBER", FormatIndexValue(currentNum, currentTotal))
		} else {
			removeCommentKey(cmt, "TRACKNUMBER")
		}
		removeCommentKey(cmt, "TRACK")
	}
	if _, ok := fields["disc_number"]; ok || hasMapKey(fields, "disc_total") {
		currentNum, currentTotal := ParseIndexPair(getComment(cmt, "DISCNUMBER"))
		if currentNum == 0 && currentTotal == 0 {
			currentNum, currentTotal = ParseIndexPair(getComment(cmt, "DISC"))
		}
		if v, ok := fields["disc_number"]; ok {
			currentNum = ParsePositiveInt(v)
		}
		if v, ok := fields["disc_total"]; ok {
			currentTotal = ParsePositiveInt(v)
		}
		if currentNum > 0 {
			setOrClearComment(cmt, "DISCNUMBER", FormatIndexValue(currentNum, currentTotal))
		} else {
			removeCommentKey(cmt, "DISCNUMBER")
		}
		removeCommentKey(cmt, "DISC")
	}
}
