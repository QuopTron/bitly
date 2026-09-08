package streaming

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func GetStreamPackage(
	reg *provider.Registry,
	lyricsClient *lyrics.Client,
	preferredProvider, trackID, quality string,
	fetchLyrics bool, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID string,
) (*StreamPackage, error) {
	if reg == nil {
		return nil, fmt.Errorf("no inicializado")
	}
	if quality == "" {
		quality = "FLAC"
	}

	track := obtenerMetadata(reg, preferredProvider, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID)
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
	if preferredProvider != "" && esProviderStreaming(preferredProvider) {
		url, err := intentarStream(reg, preferredProvider, trackID, track, quality)
		if err == nil && url != "" {
			streamURL = url
			streamProvider = preferredProvider
		}
	}

	if streamURL == "" {
		url, prov, attempted, verified := rescueStream(reg, track, trackName, artistName, quality)
		if url != "" {
			streamURL = url
			streamProvider = prov
		} else if verified {
			return nil, &VerifyRequiredError{Service: prov}
		} else if len(attempted) > 0 {
			return nil, fmt.Errorf("no se encontro stream en: %s", strings.Join(attempted, ", "))
		}
	}

	if streamURL == "" {
		return nil, fmt.Errorf("no se encontro stream en ningun proveedor")
	}

	// Reject a non-playable result (local path to an encrypted/DRM file) so the
	// player never loops "Error decoding audio"; only http(s) URLs stream.
	if !esURLReproducible(streamURL) {
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

// metadata by identity across the noisiest per-track requests. It is a plain
// LRU/TTL map keyed by the feed track's stable identity so repeated
// resolutions (prefetch on every screen, queue neighbours, re-taps) resolve the
// FIRST time and then serve the cached track — instead of name-searching every
// provider again per request, which is what burned provider rate limits (429)
// Durante largo browsing sesiones.
