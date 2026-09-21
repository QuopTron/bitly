// ─────────────────────────────────────────────────────────────
// stream_package_lossless.go — Canal SIN PÉRDIDA del camino de
// reproducción: con calidad sin pérdida y un ISRC conocido, el FLAC
// (flac-rescue → arcod / Internet Archive) se resuelve EN PARALELO al
// camino rápido y suena él si llega dentro de la ventana.
//
// Por qué existe: antes, si el proveedor preferido era de stream completo
// (YouTube / yt-dlp), la reproducción devolvía su audio y terminaba ahí
// —el canal que tiene el FLAC nunca se consultaba y su audio aparecía solo
// en las DESCARGAS—.
//
// Se conecta con: stream_package_fallback.go (lo abre y lo consulta) y
// streaming.StreamLosslessPorISRC (la resolución).
// Parte del flujo: reproducción (resolución de stream).
// ─────────────────────────────────────────────────────────────

package gobackend

import (
	"log"
	"time"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// streamSinPerdida es el candidato del canal sin pérdida: la URL del FLAC
// (flac-rescue → arcod / Internet Archive) y quién lo resolvió.
type streamSinPerdida struct {
	url  string
	prov string
}

// abrirCanalSinPerdida lanza la resolución del FLAC por ISRC EN PARALELO.
// Nada bloquea acá: el llamador sigue con el camino rápido y solo mira el
// canal cuando ya tiene un audio. Devuelve nil cuando la calidad no es sin
// pérdida o no hay ISRC, así el resto del código no paga ni un milisegundo.
func abrirCanalSinPerdida(params *streamPackageParams) chan streamSinPerdida {
	if !streaming.CalidadPideLossless(params.Quality) || params.ISRC == "" {
		return nil
	}
	ch := make(chan streamSinPerdida, 1)
	isrc, calidad := params.ISRC, params.Quality
	go func() {
		u, n := streaming.StreamLosslessPorISRC(reg, isrc, calidad)
		ch <- streamSinPerdida{url: u, prov: n}
	}()
	return ch
}

// paqueteConElMejorAudio elige quién suena: el audio ya resuelto por el camino
// rápido o el FLAC que el canal sin pérdida tenga listo dentro de la ventana.
//
// La ventana es CORTA a propósito: el canal resuelve en ~0,6 s cuando tiene el
// tema, y esperar más cambiaría un 320k ya sonando por un FLAC hipotético
// (medido: con 6 s de espera un tap parecía roto). Si el canal no llegó, el
// audio con pérdida suena igual: nunca se pierde la reproducción.
func paqueteConElMejorAudio(ch chan streamSinPerdida, params *streamPackageParams, url, name string) (string, string) {
	if ch == nil || url == "" {
		return url, name
	}
	select {
	case r := <-ch:
		if r.url == "" {
			return url, name
		}
		// Mismo guard que el resto del camino: un clip no es la canción.
		if streaming.EsPreviewStream(r.url, r.prov, params.DurationMS, params.Quality) {
			return url, name
		}
		log.Printf("[play] canal sin pérdida (%s) resolvió en paralelo: suena el FLAC en vez de %s", r.prov, name)
		return r.url, r.prov
	case <-time.After(streaming.VentanaSinPerdida):
		log.Printf("[play] el canal sin pérdida no llegó en %s: sigue %s", streaming.VentanaSinPerdida, name)
		return url, name
	}
}
