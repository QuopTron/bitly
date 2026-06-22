package metadata

import (
	"strings"
)

// APEKeysFromFields builds a set of upper-case APE tag keys corresponding to
// the metadata fields map sent by the editor.
func APEKeysFromFields(fields map[string]string) map[string]struct{} {
	mapping := map[string]string{
		"title":                 "TITLE",
		"artist":                "ARTIST",
		"album":                 "ALBUM",
		"album_artist":          "ALBUM ARTIST",
		"date":                  "DATE",
		"genre":                 "GENRE",
		"track_number":          "TRACK",
		"disc_number":           "DISC",
		"isrc":                  "ISRC",
		"lyrics":                "LYRICS",
		"label":                 "LABEL",
		"copyright":             "COPYRIGHT",
		"composer":              "COMPOSER",
		"comment":               "COMMENT",
		"replaygain_track_gain": "REPLAYGAIN_TRACK_GAIN",
		"replaygain_track_peak": "REPLAYGAIN_TRACK_PEAK",
		"replaygain_album_gain": "REPLAYGAIN_ALBUM_GAIN",
		"replaygain_album_peak": "REPLAYGAIN_ALBUM_PEAK",
	}
	result := make(map[string]struct{})
	for fk, apeKey := range mapping {
		if _, present := fields[fk]; present {
			result[strings.ToUpper(apeKey)] = struct{}{}
		}
	}
	if _, present := fields["date"]; present {
		result["DATE"] = struct{}{}
	}
	if _, present := fields["disc_number"]; present {
		result["DISCNUMBER"] = struct{}{}
	}
	if _, present := fields["disc_total"]; present {
		result["DISCNUMBER"] = struct{}{}
	}
	if _, present := fields["track_number"]; present {
		result["TRACKNUMBER"] = struct{}{}
	}
	if _, present := fields["track_total"]; present {
		result["TRACKNUMBER"] = struct{}{}
	}
	if _, present := fields["album_artist"]; present {
		result["ALBUMARTIST"] = struct{}{}
	}
	if _, present := fields["label"]; present {
		result["PUBLISHER"] = struct{}{}
	}
	if _, present := fields["lyrics"]; present {
		result["UNSYNCEDLYRICS"] = struct{}{}
	}
	return result
}

// MergeAPEItems overlays newItems on top of existing items.
func MergeAPEItems(existing, newItems []APETagItem, overrideKeys map[string]struct{}) []APETagItem {
	combined := make(map[string]struct{}, len(newItems)+len(overrideKeys))
	for k := range overrideKeys {
		combined[strings.ToUpper(k)] = struct{}{}
	}
	for _, item := range newItems {
		combined[strings.ToUpper(item.Key)] = struct{}{}
	}
	var merged []APETagItem
	for _, item := range existing {
		if _, overwritten := combined[strings.ToUpper(item.Key)]; !overwritten {
			merged = append(merged, item)
		}
	}
	merged = append(merged, newItems...)
	return merged
}
