package streaming

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// StreamPackage is the complete result for playing a track.
type StreamPackage struct {
	AudioURL string               `json:"audioUrl"`
	VideoURL string               `json:"videoUrl,omitempty"`
	Provider string               `json:"provider"`
	Quality  string               `json:"quality"`
	Track    *provider.TrackResult `json:"track"`
	Lyrics   *lyrics.Lyrics       `json:"lyrics,omitempty"`
}

// streamingProviders can serve actual audio streams. Includes both native
// names and their bundled -web extension equivalents: after extensions load,
// qobuz/tidal/etc. register under "qobuz-web"/"tidal-web" (and apple-music,
// amazon), so the hardcoded native names alone would silently skip real
// sources during rescue.
var streamingProviders = []string{
	"youtube", "deezer", "soundcloud", "qobuz", "tidal",
	"qobuz-web", "tidal-web", "spotify-web", "apple-music", "amazon",
	"ytmusic-spotiflac",
}

// isPlayableStreamProvider returns true if the provider can stream audio.
func isStreamingProvider(name string) bool {
	for _, p := range streamingProviders {
		if p == name {
			return true
		}
	}
	return false
}

// isPlayableStreamURL reports whether a resolved "stream URL" is actually
// streamable by the player. Some providers (amazon/qobuz DRM) return a local
// path to an encrypted file instead of an http stream — media_kit cannot decode
// that and would loop "Error decoding audio". Only http(s) URLs are playable.
func isPlayableStreamURL(u string) bool {
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://")
}

// GetStreamPackage busca metadata + stream URL + letras en una sola llamada.
func GetStreamPackage(
	reg *provider.Registry,
	lyricsClient *lyrics.Client,
	preferredProvider, trackID, quality string,
	fetchLyrics bool, trackName, artistName string,
) (*StreamPackage, error) {
	if reg == nil {
		return nil, fmt.Errorf("no inicializado")
	}
	if quality == "" {
		quality = "FLAC"
	}

	track := fetchMetadata(reg, preferredProvider, trackID, trackName, artistName)
	if track != nil {
		if trackName == "" {
			trackName = track.Title
		}
		if artistName == "" {
			artistName = track.Artist
		}
	}

	streamURL := ""
	streamProvider := ""
	if preferredProvider != "" && isStreamingProvider(preferredProvider) {
		url, err := tryStream(reg, preferredProvider, trackID, track, quality)
		if err == nil && url != "" {
			streamURL = url
			streamProvider = preferredProvider
		}
	}

	if streamURL == "" {
		url, prov, attempted := rescueStream(reg, track, trackName, artistName, quality)
		if url != "" {
			streamURL = url
			streamProvider = prov
		} else if len(attempted) > 0 {
			return nil, fmt.Errorf("no se encontro stream en: %s", strings.Join(attempted, ", "))
		}
	}

	if streamURL == "" {
		return nil, fmt.Errorf("no se encontro stream en ningun proveedor")
	}

	// Reject a non-playable result (local path to an encrypted/DRM file) so the
	// player never loops "Error decoding audio"; only http(s) URLs stream.
	if !isPlayableStreamURL(streamURL) {
		return nil, fmt.Errorf("stream no reproducible en %s (encriptado)", streamProvider)
	}

	pkg := &StreamPackage{
		AudioURL: streamURL,
		Provider: streamProvider,
		Quality:  quality,
	}

	if track != nil {
		pkg.Track = track
	} else if trackName != "" && artistName != "" {
p := reg.Get(streamProvider)
			if p != nil {
				if results, _ := p.SearchTracks(trackName+" "+artistName, 8); len(results) > 0 {
					if best := provider.BestOriginal(trackName, artistName, results); best != nil {
						pkg.Track = best
					}
				}
			}
	}

	if fetchLyrics && lyricsClient != nil && trackName != "" && artistName != "" {
		lyr, err := lyricsClient.GetLyrics(trackName, artistName, 0)
		if err == nil && lyr != nil {
			pkg.Lyrics = lyr
		}
	}

	return pkg, nil
}

// fetchMetadata obtiene metadata del track desde cualquier provider.
func fetchMetadata(reg *provider.Registry, providerName, trackID, trackName, artistName string) *provider.TrackResult {
	if providerName != "" {
		p := reg.Get(providerName)
		if p != nil {
			if track, _ := p.GetTrack(trackID); track != nil {
				return track
			}
			if trackName != "" {
				if results, _ := p.SearchTracks(trackName+" "+artistName, 8); len(results) > 0 {
					if best := provider.BestOriginal(trackName, artistName, results); best != nil {
						return best
					}
				}
			}
		}
	}

	allProviders := append([]string{}, streamingProviders...)
	allProviders = append(allProviders, "spotify", "apple", "musicbrainz")
	for _, name := range allProviders {
		if name == providerName {
			continue
		}
		p := reg.Get(name)
		if p == nil || trackName == "" {
			continue
		}
		if results, _ := p.SearchTracks(trackName+" "+artistName, 8); len(results) > 0 {
			if best := provider.BestOriginal(trackName, artistName, results); best != nil {
				return best
			}
		}
	}
	return nil
}
