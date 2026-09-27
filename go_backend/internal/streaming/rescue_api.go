package streaming

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// rescueByIdentifiers sondea todos los proveedores FULL-STREAM por la cancion
// EXACTA via sus identificadores cross-provider — la misma ruta CheckAvailability
// que StreamQuick usa para el proveedor preferido, pero corrida en paralelo a
// lo largo de todos los proveedores full-stream. Es la ruta mas rapida para una
// cancion tidal/amazon/qobuz/spotify con id cross-provider: cada proveedor
// resuelve el id (o ISRC) en ~1-2s sin ninguna busqueda por nombre.
func rescuePorIdentificadores(reg *provider.Registry, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName string, queryDurationMS int) (string, string, bool) {
	if isrc == "" && spotifyID == "" && deezerID == "" && tidalID == "" && qobuzID == "" {
		return "", "", false
	}
	// El orden y el paralelismo dependen de la calidad pedida: sin pérdida, las
	// fuentes que pueden darlo van primero y con un turno extra (ver
	// ordenProvidersStreamingCalidad / workersRescate).
	names := ordenProvidersStreamingCalidad(reg, quality)
	// Presupuesto de 5s. Los proveedores de ESTA fase corren en paralelo entre sí
	// (así que 5s es el tope del conjunto, no la suma), pero la fase ENTERA corre
	// antes del rescate: su tiempo SÍ suma a la latencia percibida del toque. Es
	// el mismo defecto de forma que se corrigió en play_package.go (una fase
	// "de mejora" delante de la que consigue el audio), y se deja acá a
	// propósito: ver la nota de latencia en RescueStreamURL.
	// La misma resolución por identidad que usa la fase exacta del rescate: una
	// extensión traduce el ISRC/los ids a su propio id con checkAvailability y el
	// resto cae a GetTrackByISRC (ver rescue_identidad.go).
	d := datosIdentidad{
		isrc: isrc, spotifyID: spotifyID, deezerID: deezerID,
		tidalID: tidalID, qobuzID: qobuzID,
		title: trackName, artist: artistName, durationMS: queryDurationMS,
	}
	url, prov, verified := carreraPorConfianzaCalidad(reg, names, 5*time.Second, workersRescate(quality), func(name string, p provider.Provider) (string, bool) {
		return resolverStreamPorIdentidad(p, quality, d)
	}, quality)
	return url, prov, verified
}

