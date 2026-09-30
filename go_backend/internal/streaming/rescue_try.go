package streaming

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// tryStream intenta obtener stream URL de un provider especifico.
func intentarStream(reg *provider.Registry, name, trackID string, track *provider.TrackResult, quality string) (string, error) {
	p := reg.Get(name)
	if p == nil {
		return "", fmt.Errorf("proveedor no encontrado: %s", name)
	}
	// Reloj del atajo: este camino tiene CUATRO bloques de calidades (id
	// verificado, id sin título, id propio, ISRC) y ningún techo, así que un
	// proveedor lento podía consumir minutos antes de que arrancara el rescate.
	// Ver atajo_presupuesto.go.
	techo := nuevoTechoAtajo(name)

	candidates := calidadesDisponibles(quality)

	// Verify the trackID is the RIGHT song (not a live/remix/cover) before
	// streaming it. Some extensions' getDownloadUrl resolves a name-based
	// lookup that can return a live version even when the ID looks correct.
	if track != nil && track.Title != "" && trackID != "" {
		if err := techo.comprobar("identificación"); err != nil {
			return "", err
		}
		if vID := verificarMatchStream(p, trackID, track.Title, track.Artist, track.ISRC, true, track.Duration); vID == "" {
			// trackID doesn't match the queried song — skip the direct path
			// and let the ISRC path below find the correct version.
		} else {
			trackID = vID // verified or enriched
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				if err := techo.probar(); err != nil {
					return "", err
				}
				url, err := PedirStreamURL(p, trackID, q)
				if err != nil {
					if abort, serr := clasificarErrorStream(name, err.Error()); abort {
						return "", serr
					}
					continue
				}
				if url != "" && esURLReproducible(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	} else {
		// No title to verify against — stream directly (e.g. feed item without metadata).
		for _, q := range candidates {
			if cooldown.IsCooled(name) {
				break
			}
			if err := techo.probar(); err != nil {
				return "", err
			}
			url, err := p.GetStreamURL(trackID, q)
			if err != nil {
				if abort, serr := clasificarErrorStream(name, err.Error()); abort {
					return "", serr
				}
				continue
			}
			if url != "" && esURLReproducible(url) {
				cooldown.MarkOk(name)
				return url, nil
			}
		}
	}

	// Second path: try the provider's own track ID if different from the input.
	if track != nil && track.ID != "" && track.ID != trackID {
		verifiedID := track.ID
		if track.Title != "" {
			if err := techo.comprobar("identificación"); err != nil {
				return "", err
			}
			if vID := verificarMatchStream(p, track.ID, track.Title, track.Artist, track.ISRC, false, track.Duration); vID != "" {
				verifiedID = vID
			} else {
				verifiedID = "" // track.ID is a live/remix — skip
			}
		}
		if verifiedID != "" {
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				if err := techo.probar(); err != nil {
					return "", err
				}
				url, err := PedirStreamURL(p, verifiedID, q)
				if err != nil {
					if abort, serr := clasificarErrorStream(name, err.Error()); abort {
						return "", serr
					}
					continue
				}
				if url != "" && esURLReproducible(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	}
	if track != nil && track.ISRC != "" {
		if err := techo.comprobar("resolución ISRC"); err != nil {
			return "", err
		}
		if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil && trackByISRC.ID != "" {
			// Nunca streamear un candidato ISRC sin verificar cuando conocemos el
			// titulo/artista pedido: una extension cuya busqueda ISRC cae en una
			// busqueda por nombre (re-subidas de SoundCloud, mapeos erroneos)
			// serviria una cancion distinta. verificarMatchStream re-obtiene el id
			// resuelto y lo rechaza ante ISRC distinto o fuerza titulo+artista debil.
			if track.Title != "" {
				if err := techo.comprobar("identificación"); err != nil {
					return "", err
				}
				if verified := verificarMatchStream(p, trackByISRC.ID, track.Title, track.Artist, track.ISRC, true, track.Duration); verified == "" {
					return "", fmt.Errorf("stream de %s no es la cancion solicitada", name)
				}
			}
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				if err := techo.probar(); err != nil {
					return "", err
				}
				if url, err := PedirStreamURL(p, trackByISRC.ID, q); err != nil {
					if abort, serr := clasificarErrorStream(name, err.Error()); abort {
						return "", serr
					}
				} else if url != "" && esURLReproducible(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	}
	return "", fmt.Errorf("stream no disponible en %s", name)
}
