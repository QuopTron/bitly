package gobackend

import "strings"

// ─────────────────────────────────────────────────────────────────────────
// TRADUCCIÓN: CATEGORÍA CANÓNICA → FILTRO DEL MANIFEST DE LA EXTENSIÓN
//
// EL BUG QUE ESTO ARREGLA
// La UI manda la categoría canónica ("tracks", "albums", "artists",
// "playlists") y cada extensión nombra sus filtros como quiere: Deezer declara
// "track"/"album"/"artist"/"playlist" (singular), YouTube Music
// "tracks"/"albums"/... El backend pasaba el id recibido TAL CUAL al
// customSearch de cada extensión, y eso no da error: la extensión busca su
// endpoint para ese filtro, no lo encuentra y devuelve [] como si la canción
// no existiera.
//
// Por eso una búsqueda en la fuente "Todas" —donde no hay un manifest de
// fuente del cual sacar el id correcto, así que la UI usa los canónicos—
// volvía VACÍA en las cuatro categorías, mientras que elegir Deezer (que sí
// tiene su manifest en la UI, y por eso mandaba "track") funcionaba.
//
// La traducción se hace acá, en el backend, y no en la UI, porque acá está la
// lista de manifests: así funciona para CUALQUIER fuente, incluida "Todas",
// sin que la UI tenga que adivinar el id de cada extensión.
// ─────────────────────────────────────────────────────────────────────────

// categoriaCanonicaDe lleva cualquier id de filtro a la categoría canónica con
// la que el backend agrupa resultados. Devuelve "" para "all"/vacío o para un
// filtro que no corresponde a ninguna de las cuatro categorías.
func categoriaCanonicaDe(filterID string) string {
	switch strings.ToLower(strings.TrimSpace(filterID)) {
	case "track", "tracks", "song", "songs":
		return "tracks"
	case "album", "albums":
		return "albums"
	case "artist", "artists":
		return "artists"
	case "playlist", "playlists":
		return "playlists"
	}
	return ""
}

// filtroDeLaExtension traduce la categoría pedida al id que ESA extensión
// declara en su manifest (su `searchBehavior.filters`).
//
// Devuelve "" cuando la extensión no declara un filtro para esa categoría: en
// ese caso el llamador usa el id original y el comportamiento no cambia — la
// extensión no soporta esa categoría, y forzarle un id inventado sería peor.
// (Las extensiones sin `searchBehavior` —p. ej. las solo-metadata— quedan
// fuera de la traducción a propósito.)
func filtroDeLaExtension(sourceID, categoria string) string {
	canonica := categoriaCanonicaDe(categoria)
	if canonica == "" {
		return ""
	}
	for _, e := range bundledExts {
		if !plegadoIgual(e.ID, sourceID) {
			continue
		}
		for _, f := range e.Search.Filters {
			if categoriaCanonicaDe(f.ID) == canonica {
				return f.ID
			}
		}
		return ""
	}
	return ""
}

// filtroParaExtension resuelve el id a mandarle a una extensión: el de su
// manifest si lo declara, y si no el que vino (comportamiento previo).
func filtroParaExtension(sourceID, pedido string) string {
	if f := filtroDeLaExtension(sourceID, pedido); f != "" {
		return f
	}
	return pedido
}
