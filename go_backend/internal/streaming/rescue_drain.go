package streaming

import "time"

// needs verification usually fails in ~1s, while a working provider may take a
// few seconds to resolve (e.g. youtube search + stream extraction ~2-4s). The
// grace must be generous enough that a verify-blocked provider (deezer
// VERIFY_REQUIRED) NEVER preempts a slower but genuinely playable source — a
// deezer-verify-blocked track must fall back to youtube/soundcloud instead of
// failing playback.
const verifyGrace = 4 * time.Second

// drainResults collects race results until either every worker finished, a
// verification signal arrived (honored after a short grace), or the shared
// deadline passes, honoring provider order when several finish together. A
// fresh timer per call is used (never a consumed one) so returning from the
// spawn loop on deadline can't wedge on an already-fired channel.
// [exactosEnVuelo] y [esReSubido] implementan la preferencia por la fuente
// EXACTA: un resultado de un re-subido (YouTube/YouTube Music/SoundCloud) no
// gana de inmediato si todavía quedan fuentes exactas intentándolo — espera
// [graceExactos]. Se acepta igual si la fuente exacta llega a tiempo, si todas
// terminaron, o si la gracia expira (una canción sonando es mejor que fallar).
func recogerResultados(results <-chan rescueOut, verifyCh <-chan string, done <-chan struct{}, deadline *time.Time, exactosEnVuelo int, esReSubido func(string) bool) (string, string, bool) {
	best := ""
	bestName := ""
	var verifyName string
	var graceCh <-chan time.Time
	var graceTimer *time.Timer
	// Resultado de re-subido retenido a la espera de una fuente exacta.
	var pendiente *rescueOut
	for {
		select {
		case r := <-results:
			if r.url == "" {
				continue
			}
			// Una fuente que solo identifica por nombre no le gana a una exacta
			// que todavía puede llegar: se retiene mientras queden exactas.
			if esReSubido != nil && exactosEnVuelo > 0 && esReSubido(r.name) {
				if pendiente == nil {
					rr := r
					pendiente = &rr
					// Reemplaza cualquier timer previo (p. ej. el de la gracia de
					// verificación) por el de la confianza.
					if graceTimer != nil {
						graceTimer.Stop()
					}
					graceTimer = time.NewTimer(graceExactos)
					graceCh = graceTimer.C
				}
				continue
			}
			// First success wins — and return immediately instead of waiting
			// out the budget: a leaked worker that never closes [done] must
			// not delay an already-resolved stream (that delay is what made
			// para que el segundo tap en una cola no se sienta trabado en 00:00).
			if graceTimer != nil {
				graceTimer.Stop()
			}
			return r.url, r.name, false
		case v := <-verifyCh:
			if verifyName == "" {
				verifyName = v
			}
			if graceTimer == nil {
				graceTimer = time.NewTimer(verifyGrace)
				graceCh = graceTimer.C
			}
			// Keep waiting through the grace for a real stream.
		case <-graceCh:
			// Gracia de confianza vencida: la fuente exacta no llegó a tiempo,
			// se sirve el re-subido (antes que dejar la reproducción sin audio).
			if pendiente != nil {
				if graceTimer != nil {
					graceTimer.Stop()
				}
				return pendiente.url, pendiente.name, false
			}
			// Un proveedor tiene la cancion exacta pero necesita su sesion
			// verificada: no llego stream durante la gracia — se devuelve el
			// veredicto para que el cliente abra el modal en vez de que el
			// llamador queme 10-30s en un walk de respaldo condenado.
			return "", verifyName, true
		case <-done:
			if graceTimer != nil {
				graceTimer.Stop()
			}
			if pendiente != nil {
				return pendiente.url, pendiente.name, false
			}
			if verifyName != "" && best == "" {
				return "", verifyName, true
			}
			return best, bestName, false
		case <-time.After(time.Until(*deadline)):
			if graceTimer != nil {
				graceTimer.Stop()
			}
			if pendiente != nil {
				return pendiente.url, pendiente.name, false
			}
			if verifyName != "" && best == "" {
				return "", verifyName, true
			}
			return best, bestName, false
		}
	}
}
