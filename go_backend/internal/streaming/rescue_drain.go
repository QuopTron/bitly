package streaming

import (
	"sync/atomic"
	"time"
)

// needs verification usually fails in ~1s, while a working provider may take a
// few seconds to resolve (e.g. youtube search + stream extraction ~2-4s). The
// grace must be generous enough that a verify-blocked provider (deezer
// VERIFY_REQUIRED) NEVER preempts a slower but genuinely playable source — a
// deezer-verify-blocked track must fall back to youtube/soundcloud instead of
// failing playback.
// NO bajar de 4s: un proveedor bloqueado por verificación falla en ~1s mientras
// una fuente que SÍ suena (youtube search + extracción ~2-4s) tarda más. El
// veredicto de verificación solo puede ganar si ninguna fuente real apareció en
// esta ventana — bajarla hacía que un deezer-verify preemptara a youtube y la
// canción no sonara (TestRescueRaceVerifyGraceSlowStreamWins).
const verifyGrace = 4 * time.Second

// drainResults collects race results until either every worker finished, a
// verification signal arrived (honored after a short grace), or the shared
// deadline passes, honoring provider order when several finish together. A
// fresh timer per call is used (never a consumed one) so returning from the
// spawn loop on deadline can't wedge on an already-fired channel.
// [bloqueantesEnVuelo] es atómico porque hay bloqueantes que arrancan (o se
// rinden) MIENTRAS el colector ya está leyendo: los intentos encolados esperan
// un turno del pool después de que la carrera arrancó.
//
// [bloqueantesEnVuelo] y [pol] implementan la preferencia por la MEJOR fuente:
// un resultado retenido (un re-subido como YouTube/YouTube Music/SoundCloud, o
// —cuando la calidad pedida es sin pérdida— cualquier fuente que no pueda dar
// FLAC) no gana de inmediato si todavía quedan bloqueantes intentándolo: espera
// la gracia de la política. Y si mientras espera llega un retenido MEJOR (un
// FLAC real en vez de un transcodificado), el que espera se reemplaza: no se
// descarta lo bueno por haber respondido tarde. Se acepta igual si el
// bloqueante llega a tiempo, si todos terminaron, o si la gracia expira (una
// canción sonando es mejor que un fallo de reproducción).
func recogerResultados(results <-chan rescueOut, verifyCh <-chan string, deadline *time.Time, bloqueantesEnVuelo *int32, pol politicaCarrera) (string, string, bool) {
	var verifyName string
	var graceCh <-chan time.Time
	var graceTimer *time.Timer
	// Resultado de re-subido retenido a la espera de una fuente exacta.
	var pendiente *rescueOut
	for {
		select {
		case r, abierto := <-results:
			if !abierto {
				// Todos los workers terminaron Y el buffer ya se entregó entero
				// (Go marca el cierre solo después de los valores encolados), así
				// que acá no queda ningún stream por leer: es el momento seguro de
				// cerrar la carrera sin arriesgar un resultado perdido.
				if graceTimer != nil {
					graceTimer.Stop()
				}
				if pendiente != nil {
					return pendiente.url, pendiente.name, false
				}
				if verifyName != "" {
					return "", verifyName, true
				}
				return "", "", false
			}
			if r.finBloqueante {
				// Un bloqueante terminó sin stream (o se quedó sin turno). Si era el
				// último, ya no hay NADA que pueda mejorar lo retenido dentro de
				// esta fase: se sirve YA, sin esperar a que expire la gracia (que
				// era tiempo muerto puro).
				if atomic.LoadInt32(bloqueantesEnVuelo) > 0 {
					atomic.AddInt32(bloqueantesEnVuelo, -1)
				}
				// Con una verificación de sesión pendiente se mantiene la espera
				// (verifyGrace): mostrar el modal para desbloquear el FLAC sigue
				// teniendo sentido mientras esa decisión está en el aire.
				if atomic.LoadInt32(bloqueantesEnVuelo) == 0 && pendiente != nil && verifyName == "" {
					if graceTimer != nil {
						graceTimer.Stop()
					}
					return pendiente.url, pendiente.name, false
				}
				continue
			}
			if r.url == "" {
				continue
			}
			// Un resultado de una fuente que no es la preferida (re-subido, o
			// lossy cuando se pidió sin pérdida) no le gana a una mejor que
			// todavía puede llegar: se retiene mientras queden bloqueantes.
			// Si ya había uno retenido y este es MEJOR (p. ej. un FLAC real
			// después de un 320kbps), reemplaza al que esperaba.
			if pol.retiene(r.name) && atomic.LoadInt32(bloqueantesEnVuelo) > 0 {
				if pendiente == nil || pol.prefiere(r.name, pendiente.name) {
					rr := r
					pendiente = &rr
					// Reemplaza cualquier timer previo (p. ej. el de la gracia de
					// verificación) por el de la política.
					if graceTimer != nil {
						graceTimer.Stop()
					}
					graceTimer = time.NewTimer(pol.graciaEfectiva())
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
		case <-time.After(time.Until(*deadline)):
			if graceTimer != nil {
				graceTimer.Stop()
			}
			if pendiente != nil {
				return pendiente.url, pendiente.name, false
			}
			if verifyName != "" {
				return "", verifyName, true
			}
			return "", "", false
		}
	}
}
