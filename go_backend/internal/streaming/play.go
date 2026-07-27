package streaming

import (
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// StreamPackage is the complete result for playing a track.
// Incluye metadata, URL de audio, letras y cover para video.
type StreamPackage struct {
	AudioURL string               `json:"audioUrl"`
	VideoURL string               `json:"videoUrl,omitempty"`
	Provider string               `json:"provider"`
	Quality  string               `json:"quality"`
	Track    *provider.TrackResult `json:"track"`
	Lyrics   *lyrics.Lyrics       `json:"lyrics,omitempty"`
}

// streamingProviders are providers that can serve actual audio streams.
// No incluye Spotify, Apple, MusicBrainz (metadata-only).
var streamingProviders = []string{
	"deezer", "qobuz", "tidal", "soundcloud", "youtube",
}

// nonStreamingProviders only provide metadata, no audio streams.
var nonStreamingProviders = []string{
	"spotify", "apple", "musicbrainz",
}

// isStreamingProvider returns true if the provider can stream audio.
func isStreamingProvider(name string) bool {
	for _, p := range streamingProviders {
		if p == name {
			return true
		}
	}
	return false
}

// GetStreamPackage busca metadata + stream URL + letras en una sola llamada.
// Flujo:
// 1. Obtiene metadata del provider preferido (aunque no tenga stream)
//    - Usa GetTrack(trackID) o SearchTracks por nombre
//    - Extrae ISRC para rescate preciso
// 2. Si el provider preferido PUEDE streamear -> intenta GetStreamURL
// 3. Si falla o no puede streamear -> rescata en providers que SI streamean
//    - Primero por ISRC (preciso), luego por nombre
//    - YouTube es el fallback universal (yt-dlp encuentra cualquier cancion)
// 4. Combina metadata del mejor origen + stream URL + letras
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

	// ---- Paso 1: Obtener metadata desde cualquier provider ----
	track := fetchMetadata(reg, preferredProvider, trackID, trackName, artistName)
	if track != nil {
		if trackName == "" {
			trackName = track.Title
		}
		if artistName == "" {
			artistName = track.Artist
		}
	}

	// ---- Paso 2: Intentar stream en provider preferido (si puede streamear) ----
	streamURL := ""
	streamProvider := ""
	if preferredProvider != "" && isStreamingProvider(preferredProvider) {
		url, err := tryStream(reg, preferredProvider, trackID, track, quality)
		if err == nil && url != "" {
			streamURL = url
			streamProvider = preferredProvider
		}
	}

	// ---- Paso 3: Rescate automatico en providers que si streamean ----
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

	// ---- Paso 4: Armar paquete ----
	pkg := &StreamPackage{
		AudioURL: streamURL,
		Provider: streamProvider,
		Quality:  quality,
	}

	// Usar metadata del provider original si existe
	if track != nil {
		pkg.Track = track
	} else if trackName != "" && artistName != "" {
		// Si no hay metadata, intentar obtenerla del provider que dio stream
		p := reg.Get(streamProvider)
		if p != nil {
			results, _ := p.SearchTracks(trackName+" "+artistName, 1)
			if len(results) > 0 {
				pkg.Track = &results[0]
			}
		}
	}

	// ---- Paso 5: Letras (opcional) ----
	if fetchLyrics && lyricsClient != nil && trackName != "" && artistName != "" {
		lyr, err := lyricsClient.GetLyrics(trackName, artistName, 0)
		if err == nil && lyr != nil {
			pkg.Lyrics = lyr
		}
	}

	return pkg, nil
}

// fetchMetadata obtiene metadata del track desde cualquier provider.
// Prioriza el provider preferido, luego busca en todos los demas.
func fetchMetadata(reg *provider.Registry, providerName, trackID, trackName, artistName string) *provider.TrackResult {
	// Buscar en el provider preferido
	if providerName != "" {
		p := reg.Get(providerName)
		if p != nil {
			if track, _ := p.GetTrack(trackID); track != nil {
				return track
			}
			if trackName != "" {
				if results, _ := p.SearchTracks(trackName+" "+artistName, 1); len(results) > 0 {
					return &results[0]
				}
			}
		}
	}

	// Buscar en todos los demas providers
	allProviders := append([]string{}, streamingProviders...)
	allProviders = append(allProviders, nonStreamingProviders...)
	for _, name := range allProviders {
		if name == providerName {
			continue
		}
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if trackName != "" {
			if results, _ := p.SearchTracks(trackName+" "+artistName, 1); len(results) > 0 {
				return &results[0]
			}
		}
	}
	return nil
}

// tryStream intenta obtener stream URL de un provider especifico.
// Prueba: trackID, track.ID, ISRC lookup, fallback por nombre.
func tryStream(reg *provider.Registry, name, trackID string, track *provider.TrackResult, quality string) (string, error) {
	p := reg.Get(name)
	if p == nil {
		return "", fmt.Errorf("proveedor no encontrado: %s", name)
	}

	// 1. Intentar con el trackID original
	if url, _ := p.GetStreamURL(trackID, quality); url != "" {
		return url, nil
	}

	// 2. Intentar con el ID del track encontrado (si es distinto)
	if track != nil && track.ID != "" && track.ID != trackID {
		if url, _ := p.GetStreamURL(track.ID, quality); url != "" {
			return url, nil
		}
	}

	// 3. Buscar por ISRC en el mismo provider
	if track != nil && track.ISRC != "" {
		if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil {
			if url, _ := p.GetStreamURL(trackByISRC.ID, quality); url != "" {
				return url, nil
			}
		}
	}

	return "", fmt.Errorf("stream no disponible en %s", name)
}

// rescueStream busca un stream URL en TODOS los providers que streamean.
// Orden: Deezer, Qobuz, Tidal, SoundCloud, YouTube (fallback universal).
// Usa ISRC si esta disponible, sino busca por nombre de cancion + artista.
// Retorna: url, providerName, attemptedProviders
func rescueStream(reg *provider.Registry, track *provider.TrackResult, trackName, artistName, quality string) (string, string, []string) {
	var attempted []string
	for _, name := range streamingProviders {
		p := reg.Get(name)
		if p == nil {
			continue
		}

		// A: Buscar por ISRC (mas preciso)
		if track != nil && track.ISRC != "" {
			if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil {
				if url, _ := p.GetStreamURL(trackByISRC.ID, quality); url != "" {
					return url, name, nil
				}
				attempted = append(attempted, name+"(ISRC)")
				continue
			}
		}

		// B: Buscar por nombre
		if trackName != "" && artistName != "" {
			if results, err := p.SearchTracks(trackName+" "+artistName, 1); err == nil && len(results) > 0 {
				if url, _ := p.GetStreamURL(results[0].ID, quality); url != "" {
					return url, name, nil
				}
				attempted = append(attempted, name+"(buscado)")
				continue
			}
		}

		attempted = append(attempted, name)
	}
	return "", "", attempted
}
