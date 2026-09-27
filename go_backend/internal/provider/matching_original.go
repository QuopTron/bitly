package provider

import (
	"strings"
)

func artistaEnTitulo(queryArtist, title string) bool {
	qa := FoldTrack(queryArtist)
	if qa == "" {
		return false
	}
	// Los créditos parentéticos NO cuentan como el artista dentro del título.
	//
	// Por qué: "el artista aparece en el título" es el sello de un re-subido
	// ("Shakira - DAI DAI" subido por un canal cualquiera). Pero los discos de
	// covers/tributo/versiones acreditan al artista ORIGINAL en un paréntesis
	// final —"BbY WOW (KAROL G, Judeline, rusowsky)" de un ensamble, "(Originally
	// Performed by ...)", "(feat. ...)"— y con la comprobación anterior ese
	// crédito alcanzaba para que el cover pasara como el original: se servía su
	// ISRC y su audio (la versión de piano/orquesta) en vez de la grabación
	// pedida. Restando los tramos entre paréntesis/corchetes, un re-subido sigue
	// contando (el artista va junto al título, no dentro de un crédito) y el
	// cover deja de colarse.
	t := FoldTrack(sinCreditosParenteticos(title))
	if t == "" {
		return false
	}
	tokens := strings.Fields(qa)
	for _, tok := range tokens {
		if len(tok) >= 3 && strings.Contains(t, tok) {
			return true
		}
	}
	return false
}

// sinCreditosParenteticos quita los tramos encerrados entre paréntesis,
// corchetes o llaves. Lo que queda es el título sin los créditos accesorios
// ("(feat. X)", "[Official Video]", "(KAROL G, ...)").
func sinCreditosParenteticos(s string) string {
	var b strings.Builder
	prof := 0
	for _, r := range s {
		switch r {
		case '(', '[', '{':
			prof++
		case ')', ']', '}':
			if prof > 0 {
				prof--
			}
		default:
			if prof == 0 {
				b.WriteRune(r)
			}
		}
	}
	return b.String()
}

// artistaDeVersion reporta si el campo Artist del candidato se anuncia como una
// interpretación derivada: una orquesta, un ensamble, un pianista, un canal de
// "slowed", un karaoke. No es un rechazo del candidato —sigue disponible por
// nombre— sino el veto a la evidencia "artista dentro del título": quien firma
// como versión no puede pasar por el original aunque su título acredite al
// artista original. Se evalúa solo ahí para no descartar artistas cuyo NOMBRE
// legítimo coincide con un marcador (p. ej. la banda "Live").
func artistaDeVersion(artist string) bool {
	artist = strings.TrimSpace(artist)
	if artist == "" {
		return false
	}
	return IsNonOriginalTitle(artist)
}

// artistaEnTituloDelCandidato es la evidencia "artista dentro del título" con el
// veto por artista de versión aplicado: un cover/orquesta que acredita al
// artista original en el título no la obtiene.
func artistaEnTituloDelCandidato(queryArtist string, t TrackResult) bool {
	if !artistaEnTitulo(queryArtist, t.Title) {
		return false
	}
	return !artistaDeVersion(t.Artist)
}

// canalesResubida son palabras que delatan un canal de re-subida (YouTube
// "topic"/"VEVO", agregadores de lyrics, recopilatorios) en vez de un artista
// real. Cuando el campo Artist las contiene, el título suele seguir siendo la
// canción pedida y el artista real va dentro del propio título.
var canalesResubida = []string{
	"vevo", "topic", "lyrics", "lyric", "hits", "records", "entertainment",
	"music", "songs", "uploads", "uploader", "channel", "official",
}

// EsCanalDeResubida reporta si [artist] parece un canal de re-subida y no un
// artista. Se usa para ORDENAR, nunca para rechazar: un candidato que viene de
// un canal de re-subida es más probable que un homónimo de otro artista real.
func EsCanalDeResubida(artist string) bool {
	low := strings.ToLower(strings.TrimSpace(artist))
	if low == "" {
		return false
	}
	for _, marca := range canalesResubida {
		if strings.Contains(low, marca) {
			return true
		}
	}
	return false
}

