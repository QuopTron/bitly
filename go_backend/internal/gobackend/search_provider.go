package gobackend

import (
	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// searchProviderItems searches a single provider and returns FeedItemGo items
// (no JSON serialization — used by streaming search). Track results are
// filtered through RankOriginalCandidates so covers/remixes/wrong-versions
// are rejected before they reach the user's screen.
func searchProviderItems(p provider.Provider, query string, limit int, searchType string) []FeedItemGo {
	items := make([]FeedItemGo, 0)

	// Only skip providers cooled *for search*. Streaming/download rate-limits
	// cool the provider-wide bucket; gating search on that here would make a
	// "Todas"/single-source search come back empty right after a heavy playback
	// session (until the cooldown expires) even though the source's search
	// endpoints are perfectly reachable.
	if cooldown.IsCooledOp(p.Name(), "search") {
		return items
	}

	// Extract query title+artist for relevance filtering.
	queryTitle, queryArtist := splitSearchQuery(query)

	switch searchType {
	case "all", "":
		// Combined search (unfiltered)
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			res, err := ep.CombinedSearch(query, limit)
			if err != nil {
				// Transport/session failure: the source is unhealthy right now.
				// Return fast — a fallback query would fail the same way and
				// only add seconds of dead wait for the user.
				return items
			}
			for _, c := range res {
				items = append(items, combinadoAFeedItem(c, ep.Name()))
			}
			// Solo se filtran los TRACKS por relevancia (álbumes/artistas/playlists
			// se dejan como vienen: el usuario puede querer otro álbum con el mismo
			// nombre). filtrarOriginales conserva lo que no es track y usa la misma
			// política en dos pasadas que el resto del pipeline: sin eso, una consulta
			// sin separador de artista devolvía vacío aunque la canción estuviera
			// encontrada (ver su doc).
			if queryTitle != "" {
				items = filtrarOriginales(items, queryTitle, queryArtist)
			}
			if len(items) > 0 {
				return items
			}
		}
		// Fallback: track search only (only reached when the extension search
		// genuinely succeeded with zero results, or for native providers).
		tracks, err := p.SearchTracks(query, limit)
		if err == nil {
			if queryTitle != "" {
				tracks = provider.RankOriginalCandidates(queryTitle, queryArtist, tracks)
			}
			for _, t := range tracks {
				items = append(items, trackToFeedItem(t, p.Name()))
			}
		}
	case "track", "tracks", "song", "songs":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			// El id del manifest de ESA extensión, no el canónico de la UI:
			// pasarle "tracks" a Deezer (que declara "track") devolvía
			// vacío sin error — ver search_filtro_extension.go.
			res, err := ep.SearchFiltered(
				filtroParaExtension(ep.Name(), searchType), query, limit)
			if err != nil {
				// Source is down (auth/session/rate-limit): don't burn a second
				// full query on top of the failed one.
				return items
			}
			if len(res) > 0 {
				items := combinadosAFeedItems(res, ep.Name())
				if queryTitle != "" {
					items = filtrarOriginales(items, queryTitle, queryArtist)
				}
				return items
			}
			// Genuine empty for this filter: fall through to SearchTracks once
			// (some providers only populate the unfiltered search).
		}
		tracks, err := p.SearchTracks(query, limit)
		if err == nil {
			if queryTitle != "" {
				tracks = provider.RankOriginalCandidates(queryTitle, queryArtist, tracks)
			}
			for _, t := range tracks {
				items = append(items, trackToFeedItem(t, p.Name()))
			}
		}
	case "album", "albums":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(
				filtroParaExtension(ep.Name(), searchType), query, limit,
			); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
		}
		albums, err := p.SearchAlbums(query, limit)
		if err == nil {
			for _, a := range albums {
				items = append(items, albumAFeedItem(a, p.Name()))
			}
		}
	case "artist", "artists":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(
				filtroParaExtension(ep.Name(), searchType), query, limit,
			); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
		}
		artists, err := p.SearchArtists(query, limit)
		if err == nil {
			for _, a := range artists {
				items = append(items, artistaAFeedItem(a, p.Name()))
			}
		}
	case "playlist", "playlists":
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if res, err := ep.SearchFiltered(
				filtroParaExtension(ep.Name(), searchType), query, limit,
			); err == nil && len(res) > 0 {
				return combinadosAFeedItems(res, ep.Name())
			}
		}
		playlists, err := p.SearchPlaylists(query, limit)
		if err == nil {
			for _, pl := range playlists {
				items = append(items, playlistAFeedItem(pl, p.Name()))
			}
		}
	}
	return items
}

