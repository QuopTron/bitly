package gobackend

import "encoding/json"

// GetHomeFeed — returns a JSON array of FeedSectionGo grouped by provider
// =========================================================================

// GetSources returns the list of user-facing sources (providers/extensions)
// registered in the backend. Internal metadata/rescue-only providers
// (musicbrainz) and natives superseded by an extension (youtube, replaced by
// ytmusic-spotiflac) are excluded so the UI shows no duplicate/empty bubbles.
func GetSources() string {
	if reg == nil {
		return `[]`
	}
	hidden := map[string]bool{
		"musicbrainz": true, // metadata/rescue only, no feed content
		"youtube":     true, // superseded by the ytmusic-spotiflac extension
	}
	names := make([]string, 0, 12)
	for _, n := range reg.Names() {
		if hidden[n] {
			continue
		}
		names = append(names, n)
	}
	data, err := json.Marshal(names)
	if err != nil {
		return `[]`
	}
	return string(data)
}
