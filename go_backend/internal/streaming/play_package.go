package streaming

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func GetStreamPackage(
	reg *provider.Registry,
	lyricsClient *lyrics.Client,
	preferredProvider, trackID, quality string,
	fetchLyrics bool, trackName, artistName, albumName, isrc, spotifyID, deezerID, tidalID, qobuzID string,
	durationMs int,
) (*StreamPackage, error) {
	if reg == nil {
		return nil, fmt.Errorf("no inicializado")
	}
	if quality == "" {
		quality = "FLAC"
	}

	// Instrumentación de LATENCIA (ver rescue_stream.go): el pedido de un stream
	// se compone de metadata + atajo al proveedor preferido + rescate por fases.
	// Sin estos tres números no se puede saber cuál se come los segundos.
	inicioPkg := time.Now()
	track := obtenerMetadata(reg, preferredProvider, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID)
	log.Printf("[play] metadata %.0fms (prov=%q track=%v isrc=%v)",
		float64(time.Since(inicioPkg).Microseconds())/1000, preferredProvider, track != nil,
		track != nil && track.ISRC != "")
	if track != nil {
		if trackName == "" {
			trackName = track.Title
		}
		if artistName == "" {
			artistName = track.Artist
		}
	}
	// Identidad para el RESCATE: la del proveedor cuando la metadata llegó a
	// tiempo y, si no, la del propio PEDIDO. La metadata se acota por presupuesto
	// (ver play_metadata_limite.go) y puede volver vacía sin que eso signifique
	// "sin identidad": la UI ya manda el ISRC/los ids. Sin este fallback, una
	// extensión lenta se llevaba por delante la fase exacta por ISRC y el rescate
	// FLAC. `track` queda intacto a propósito: más abajo es lo que llena pkg.Track
	// con los datos ricos (portada, álbum) del proveedor ganador.
	trackIdentidad := track
	if trackIdentidad == nil && (isrc != "" || spotifyID != "" || deezerID != "" || tidalID != "" || qobuzID != "") {
		trackIdentidad = &provider.TrackResult{
			ID:        quitarPrefijoConocido(trackID),
			Title:     trackName,
			Artist:    artistName,
			Album:     albumName,
			ISRC:      isrc,
			SpotifyID: spotifyID,
			DeezerID:  deezerID,
			TidalID:   tidalID,
			QobuzID:   qobuzID,
			Provider:  preferredProvider,
			Duration:  durationMs,
		}
	}
	// El álbum del pedido también sirve cuando la metadata SÍ llegó pero el
	// proveedor no lo expone: el ranking por nombre prefiere la toma del disco
	// pedido en vez de la de un recopilatorio. Se copia la estructura a propósito
	// —`track` es el objeto cacheado y lo que llena pkg.Track: mutarlo acá
	// ensuciaría la metadata que ve la UI.
	if trackIdentidad != nil && trackIdentidad.Album == "" && albumName != "" {
		copia := *trackIdentidad
		copia.Album = albumName
		trackIdentidad = &copia
	}

	streamURL := ""
	streamProvider := ""
	if preferredProvider != "" && esProviderStreaming(preferredProvider) {
		inicioAtajo := time.Now()
		url, err := intentarStream(reg, preferredProvider, trackID, track, quality)
		log.Printf("[play] atajo propio %.0fms -> ok=%v err=%v",
			float64(time.Since(inicioAtajo).Microseconds())/1000, url != "", err)
		if err == nil && url != "" {
			streamURL = url
			streamProvider = preferredProvider
		}
	}

	if streamURL == "" {
		url, prov, attempted, verified := rescueStream(reg, trackIdentidad, trackName, artistName, quality)
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
	log.Printf("[play] stream listo en %.0fms (prov=%q)",
		float64(time.Since(inicioPkg).Microseconds())/1000, streamProvider)

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
