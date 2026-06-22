package lyrics

import "fmt"

func (c *LyricsClient) tryLRCLIB(primaryArtist, artistName, trackName, simplifiedTrack string, durationSec float64) (*LyricsResponse, error) {
	tryFetch := func(artist, track string) (*LyricsResponse, bool) {
		l, err := c.FetchLyricsWithMetadata(artist, track)
		return l, err == nil && l != nil && (len(l.Lines) > 0 || l.Instrumental)
	}

	if l, ok := tryFetch(primaryArtist, trackName); ok {
		l.Source = "LRCLIB"
		return l, nil
	}
	if primaryArtist != artistName {
		if l, ok := tryFetch(artistName, trackName); ok {
			l.Source = "LRCLIB"
			return l, nil
		}
	}
	if simplifiedTrack != trackName {
		if l, ok := tryFetch(primaryArtist, simplifiedTrack); ok {
			l.Source = "LRCLIB (simplified)"
			return l, nil
		}
	}

	query := primaryArtist + " " + trackName
	if l, err := c.FetchLyricsFromLRCLibSearch(query, durationSec); err == nil && (len(l.Lines) > 0 || l.Instrumental) {
		l.Source = "LRCLIB Search"
		return l, nil
	}
	if simplifiedTrack != trackName {
		query = primaryArtist + " " + simplifiedTrack
		if l, err := c.FetchLyricsFromLRCLibSearch(query, durationSec); err == nil && (len(l.Lines) > 0 || l.Instrumental) {
			l.Source = "LRCLIB Search (simplified)"
			return l, nil
		}
	}
	return nil, fmt.Errorf("LRCLIB: no lyrics found")
}
