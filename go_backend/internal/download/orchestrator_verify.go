package download

import (
	"regexp"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// durationMatches bounds how much a candidate's length may diverge from the
// requested track before it is rejected. A cover, remix, extended or acoustic
// version of the "same" song almost always differs by more than this from the
// album version, so an unusually long/short match is a strong wrong-version
// signal even when title/artist happen to align.
func duracionCoincide(queryDurationMS, got int) bool {
	if queryDurationMS <= 0 || got <= 0 {
		return true
	}
	diff := queryDurationMS - got
	if diff < 0 {
		diff = -diff
	}
	tol := queryDurationMS / 4
	if tol < 20000 {
		tol = 20000
	}
	return diff <= tol
}

// confirmDownloadMatch reverse-verifies, before downloading, that a track id
// resolved for a NON-owner provider is the ORIGINAL requested track. It rejects
// only when we can CONFIRM it is a different song — an explicit ISRC mismatch
// or a weak title/artist match. A candidate with no ISRC at all (typical of
// soundcloud re-uploads) is NOT rejected, because soundcloud never exposes
// ISRC and rejecting it would make every soundcloud-only track unplayable;
// marked variants (remix/live/cover) are already filtered upstream by
// RankOriginalCandidates.
func confirmarMatchDescarga(p provider.Provider, trackID, isrc, queryTitle, queryArtist string, queryDurationMS int) bool {
	t, err := p.GetTrack(trackID)
	if err != nil || t == nil {
		return true
	}
	if isrc != "" && t.ISRC != "" && !strings.EqualFold(strings.ToUpper(isrc), strings.ToUpper(t.ISRC)) {
		return false
	}
	if !duracionCoincide(queryDurationMS, t.Duration) {
		return false
	}
	if queryTitle == "" {
		return true
	}
	if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *t); ok {
		return true
	}
	if t.ISRC != "" {
		if it, err := p.GetTrackByISRC(t.ISRC); err == nil && it != nil {
			if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *it); ok {
				return true
			}
		}
	}
	return false
}

// stripTrackPrefix removes a KNOWN source prefix ("tidal:", "spotify:",
// "deezer:", "qobuz:", "amazon:", ...) from a feed item's id so provider
// GetTrack calls receive the raw native id the extension understands. Only
// known prefixes are stripped — a URL-shaped id ("https://...") or any other
// colon-bearing value is passed through untouched, mirroring the reference
// middleware's trimKnownProviderPrefix behavior.
func quitarPrefijoTrack(id string) string {
	i := strings.IndexByte(id, ':')
	if i <= 0 || i >= len(id)-1 {
		return id
	}
	switch strings.ToLower(id[:i]) {
	case "spotify", "deezer", "tidal", "qobuz", "amazon", "soundcloud", "apple", "youtube":
		return id[i+1:]
	}
	return id
}

// spotifyTrackIDRe matches Spotify's canonical 22-char base62 track IDs.
var spotifyTrackIDRe = regexp.MustCompile(`^[0-9A-Za-z]{22}$`)

// IsSpotifyTrackID reports whether [id] (optionally with a provider prefix
// like "spotify:" or "deezer:") is a well-formed Spotify track ID. Used to
// skip wasted spotify-web getTrack calls when a cross-provider id belongs to
// another service (a deezer/tidal numeric id always throws "Invalid Spotify
// ID character" inside the extension and returns an empty track).
func IsSpotifyTrackID(id string) bool {
	return spotifyTrackIDRe.MatchString(quitarPrefijoTrack(strings.TrimSpace(id)))
}
