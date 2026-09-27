// ─────────────────────────────────────────────────────────────────────────
// play_metadata.go — Fase de IDENTIDAD de la reproducción: resuelve el track
// (título, artista, ISRC, ids cross-proveedor) EN PARALELO con el pedido del
// stream (ver play_package.go), nunca delante de él.
//
// La metadata es una MEJORA, no un requisito: el audio lo consigue el rescate
// (rescue_stream.go) con la identidad del PEDIDO. Por eso cada paso acá tiene
// PRESUPUESTO y los recorridos corren en PARALELO (ver play_metadata_limite.go):
// medido, una sola llamada a una extensión lenta retenía la reproducción 65s
// aunque el rescate resolvía la canción en 3,5s.
//
// Se conecta con: play_metadata_limite.go (presupuestos) + play_metadata_enrich
// .go (ISRC por identidad) + play_metacache.go (caché por identidad estable).
// Parte del flujo: reproducción (identidad → stream).
// ─────────────────────────────────────────────────────────────────────────

package streaming

import (
	"log"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func obtenerMetadata(reg *provider.Registry, providerName, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID string) *provider.TrackResult {
	cacheKey := claveCacheMetadata(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName)
	// Session cache: the same track is resolved many times (feed prefetch,
	// queue neighbours, re-tap). Serve the cached result instead of re-searching.
	if cached := metadataCacheada(cacheKey); cached != nil {
		return cached
	}

	// ISRC por IDENTIDAD (SongLink/Odesli vía enrichTrack de la extensión) antes
	// de cualquier búsqueda por nombre: ver play_metadata_enrich.go. Solo cuando
	// la consulta no trae ya un ISRC y la fuente ES una extensión — los catálogos
	// no lo necesitan porque su metadata ya lo incluye.
	inicio := time.Now()
	var enriquecido *provider.EnrichTrackResult
	if isrc == "" {
		enriquecido = enriquecerPorIdentidad(reg, providerName, trackID, trackName)
	}
	msEnrich := time.Since(inicio)

	// Instrumentación de LATENCIA por eslabón: sin esto no se distingue "la
	// extensión preferida tardó" de "la caminata de catálogos se comió el
	// tiempo" — que es exactamente cómo se encontró el caso de 68s.
	msPreferido, msISRC, msNombre := time.Duration(0), time.Duration(0), time.Duration(0)
	defer func() {
		log.Printf("[play] metadata detalle: enrich=%.0fms preferido=%.0fms isrc=%.0fms nombre=%.0fms (prov=%q)",
			msEnrich.Seconds()*1000, msPreferido.Seconds()*1000,
			msISRC.Seconds()*1000, msNombre.Seconds()*1000, providerName)
	}()

	store := func(t *provider.TrackResult) *provider.TrackResult {
		if t != nil && t.ISRC == "" && !enriquecimientoVacio(enriquecido) {
			copia := *t
			aplicarEnriquecimiento(&copia, enriquecido)
			t = &copia
		}
		guardarMetadata(cacheKey, t)
		// Also index by the found track's ISRC so later calls that only carry a
		// different provider id still hit (their key normalizes to the ISRC).
		if t != nil && t.ISRC != "" {
			guardarMetadata(claveCacheMetadata(t.ISRC, "", "", "", "", "", "", ""), t)
		}
		return t
	}

	exactID := quitarPrefijoConocido(trackID)

	// ── Proveedor preferido, con PRESUPUESTO ────────────────────────────────
	// Las llamadas van de la más exacta a la más difusa (ISRC → id nativo → ids
	// cross-proveedor → búsqueda por nombre). Todo el bloque se corta si una
	// extensión se cuelga; el resultado que llegue tarde igual se guarda en la
	// caché (store corre dentro de la goroutine), así el próximo tap es
	// instantáneo aunque este no lo aproveche.
	inicioPreferido := time.Now()
	// Ventana del bloque: si el pedido YA trae identidad (ISRC o ids), acá solo se
	// busca metadata rica y se corta en 400ms; si no la trae, esta fase es la que
	// puede DESCUBRIR el ISRC (y con él la fase exacta y el rescate FLAC), así que
	// se le da la ventana larga.
	ventanaPreferido := presupuestoBloquePreferido
	if isrc != "" || spotifyID != "" || deezerID != "" || tidalID != "" || qobuzID != "" {
		ventanaPreferido = presupuestoIdentidadConocida
	}
	if providerName != "" {
		if p := reg.Get(providerName); p != nil && !cooldown.IsCooled(providerName) {
			elegido := resolverConPresupuesto(ventanaPreferido, func() *provider.TrackResult {
				// Exact ISRC first — one call, no name search, and the result is
				// the canonical identity every provider can resolve against.
				if isrc != "" {
					if t, err := p.GetTrackByISRC(isrc); err == nil && t != nil {
						return store(t)
					}
				}
				if exactID != "" {
					if t, err := p.GetTrack(exactID); err == nil && t != nil {
						return store(t)
					}
				}
				// Cross-provider ids via the provider that owns them (only the
				// matching shape is fed, so no wasted calls).
				for _, cid := range []struct {
					name string
					id   string
				}{{"spotify", spotifyID}, {"deezer", deezerID}, {"tidal", tidalID}, {"qobuz", qobuzID}} {
					if cid.id == "" || cid.name == providerName {
						continue
					}
					if t, err := p.GetTrack(cid.id); err == nil && t != nil {
						return store(t)
					}
				}
				if trackName != "" && artistName != "" {
					if results, err := p.SearchTracks(trackName+" "+artistName, 8); err == nil && len(results) > 0 {
						if best := provider.BestOriginal(trackName, artistName, results); best != nil {
							return store(best)
						}
					}
				}
				return nil
			})
			if elegido != nil {
				msPreferido = time.Since(inicioPreferido)
				return elegido
			}
		}
	}
	msPreferido = time.Since(inicioPreferido)

	// ── ISRC por los DEMÁS proveedores: en paralelo y acotado ───────────────
	// Antes era un recorrido serial (cada catálogo sumaba su latencia). Cada uno
	// puede conocerlo nativamente, así que alcanza con el primero que lo tenga.
	inicioISRC := time.Now()
	if isrc != "" {
		if t := buscarEnParalelo(reg, streamingProviders, providerName, presupuestoISRCCruzado,
			func(p provider.Provider, _ string) *provider.TrackResult {
				if tr, err := p.GetTrackByISRC(isrc); err == nil {
					return tr
				}
				return nil
			}); t != nil {
			msISRC = time.Since(inicioISRC)
			return store(t)
		}
	}
	msISRC = time.Since(inicioISRC)

	// ── Último recurso: búsqueda por nombre, acotada y en paralelo ──────────
	// Solo cuando no hay ningún identificador que resuelva exacto. El rescate
	// hace esta misma búsqueda para conseguir el AUDIO, así que esperar mucho
	// acá es duplicar trabajo: se le da una ventana corta y se sigue.
	inicioNombre := time.Now()
	if trackName != "" && artistName != "" {
		if t := buscarEnParalelo(reg, streamingProviders, providerName, presupuestoNombreCruzado,
			func(p provider.Provider, _ string) *provider.TrackResult {
				results, err := p.SearchTracks(trackName+" "+artistName, 8)
				if err != nil || len(results) == 0 {
					return nil
				}
				return provider.BestOriginal(trackName, artistName, results)
			}); t != nil {
			msNombre = time.Since(inicioNombre)
			return store(t)
		}
	}
	msNombre = time.Since(inicioNombre)

	// Ningún catálogo la tiene, pero el hook por IDENTIDAD sí resolvió el ISRC:
	// con eso alcanza para que la reproducción entre a la fase exacta por ISRC y
	// al rescate FLAC. Antes este dato se descartaba y la canción quedaba
	// condenada al stream lossy por nombre.
	if !enriquecimientoVacio(enriquecido) {
		base := &provider.TrackResult{
			ID:       exactID,
			Title:    trackName,
			Artist:   artistName,
			Provider: providerName,
		}
		aplicarEnriquecimiento(base, enriquecido)
		if base.ISRC != "" {
			return store(base)
		}
	}
	return nil
}
