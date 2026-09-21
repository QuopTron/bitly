package provider

import "strings"

// matching_album.go — Desempate por ÁLBUM para el ranking de candidatos.
//
// Por qué existe: título + artista no alcanzan cuando la MISMA canción vive en
// varios álbumes a la vez — el disco original, el recopilatorio, el "remix
// album", la edición de lujo con otra toma. Ahí el ranking servía la versión de
// otro disco (el clásico "descargué un remix"): el título coincide y el artista
// también, pero el álbum del candidato no es el del pedido.
//
// El álbum es además la señal que falta en las descargas POR ÁLBUM: todas las
// pistas que se piden comparten ese álbum, así que preferir el candidato del
// disco pedido resuelve pistas homónimas ("Intro", "Interlude", o dos tomas de
// la misma canción) sin adivinar.
//
// Regla de oro (igual que el desempate por duración): NUNCA rechaza. Un
// candidato con álbum distinto o sin álbum sigue siendo válido — los catálogos
// cambian el nombre entre ediciones ("Un Verano Sin Ti" vs "Un Verano Sin Ti
// (Deluxe)"), los re-subidos no traen álbum, y rechazar por eso dejaría
// canciones sin audio. Solo reordena candidatos que empatan en puntaje.
//
// Se conecta con: matching_original.go y matching_duracion.go (el ranking base),
// download/orchestrator_trackid.go y streaming/rescue_rank.go (los llamadores
// que conocen el álbum pedido).
// Parte del flujo: identificación de la canción buscada.

// AlbumScore mide qué tan bien coincide el álbum del candidato con el pedido:
// 3 = igual, 2 = uno contiene al otro (edición de lujo, remaster, relanzamiento),
// 1 = solapamiento débil de tokens, 0 = distinto o desconocido.
func AlbumScore(queryAlbum, candAlbum string) float64 {
	q := FoldTrack(queryAlbum)
	r := FoldTrack(candAlbum)
	if q == "" || r == "" {
		return 0
	}
	if q == r {
		return 3
	}
	// "un verano sin ti" vs "un verano sin ti deluxe": la edición de lujo del
	// MISMO disco es una coincidencia fuerte, no débil.
	if strings.Contains(r, q) || strings.Contains(q, r) {
		return 2
	}
	if solapamientoTokens(q, r) >= 0.7 {
		return 1
	}
	return 0
}

// mejorCandidato reporta si [a] debe ir antes que [b] dentro del MISMO grupo de
// puntaje título+artista: primero el álbum pedido, después la duración más
// parecida. Cuando no hay álbum en el pedido la comparación degrada exactamente
// al desempate por duración de siempre.
func mejorCandidato(queryAlbum string, queryDurationMS int, a, b TrackResult) bool {
	sa, sb := AlbumScore(queryAlbum, a.Album), AlbumScore(queryAlbum, b.Album)
	if sa != sb {
		return sa > sb
	}
	return distanciaDuracionMS(queryDurationMS, a.Duration) < distanciaDuracionMS(queryDurationMS, b.Duration)
}

// RankOriginalCandidatesAlbum es RankOriginalCandidates más el desempate por
// álbum y duración. El orden base (originales primero, variantes excluidas) NO
// cambia: solo se reordenan candidatos con el MISMO puntaje título+artista, así
// que un candidato mejor nunca baja y uno sin álbum nunca se descarta.
//
// Con [queryAlbum] vacío equivale a RankOriginalCandidatesDuracion (el álbum de
// todos puntúa 0), por eso ese camino delega acá en vez de duplicar el orden.
func RankOriginalCandidatesAlbum(queryTitle, queryArtist, queryAlbum string, queryDurationMS int, results []TrackResult) []TrackResult {
	ranked := RankOriginalCandidates(queryTitle, queryArtist, results)
	if len(ranked) < 2 || (queryAlbum == "" && queryDurationMS <= 0) {
		return ranked
	}
	out := append([]TrackResult(nil), ranked...)
	// Inserción estable por (álbum, duración) DENTRO de cada grupo de puntaje: al
	// no cruzar grupos, un candidato mejor nunca baja.
	for i := 1; i < len(out); i++ {
		for j := i; j > 0; j-- {
			prev, cur := out[j-1], out[j]
			if puntajeEfectivo(queryTitle, queryArtist, prev) != puntajeEfectivo(queryTitle, queryArtist, cur) {
				break
			}
			if mejorCandidato(queryAlbum, queryDurationMS, cur, prev) {
				out[j-1], out[j] = out[j], out[j-1]
				continue
			}
			break
		}
	}
	return out
}

// BestOriginalAlbumDuracion picks the strongest original match, desempatando por
// álbum y después por duración. Devuelve nil si ningún candidato es un original.
func BestOriginalAlbumDuracion(queryTitle, queryArtist, queryAlbum string, queryDurationMS int, results []TrackResult) *TrackResult {
	ranked := RankOriginalCandidatesAlbum(queryTitle, queryArtist, queryAlbum, queryDurationMS, results)
	if len(ranked) == 0 {
		return nil
	}
	return &ranked[0]
}
