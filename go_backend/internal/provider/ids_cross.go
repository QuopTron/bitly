package provider

import "strings"

// TrimKnownProviderPrefix quita un prefijo "<proveedor>:" cuando el id lo trae
// ("tidal:123", "spotify:abc"): los ítems de feed/detalle lo llevan y las
// extensiones no lo entienden. Un prefijo desconocido —o un id con ":" que no
// es prefijo, como una URL— se devuelve intacto. Es la regla
// `trimKnownProviderPrefix` del middleware de referencia.
//
// Se incluyen las variantes `-web` y los nombres de extensión ("qobuz-web",
// "apple-music"): el `source` que manda la app es el id de la EXTENSIÓN, así que
// un id prefijado lleva ese nombre, no el del proveedor nativo.
func TrimKnownProviderPrefix(id string) string {
	i := strings.IndexByte(id, ':')
	if i <= 0 || i >= len(id)-1 {
		return id
	}
	switch strings.ToLower(id[:i]) {
	case "spotify", "spotify-web", "deezer", "deezer-web",
		"tidal", "tidal-web", "qobuz", "qobuz-web",
		"amazon", "amazon-web", "soundcloud", "apple", "apple-music",
		"youtube", "ytmusic", "ytmusic-spotiflac":
		return id[i+1:]
	}
	return id
}

// DerivarIDsCrossDesdeFuente completa los ids cross-proveedor que falten a
// partir del id NATIVO del proveedor que originó el pedido.
//
// Por qué existe: un ítem de feed/búsqueda casi nunca trae los ids
// cross-proveedor —sólo su `source` y su `trackID` nativo—. La DESCARGA ya
// derivaba el id correcto a partir de esa forma y se lo pasaba a
// checkAvailability de cualquier fuente; el STREAMING no, así que un ítem de
// Tidal/Deezer/Qobuz/Spotify no podía rescatar la grabación EXACTA por
// identidad en otra fuente y caía a una búsqueda por nombre, que es justo la
// vía donde aparecen los re-subidos. Centralizar la regla acá garantiza que los
// dos caminos deriven EXACTAMENTE lo mismo.
//
// Sólo se deriva cuando el id tiene la FORMA del proveedor origen (Spotify = 22
// base62; Deezer/Tidal/Qobuz = numérico) y el id correspondiente está vacío: un
// id ya presente NUNCA se pisa. Una fuente que no es catálogo (amazon=ASIN,
// apple=id propio numérico, youtube=video, soundcloud=...) no aporta un id
// cross-proveedor y se deja intacta — de ahí que la lista de casos sea cerrada y
// no un "si es numérico lo uso".
func DerivarIDsCrossDesdeFuente(source, trackID, spotifyID, deezerID, tidalID, qobuzID string) (string, string, string, string) {
	id := TrimKnownProviderPrefix(strings.TrimSpace(trackID))
	if id == "" {
		return spotifyID, deezerID, tidalID, qobuzID
	}
	switch strings.ToLower(strings.TrimSpace(source)) {
	case "spotify", "spotify-web":
		if spotifyID == "" && IsSpotifyID(id) {
			spotifyID = id
		}
	case "deezer", "deezer-web":
		if deezerID == "" && IsNumericID(id) {
			deezerID = id
		}
	case "tidal", "tidal-web":
		if tidalID == "" && IsNumericID(id) {
			tidalID = id
		}
	case "qobuz", "qobuz-web":
		if qobuzID == "" && IsNumericID(id) {
			qobuzID = id
		}
	}
	return spotifyID, deezerID, tidalID, qobuzID
}