// evidenciaArtista reporta si el campo Artist del candidato se puede relacionar
// con la consulta pedida, aunque sea de forma débil: coincidencia de tokens, el
// artista real dentro del título (re-subidos de SoundCloud/YouTube: "Shakira -
// DAI DAI" subido por "minecraftdiablo") o un canal de re-subida reconocible.
//
// Por qué importa: en el último recurso por nombre, varias canciones distintas
// comparten el MISMO título. Sin evidencia de artista, un homónimo de otro
// artista real (o un cover sin marcador: "karaoke" no siempre viene en el
// título) se veía igual de bueno que el re-subido de la canción pedida, y el
// ranking podía servir la versión equivocada.
func evidenciaArtista(queryArtist string, t TrackResult) bool {
	if strings.TrimSpace(queryArtist) == "" {
		return false
	}
	if FieldScore(queryArtist, t.Artist) >= 1 {
		return true
	}
	return artistaEnTituloDelCandidato(queryArtist, t) || EsCanalDeResubida(t.Artist)
}

// OriginalStrength reports whether the candidate is the ORIGINAL track for the
// query and how strongly (combined title+artist score). Strong title (>=2) is
// required; the artist may be strong (>=2), OR appear inside the title (common
// SoundCloud re-uploads), OR be exact while the title differs only in token
// order/extra words ("(feat. X) [bonus track]" vs "[bonus track] (feat. X)").
// A title es solo rejected como un variant cuando su non-original markers (remix,// live, cover...) are absent from the QUERY title too — official titles like
// "MORNING DEW (DONK) REMIX" are accepted.
func OriginalStrength(queryTitle, queryArtist string, t TrackResult) (float64, bool) {
	tt := FieldScore(queryTitle, t.Title)
	aa := FieldScore(queryArtist, t.Artist)
	if tt < 2 {
		return tt + aa, false
	}
	// El marcador de versión puede estar en el título, en el artista o en el
	// álbum: cada catálogo lo pone donde lo tiene (ver IsNonOriginalTrack).
	if IsNonOriginalTrack(t, queryTitle, queryArtist) {
		return tt + aa, false
	}
	strong := aa >= 2
	if !strong && artistaEnTituloDelCandidato(queryArtist, t) {
		strong = true
	}
	return tt + aa, strong
}

// RankOriginalCandidates orders [results] best-first for fallback resolution:
// first every strict ORIGINAL match (strong title + plausible artist), then a
// best-effort pass that keeps candidates whose TITLE strongly matches the query
// even when the Artist field holds an uploader/lyrics channel (SoundCloud/YouTube
// re-uploads: "Manuel Turizo – La Bachata" uploaded by "Anna pham"). Variants
// relative to the query (remix/live/cover when the query lacks them) and tracks
// with a weak title are still excluded, so a different song is never served.
//
// Dentro del último recurso, los candidatos con ALGUNA evidencia de artista
// (evidenciaArtista) van primero. Nunca se descarta a nadie: el orden cambia,
// la disponibilidad no.
func RankOriginalCandidates(queryTitle, queryArtist string, results []TrackResult) []TrackResult {
	var out []TrackResult
	seen := map[int]bool{}
	// Pass 1: strict originals, best first.
	for i := range results {
		s, ok := OriginalStrength(queryTitle, queryArtist, results[i])
		if ok {
			out = append(out, results[i])
			seen[i] = true
			_ = s
		}
	}
	// Pass 2: best-effort — strong title, non-variant relative to the query.
	// Se usa solo cuando no existe ningún original estricto (el caso típico: el
	// artista real va dentro del título y el campo Artist es el canal).
	//
	// El puntaje es el MISMO que usa el desempate por duración
	// (puntajeEfectivo), que ya incluye un bonus por evidencia de artista: un
	// homónimo de otro artista real, o un cover sin marcador, queda detrás de un
	// candidato relacionable con la consulta — pero NUNCA se descarta.
	if len(out) == 0 {
		type cand struct {
			idx   int
			score float64
		}
		eff := make([]cand, 0, len(results))
		for i := range results {
			tt := FieldScore(queryTitle, results[i].Title)
			if tt < 2 || IsNonOriginalTrack(results[i], queryTitle, queryArtist) {
				continue
			}
			eff = append(eff, cand{i, puntajeEfectivo(queryTitle, queryArtist, results[i])})
		}
		// Best first, stable.
		for x := 1; x < len(eff); x++ {
			for y := x; y > 0 && eff[y-1].score < eff[y].score; y-- {
				eff[y-1], eff[y] = eff[y], eff[y-1]
			}
		}
		for _, e := range eff {
			out = append(out, results[e.idx])
		}
	}
	return out
}

// BestOriginal picks the strongest candidate that is an ORIGINAL match, or nil.
func BestOriginal(queryTitle, queryArtist string, results []TrackResult) *TrackResult {
	ranked := RankOriginalCandidates(queryTitle, queryArtist, results)
	if len(ranked) == 0 {
		return nil
	}
	return &ranked[0]
}