// RescueStreamURL probes every registered FULL-STREAM provider (deezer,
// soundcloud, ytmusic, youtube) for a direct http stream of the exact track,
// resolved via its identifiers (ISRC / cross-provider ids, then a strict
// original-track name search) — the same fast route StreamQuick uses for the
// preferred provider, but across all full-stream providers. It is the "instant
// stream" pass used before the slow download pipeline for tracks whose
// preferred source (tidal/apple/amazon/qobuz/spotify-web) exposes no direct
// stream. Returns (url, provider, err).
func RescueStreamURL(reg *provider.Registry, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName, queryAlbum string, queryDurationMS int) (urlOut, provOut string, errOut error) {
	if reg == nil {
		return "", "", fmt.Errorf("no inicializado")
	}
	// Instrumentación de LATENCIA del TAP: este es el camino que corre en cada
	// toque real (allowFallback=true) y hasta ahora no tenía ninguna marca
	// temporal — no había forma de saber si los segundos se iban en la fase de
	// identificadores o en el rescate. Es el mismo tipo de número que el
	// [play] metadata de play_package.go: sin él no se encontró aquella fase
	// serial, y sin él no se puede decidir si vale tocar esta.
	inicioTotal := time.Now()
	defer func() {
		log.Printf("[play] tap TOTAL %.0fms -> prov=%q url=%v verify=%v err=%v",
			float64(time.Since(inicioTotal).Microseconds())/1000, provOut, urlOut != "", urlOut == "" && provOut != "", errOut)
	}()
	// Serialize rescue walks so batch play (3+ concurrent getStreamPackage)
	// does not flood providers with parallel requests that trigger rate limits
	// (tidal 429 → VERIFY_REQUIRED, soundcloud 401).  A buffered channel of 2
	// Permite dos walks simultaneos (p. ej. cancion actual + prefetch del
	// siguiente) mientras bloquea un tercero hasta que uno termine.
	select {
	case rescueWalkGate <- struct{}{}:
		defer func() { <-rescueWalkGate }()
	case <-time.After(15 * time.Second):
		// Don't block playback forever — if the gate is saturated the caller
		// already has too many in-flight walks; fall through and try anyway.
	}
	// Si no hay identificador ni nombre, no hay nada con que resolver.
	if isrc == "" && spotifyID == "" && deezerID == "" && tidalID == "" && qobuzID == "" && trackName == "" {
		return "", "", fmt.Errorf("sin identificador de track")
	}
	// Phase 0 — identifiers first: the exact track resolved via cross-provider
	// ids / ISRC, raced in parallel across every full-stream provider. A track
	// from ANY source (search item, album/playlist/artist detail, feed) that
	// carries spotify/deezer/tidal/qobuz id or an ISRC starts playing in ~1-2s
	// instead of falling into the slow name-search below. Search results in
	// particular often lack an ISRC but always carry the source provider's id.
	// Una senal de verificacion aqui es RECORDADA, nunca fatal: las fases de
	// busqueda por nombre siguientes aun pueden encontrar la cancion en un
	// proveedor que no indexa ISRC / ids cross-provider (p. ej. youtube) — una
	// cancion sonando siempre gana a un modal de verificacion, asi que el
	// veredicto solo se devuelve cuando nada streamea.
	// NOTA DE LATENCIA: esta fase corre ENTERA antes del rescate, así que sus
	// segundos suman al toque — a diferencia de las fases internas de
	// rescueStream, que corren en paralelo entre sí. Solaparla se evaluó y NO se
	// hace: sumarle una búsqueda por id en YouTube/ytmusic haría que las dos fases
	// pelearan por los mismos proveedores y volvería el triplicado de latencia que
	// ya se midió y se revirtió (2,2s → 5,8-11,2s). El orden queda como está y es
	// el presupuesto de 5s el que acota el daño.
	//
	// La MISMA resolución por identidad la usan las dos fases (aquí y en la fase
	// exacta de rescueStream, ver rescue_identidad.go), y por eso el rescate sabe
	// que esta ya se intentó y no la repite — salvo que un ISRC nuevo llegue
	// derivado en vuelo.
	var idVerify string
	inicioIDs := time.Now()
	urlIDs, provIDs, verifiedIDs := rescuePorIdentificadores(reg, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName, queryDurationMS)
	msIDs := float64(time.Since(inicioIDs).Microseconds()) / 1000
	if urlIDs != "" {
		log.Printf("[play] tap: identificadores %.0fms -> %s", msIDs, provIDs)
		return urlIDs, provIDs, nil
	}
	if verifiedIDs {
		idVerify = provIDs
	}
	log.Printf("[play] tap: identificadores %.0fms sin stream (verify=%q): arranca el rescate", msIDs, idVerify)
	// La duración entra para que la verificación por fase (y la fase exacta por
	// ISRC) pueda descartar un remix/directo con el título parecido, y el álbum
	// para que el ranking por nombre prefiera la toma del disco pedido.
	track := &provider.TrackResult{
		ISRC:      isrc,
		Title:     trackName,
		Artist:    artistName,
		Album:     queryAlbum,
		Duration:  queryDurationMS,
		SpotifyID: spotifyID,
		DeezerID:  deezerID,
		TidalID:   tidalID,
		QobuzID:   qobuzID,
	}
	// La identidad que acaba de probar la fase de arriba: la fase exacta del
	// rescate no la repite (solo corre si un ISRC nuevo llega derivado en vuelo).
	identidadProbada := isrc != "" || spotifyID != "" || deezerID != "" || tidalID != "" || qobuzID != ""
	url, prov, attempted, verified := rescueStream(reg, track, trackName, artistName, quality, identidadProbada)
	if url != "" {
		return url, prov, nil
	}
	if verified {
		return "", prov, &VerifyRequiredError{Service: prov}
	}
	if idVerify != "" {
		return "", idVerify, &VerifyRequiredError{Service: idVerify}
	}
	if len(attempted) > 0 {
		return "", "", fmt.Errorf("sin stream en: %s", strings.Join(attempted, ", "))
	}
	return "", "", fmt.Errorf("sin stream en ningun proveedor")
}
