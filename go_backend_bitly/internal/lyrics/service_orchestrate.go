package lyrics

import (
	"fmt"
	"regexp"
)

var instrumentalTrackPattern = regexp.MustCompile(`(?i)(?:^|[\s\[\(\-])(?:instrumental|inst\.?)(?:[\s\])]|$)`)

func tryArtistFallback(fetch func(artist, track string) (*LyricsResponse, error), primaryArtist, artistName, trackName, simplifiedTrack string) (*LyricsResponse, error) {
	lyrics, err := fetch(primaryArtist, trackName)
	if err == nil {
		return lyrics, nil
	}
	if primaryArtist != artistName {
		lyrics, err = fetch(artistName, trackName)
		if err == nil {
			return lyrics, nil
		}
	}
	if simplifiedTrack != trackName {
		lyrics, err = fetch(primaryArtist, simplifiedTrack)
		if err == nil {
			return lyrics, nil
		}
	}
	return nil, err
}

func (c *LyricsClient) FetchLyricsAllSources(spotifyID, trackName, artistName string, durationSec float64) (*LyricsResponse, error) {
	primaryArtist := NormalizeArtistName(artistName)
	fetchOptions := GetLyricsFetchOptions()

	if isLikelyInstrumentalTrack(trackName) {
		instrumental := &LyricsResponse{
			Instrumental: true,
			Source:       "Heuristic: Instrumental",
		}
		globalLyricsCache.Set(artistName, trackName, durationSec, instrumental)
		return instrumental, nil
	}

	if cached, found := globalLyricsCache.Get(artistName, trackName, durationSec); found {
		cp := *cached
		cp.Source = cached.Source + " (cached)"
		return &cp, nil
	}

	providerOrder := GetLyricsProviderOrder()
	simplifiedTrack := SimplifyTrackName(trackName)

	for _, providerName := range providerOrder {
		var lyrics *LyricsResponse
		var err error

		switch providerName {
		case ProviderLRCLIB:
			lyrics, err = c.tryLRCLIB(primaryArtist, artistName, trackName, simplifiedTrack, durationSec)

		case ProviderNetease:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewNeteaseClient().FetchLyrics(track, artist, durationSec, fetchOptions.IncludeTranslationNetease, fetchOptions.IncludeRomanizationNetease)
			}, primaryArtist, artistName, trackName, simplifiedTrack)

		case ProviderMusixmatch:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewMusixmatchClient().FetchLyrics(track, artist, durationSec, fetchOptions.MusixmatchLanguage)
			}, primaryArtist, artistName, trackName, trackName)

		case ProviderAppleMusic:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewAppleMusicClient().FetchLyrics(track, artist, durationSec, fetchOptions.MultiPersonWordByWord, fetchOptions.AppleElrcWordSync)
			}, primaryArtist, artistName, trackName, trackName)

		case ProviderQQMusic:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewQQMusicClient().FetchLyrics(track, artist, durationSec, fetchOptions.MultiPersonWordByWord)
			}, primaryArtist, artistName, trackName, trackName)

		case ProviderSpotify:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewSpotifyLyricsClient().FetchLyrics(spotifyID, track, artist, durationSec)
			}, primaryArtist, artistName, trackName, simplifiedTrack)

		case ProviderDeezer:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewDeezerLyricsClient().FetchLyrics(spotifyID, track, artist, durationSec)
			}, primaryArtist, artistName, trackName, trackName)

		case ProviderYouTube:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewYouTubeLyricsClient().FetchLyrics(track, artist, durationSec)
			}, primaryArtist, artistName, trackName, simplifiedTrack)

		case ProviderKugou:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewKugouLyricsClient().FetchLyrics(track, artist, durationSec)
			}, primaryArtist, artistName, trackName, simplifiedTrack)

		case ProviderGenius:
			lyrics, err = tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
				return NewGeniusLyricsClient().FetchLyrics(track, artist, durationSec)
			}, primaryArtist, artistName, trackName, simplifiedTrack)

		default:
			continue
		}

		if err == nil && LyricsHasUsableText(lyrics) {
			globalLyricsCache.Set(artistName, trackName, durationSec, lyrics)
			return lyrics, nil
		}
	}

	return nil, fmt.Errorf("lyrics not found from any source")
}
