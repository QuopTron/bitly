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

	// ── LA METADATA CORRE EN PARALELO, NO DELANTE ───────────────────────────
	// Antes era un paso SERIAL previo al atajo y al rescate, así que su tiempo
	// entero se sumaba al pedido aunque el audio estuviera a la vuelta de la
	// esquina. Con el arnés real (TestStreamDiagE2E) eso era el caso
	// amazon→Percuma: metadata 2,49s + rescate 2,22s = 4,71s de punta a punta,
	// cuando el rescate ya tenía el stream a los 2,22s. El comentario de este
	// flujo dice desde siempre que la metadata es "una mejora, nunca un
	// requisito"; ahora el código lo cumple.
	//
	// La identidad con la que se BUSCA el audio sale del PEDIDO (título, artista,
	// ISRC y ids cross-proveedor que ya manda la UI), que es exactamente lo que el
	// usuario tocó. La metadata solo AGREGA datos ricos (portada, álbum, ids
	// traducidos) y se cosecha al final, cuando el stream ya está resuelto.
	chMeta := make(chan *provider.TrackResult, 1)
	go func() {
		defer func() {
			// Una extensión que paniquea no puede tumbar la reproducción NI dejar
			// el canal sin respuesta: el pedido sin identidad propia ESPERA este
			// canal, así que un worker muerto sin enviar sería un cuelgue.
			if r := recover(); r != nil {
				log.Printf("[play] metadata: pánico en la fase de identidad: %v", r)
				chMeta <- nil
			}
		}()
		inicioMeta := time.Now()
		t := obtenerMetadata(reg, preferredProvider, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID)
		log.Printf("[play] metadata %.0fms (prov=%q track=%v isrc=%v)",
			float64(time.Since(inicioMeta).Microseconds())/1000, preferredProvider,
			t != nil, t != nil && t.ISRC != "")
		chMeta <- t
	}()

	// Cosecha sin espera: la metadata ya resuelta para este pedido (tap repetido,
	// prefetch, vecino de cola) está en memoria y mirarla es gratis — no se abre
	// ninguna ventana por algo que ya está.
	track := metadataCacheadaDelPedido(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName)
	// Excepción a la regla: si el pedido NO trae el QUÉ buscar (título o
	// artista), esta fase es la ÚNICA fuente de la consulta. Sin ella el rescate
	// por nombre y el video oficial no tienen con qué arrancar, así que acá sí se
	// la espera. Sus llamadas ya vienen acotadas por presupuesto
	// (ver play_metadata_limite.go).
	if track == nil && (trackName == "" || artistName == "") {
		track = <-chMeta
	}
	if track != nil {
		if trackName == "" {
			trackName = track.Title
		}
		if artistName == "" {
			artistName = track.Artist
		}
	}
	// Identidad para el RESCATE: la del proveedor cuando la metadata llegó (o ya
	// estaba cacheada) y, si no, la del propio PEDIDO. La UI ya manda el ISRC/los
	// ids, así que una metadata vacía NO significa "sin identidad". Sin este
	// fallback, una extensión lenta se llevaba por delante la fase exacta por
	// ISRC y el rescate FLAC. `track` queda intacto a propósito: más abajo es lo
	// que llena pkg.Track con los datos ricos (portada, álbum) del proveedor
	// ganador.
	//
	// Se arma también cuando el pedido solo trae título/artista (sin ids): esa
	// identidad no alcanza para resolver por id, pero SÍ para que el rescate
	// derive el ISRC en vuelo (provider.DerivarISRC) y habilite la fase exacta
	// —que es justo lo que antes aportaba la metadata al llegar.
	trackIdentidad := track
	if trackIdentidad == nil && (trackName != "" || artistName != "" || isrc != "" || spotifyID != "" || deezerID != "" || tidalID != "" || qobuzID != "") {
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
		url, err := intentarStream(reg, preferredProvider, trackID, trackIdentidad, quality)
		log.Printf("[play] atajo propio %.0fms -> ok=%v err=%v",
			float64(time.Since(inicioAtajo).Microseconds())/1000, url != "", err)
		if err == nil && url != "" {
			streamURL = url
			streamProvider = preferredProvider
		}
	}

	if streamURL == "" {
		// identidadProbada=false: acá NO corrió la fase de identificadores de
		// RescueStreamURL — el atajo propio sondeó un solo proveedor, no la
		// identidad contra todas las fuentes de audio.
		url, prov, attempted, verified := rescueStream(reg, trackIdentidad, trackName, artistName, quality, false)
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

	// Cosecha de la metadata que quedó EN VUELO: el audio ya está resuelto, así
	// que acá solo se decide con qué se completa el paquete. La gracia es corta y
	// acotada a propósito (ver esperaMetadataTardia): evita que un paquete salga
	// sin track y dispare una búsqueda por nombre nueva después de haber
	// resuelto la reproducción. Si la metadata no llega, se sigue sin ella.
	if track == nil {
		select {
		case track = <-chMeta:
		case <-time.After(esperaMetadataTardia):
		}
	}

	pkg := &StreamPackage{
		AudioURL: streamURL,
		Provider: streamProvider,
		Quality:  quality,
	}

	if track != nil {
		pkg.Track = track
	}

	// ── LA COMPLETACIÓN TAMBIÉN SALE ACOTADA ─────────────────────────────────
	// El audio ya está resuelto: el track por nombre y las letras son MEJORA,
	// nunca requisito, y sin embargo corrían EN SERIE y sin techo justo acá,
	// al final de la recta. Una búsqueda por nombre se come medio segundo y
	// GetLyrics uno o dos: el paquete salía tarde aunque el stream llevara
	// segundos listo (mismo defecto de forma que el de la metadata serial de
	// arriba, pero en la cola).
	//
	// Ahora los dos trabajos arrancan JUNTOS y el paquete espera por los dos
	// como mucho [esperaCompletacionTardia]. Lo que no llega a tiempo no se
	// pierde: el track queda en la caché de metadata (play_completacion.go) y
	// las letras pueden pedirlas de nuevo por la RPC fetchLyrics — el
	// reproductor ni las pide en línea, manda fetchLyrics=false.
	limite := time.Now().Add(esperaCompletacionTardia)

	var chTrack chan *provider.TrackResult
	if pkg.Track == nil && trackName != "" && artistName != "" {
		clave := claveCacheMetadata(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName)
		chTrack = make(chan *provider.TrackResult, 1)
		go func() {
			chTrack <- buscarTrackPorNombre(reg, streamProvider, clave, trackName, artistName)
		}()
	}

	var chLetras chan *lyrics.Lyrics
	if fetchLyrics && lyricsClient != nil && trackName != "" && artistName != "" {
		chLetras = make(chan *lyrics.Lyrics, 1)
		go func() {
			chLetras <- pedirLetras(lyricsClient, trackName, artistName)
		}()
	}

	if chTrack != nil {
		select {
		case t := <-chTrack:
			pkg.Track = t
		case <-time.After(time.Until(limite)):
		}
	}
	if chLetras != nil {
		select {
		case lyr := <-chLetras:
			if lyr != nil {
				pkg.Lyrics = lyr
			}
		case <-time.After(time.Until(limite)):
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