// combinedToFeedItems converts a slice of CombinedResult to FeedItemGo.
func combinadosAFeedItems(res []provider.CombinedResult, source string) []FeedItemGo {
	items := make([]FeedItemGo, 0, len(res))
	for _, c := range res {
		items = append(items, combinadoAFeedItem(c, source))
	}
	return items
}

// filtrarOriginales keeps what the user actually asked for, dropping covers,
// remixes, karaoke and wrong songs. Se aplica a los resultados de
// SearchFiltered, que NO pasan por RankOriginalCandidates.
//
// CUATRO NIVELES, EN ESTE ORDEN (el primero que encuentra algo, gana):
//
//  1. ESTRICTOS: título fuerte + artista confirmado (OriginalStrength). Es la
//     máxima confianza y la misma política que el camino nativo.
//  2. POR TÍTULO: el nombre del resultado coincide con la consulta y no es una
//     variante.
//  3. POR ARTISTA/ÁLBUM: la consulta nombra al ARTISTA (o al disco) y este
//     resultado es suyo. **Esto era el bug**: quien busca "Canserbero" o "Bad
//     Bunny" quiere las canciones de ese artista, pero el filtro solo comparaba
//     contra el TÍTULO — y ningún tema se llama como el artista, así que la
//     lista quedaba VACÍA mientras álbumes/artistas/playlists (que no pasan por
//     este filtro) sí aparecían. Medido contra Deezer: q="Canserbero" devolvía
//     25 temas y los 25 se descartaban; con este nivel entran los 25.
//  4. ÚLTIMO RECURSO: no variantes con al menos 60% de solapamiento de tokens
//     con la consulta. Es la red que evita la pantalla vacía cuando la
//     relevancia la decidió la propia extensión (que es la única que conoce su
//     catálogo). Nunca promueve un cover/remix/karaoke, y exige coincidencia
//     real de texto: por eso no puede inundar de basura una búsqueda que no
//     existe.
//
// Los niveles 2 y 3 se SUMAN (título primero): una búsqueda de artista suele
// traer también algún tema homónimo, y ambos son lo que el usuario pidió.
func filtrarOriginales(items []FeedItemGo, queryTitle, queryArtist string) []FeedItemGo {
	noTracks := make([]FeedItemGo, 0, len(items))
	estrictos := make([]FeedItemGo, 0, len(items))
	porTitulo := make([]FeedItemGo, 0, len(items))
	porArtistaOAlbum := make([]FeedItemGo, 0, len(items))
	ultimoRecurso := make([]FeedItemGo, 0, len(items))
	for _, item := range items {
		if item.Type != "track" {
			noTracks = append(noTracks, item)
			continue
		}
		variante := provider.IsNonOriginalVariant(item.Name, queryTitle)
		tr := provider.TrackResult{
			Title:  item.Name,
			Artist: item.Artists,
			ISRC:   item.ISRC,
		}
		if _, ok := provider.OriginalStrength(queryTitle, queryArtist, tr); ok {
			estrictos = append(estrictos, item)
			continue
		}
		if !variante && provider.FieldScore(queryTitle, item.Name) >= 2 {
			porTitulo = append(porTitulo, item)
			continue
		}
		if !variante && (provider.FieldScore(queryTitle, item.Artists) >= 2 ||
			provider.FieldScore(queryTitle, item.AlbumName) >= 2) {
			porArtistaOAlbum = append(porArtistaOAlbum, item)
			continue
		}
		if !variante && provider.FieldScore(queryTitle, item.Name) >= 1 {
			ultimoRecurso = append(ultimoRecurso, item)
		}
	}
	if len(estrictos) > 0 {
		return append(noTracks, estrictos...)
	}
	if len(porTitulo) > 0 || len(porArtistaOAlbum) > 0 {
		return append(append(noTracks, porTitulo...), porArtistaOAlbum...)
	}
	return append(noTracks, ultimoRecurso...)
}

// searchRankedAll uses the search engine (ISRC dedup + relevance ranking)
// for track searches across all providers. Falls back to parallel raw search
