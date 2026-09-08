package streaming

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

func StreamQuick(
	reg *provider.Registry,
	providerName, trackID, quality, isrc, spotifyID, deezerID, tidalID, qobuzID string,
	trackName, artistName string,
) (string, string, error) {
	if reg == nil {
		return "", "", fmt.Errorf("no inicializado")
	}
	if providerName == "" {
		return "", "", fmt.Errorf("sin proveedor")
	}
	p := reg.Get(providerName)
	if p == nil {
		return "", "", fmt.Errorf("proveedor no encontrado: %s", providerName)
	}
	// Authoritative identifiers resolve the EXACT track; a plain trackID (often
	// another provider's native id) does not and must be verified later.
	authoritative := isrc != "" || spotifyID != "" || deezerID != "" || tidalID != "" || qobuzID != ""
	id := ""
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		if foundID, found := ep.CheckAvailability(isrc, trackName, artistName, spotifyID, deezerID, tidalID, qobuzID, 0); found && foundID != "" {
			id = foundID
		}
	}
	if id == "" && isrc != "" {
		if t, err := p.GetTrackByISRC(isrc); err == nil && t != nil && t.ID != "" {
			id = t.ID
		}
	}
	if id == "" {
		id = quitarPrefijoConocido(trackID)
		authoritative = false
	}
	if id == "" {
		return "", "", fmt.Errorf("no se pudo identificar el track en %s", providerName)
	}
	// Always verify the resolved id really is the requested track when we have
	// its title — even when the id came from an "authoritative" identifier (a
	// wrong/misreported ISRC or a cross-provider id still produces a wrong song,
	// which is worse than a moment's extra lookup). We never play a similar song.
	if trackName != "" {
		id = verificarMatchStream(p, id, trackName, artistName, isrc, authoritative)
		if id == "" {
			return "", "", fmt.Errorf("no se pudo confirmar la cancion original en %s", providerName)
		}
	}
	for _, q := range calidadesDisponibles(quality) {
		if cooldown.IsCooled(providerName) {
			break
		}
		url, err := p.GetStreamURL(id, q)
		if err != nil {
			// El proveedor tiene la cancion exacta (resuelta por isrc / id
			// cross-provider) pero necesita su sesion verificada para streamear:
			// se devuelve ese veredicto para que el reproductor abra el modal en
			// vez de recorrer todos los providers 10-30s y fallar generico. Nunca
			// se enfría aqui un provider pendiente de verificar: enfriarlo haria
			// que el SIGUIENTE tap omita la ruta rapida y re-entre al walk lento.
			// El descifrado cliente (deezer Blowfish FLAC) tambien aborta rapido:
			// solo download() puede servir esa cancion, sin enfriar a deezer
			// que debe seguir usable como fuente del pipeline de descarga.
			if abort, serr := clasificarErrorStream(providerName, err.Error()); abort {
				return "", "", serr
			}
			continue
		}
		if url != "" && esURLReproducible(url) {
			cooldown.MarkOk(providerName)
			return url, providerName, nil
		}
	}
	return "", "", fmt.Errorf("sin stream reproducible en %s", providerName)
}

// verifyStreamMatch confirms that a resolved id actually maps back to the
// ORIGINAL query track before its stream is served. It returns [id] unchanged
// cuando confident, o "" cuando se cannot ser confirmed — so el caller falls// through to a path with stricter matching instead of playing a wrong/similar
// song (remix/live/cover/other track). [isrc] is the ISRC the caller was given
// (may be empty); [authoritative] reports whether [id] came from an ISRC or a
// cross-provider id (trusted if it can't be fetched) as opposed to a guessed
// id (refused if it can't be fetched).
