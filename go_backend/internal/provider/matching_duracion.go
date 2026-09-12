package provider

// matching_duracion.go — Desempate por DURACIÓN para el ranking de candidatos.
//
// Por qué existe: las fuentes que no exponen ISRC (YouTube, SoundCloud, y los
// re-subidos) solo pueden identificarse por título/artista, y en esos catálogos
// conviven varias versiones con el MISMO título y el MISMO artista (el video
// oficial, el audio, el lyric video, un re-subido). El puntaje título+artista
// no las distingue, así que el backend podía servir la versión equivocada
// (empezando a mitad de canción, o un corte distinto).
//
// La duración sí las distingue: es el mismo dato que ya usa el verificador de
// descargas (duracionCoincide en download/orchestrator_verify.go). Acá se usa
// como DESEMPATE, nunca como filtro: un candidato sin duración (0) no se
// descarta — SoundCloud y los streams no siempre la traen y rechazarlos dejaría
// esas canciones sin audio.
//
// Se conecta con: matching_original.go (el ranking base) y los llamadores que
// conocen la duración consultada (streaming/rescue_rank.go,
// download/orchestrator_trackid.go).
// Parte del flujo: identificación de la canción buscada.

// duracionDesconocida es el "peso" que se le da a un candidato sin duración al
// desempatar: pierde contra cualquier duración conocida, pero sigue siendo un
// candidato válido (no se descarta).
//
// Se queda en int32 a propósito: el backend se compila también para Android de
// 32 bits (armv7/x86 vía gomobile), donde `int` son 32 bits y un centinela más
// grande no compila. 2^31-1 (≈24 días en ms) excede cualquier distancia real.
const duracionDesconocida = 1<<31 - 1

// distanciaDuracionMS devuelve qué tan lejos está [got] de [query] en ms, o
// duracionDesconocida si el candidato no trae duración.
func distanciaDuracionMS(queryMS, got int) int {
	if queryMS <= 0 || got <= 0 {
		return duracionDesconocida
	}
	diff := queryMS - got
	if diff < 0 {
		diff = -diff
	}
	return diff
}

// puntajeEfectivo replica el puntaje que usa el ranking (matching_original.go):
// título + artista, con el artista contando como fuerte cuando aparece dentro
// del título (re-subidos de SoundCloud/YouTube: "Shakira - DAI DAI" subido por
// "minecraftdiablo"). Se usa solo para decidir QUÉ candidatos están empatados.
func puntajeEfectivo(queryTitle, queryArtist string, t TrackResult) float64 {
	tt := FieldScore(queryTitle, t.Title)
	aa := FieldScore(queryArtist, t.Artist)
	if tt >= 2 && aa < 2 && artistaEnTitulo(queryArtist, t.Title) {
		aa = 2
	}
	return tt + aa
}

// RankOriginalCandidatesDuracion es RankOriginalCandidates más un desempate por
// duración. El orden base (originales primero, variantes excluidas) NO cambia:
// solo se reordenan candidatos con el MISMO puntaje título+artista, prefiriendo
// el que dura lo mismo que la canción consultada. Nunca promueve un candidato
// peor ni descarta uno sin duración — por eso es seguro llamarlo en el camino
// crítico de reproducción.
func RankOriginalCandidatesDuracion(queryTitle, queryArtist string, queryDurationMS int, results []TrackResult) []TrackResult {
	ranked := RankOriginalCandidates(queryTitle, queryArtist, results)
	if len(ranked) < 2 || queryDurationMS <= 0 {
		return ranked
	}
	out := append([]TrackResult(nil), ranked...)
	// Inserción estable por (puntaje desc, distancia de duración asc) DENTRO de
	// cada grupo de puntaje: al no cruzar grupos, un candidato mejor nunca baja.
	for i := 1; i < len(out); i++ {
		for j := i; j > 0; j-- {
			prev, cur := out[j-1], out[j]
			if puntajeEfectivo(queryTitle, queryArtist, prev) != puntajeEfectivo(queryTitle, queryArtist, cur) {
				break
			}
			dPrev := distanciaDuracionMS(queryDurationMS, prev.Duration)
			dCur := distanciaDuracionMS(queryDurationMS, cur.Duration)
			if dCur < dPrev {
				out[j-1], out[j] = out[j], out[j-1]
				continue
			}
			break
		}
	}
	return out
}

// BestOriginalDuracion picks the strongest original match, desempatando por
// duración cuando la fuente no expone ISRC. Devuelve nil si ningún candidato es
// un original válido.
func BestOriginalDuracion(queryTitle, queryArtist string, queryDurationMS int, results []TrackResult) *TrackResult {
	ranked := RankOriginalCandidatesDuracion(queryTitle, queryArtist, queryDurationMS, results)
	if len(ranked) == 0 {
		return nil
	}
	return &ranked[0]
}
