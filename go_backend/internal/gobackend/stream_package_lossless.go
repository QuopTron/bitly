// ─────────────────────────────────────────────────────────────
// stream_package_lossless.go — Canal SIN PÉRDIDA del camino de
// reproducción: con calidad sin pérdida, el FLAC (flac-rescue → arcod /
// Internet Archive) se resuelve EN PARALELO al camino rápido y suena él
// si llega dentro de la ventana.
//
// Por qué existe: antes, si el proveedor preferido era de stream completo
// (YouTube / yt-dlp), la reproducción devolvía su audio y terminaba ahí
// —el canal que tiene el FLAC nunca se consultaba y su audio aparecía solo
// en las DESCARGAS—.
//
// El ISRC no siempre viene en el pedido (YouTube/SoundCloud no lo publican).
// Cuando falta, el canal lo DERIVA en paralelo con las mismas reglas del
// rescate (provider.DerivarISRC: solo un original verificado por duración) y
// apenas lo tiene pide el FLAC. Así un tema que entra sin ISRC también puede
// preferir el FLAC en vez de quedarse con el stream lossy por nombre.
//
// Se conecta con: stream_package_fallback.go (lo abre y lo consulta),
// streaming.StreamLosslessPorISRC (la resolución) y provider.DerivarISRC
// (la derivación).
// Parte del flujo: reproducción (resolución de stream).
// ─────────────────────────────────────────────────────────────

package gobackend

import (
	"log"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// streamSinPerdida es el candidato del canal sin pérdida: la URL del FLAC
// (flac-rescue → arcod / Internet Archive) y quién lo resolvió.
type streamSinPerdida struct {
	url  string
	prov string
}

// canalSinPerdida es el canal sin pérdida ya abierto. Guarda además el instante
// de apertura y si hay que derivar el ISRC, porque la ventana es TOTAL (desde
// que se abrió) y no por consulta: el llamador puede mirar el canal después del
// proveedor preferido y otra vez después del rescate, y no debe pagar la espera
// completa dos veces.
type canalSinPerdida struct {
	ch        chan streamSinPerdida
	inicio    time.Time
	derivando bool
}

// ventana es el margen total del canal según si hubo que derivar el ISRC.
func (c *canalSinPerdida) ventana() time.Duration {
	if c.derivando {
		return streaming.VentanaSinPerdidaDerivada
	}
	return streaming.VentanaSinPerdida
}

// restante es lo que le queda al canal para cerrar su ventana. Puede ser <= 0:
// entonces ya solo se lo mira sin bloquear (el resultado, si llegó, sigue en el
// buffer del canal y se recoge igual).
func (c *canalSinPerdida) restante() time.Duration {
	return time.Until(c.inicio.Add(c.ventana()))
}

// abrirCanalSinPerdida lanza la resolución del FLAC EN PARALELO. Nada bloquea
// acá: el llamador sigue con el camino rápido y solo mira el canal cuando ya
// tiene un audio. Devuelve nil cuando la calidad no es sin pérdida —así el
// resto del código no paga ni un milisegundo— y también cuando no hay ISRC ni
// con qué derivarlo (título y artista): sin título/artista no hay nada que
// buscar en los catálogos y abrir el canal sería un gasto a fondo perdido.
func abrirCanalSinPerdida(params *streamPackageParams) *canalSinPerdida {
	if !streaming.CalidadPideLossless(params.Quality) {
		return nil
	}
	isrc := params.ISRC
	if isrc == "" && (params.TrackName == "" || params.ArtistName == "") {
		return nil
	}
	c := &canalSinPerdida{
		ch:        make(chan streamSinPerdida, 1),
		inicio:    time.Now(),
		derivando: isrc == "",
	}
	// La copia local de reg evita que la goroutine lea el global mientras
	// otro camino lo reasigna.
	r := reg
	calidad, titulo, artista, dur := params.Quality, params.TrackName, params.ArtistName, params.DurationMS
	go func() {
		if isrc == "" {
			isrc = provider.DerivarISRC(r, titulo, artista, dur)
			if isrc == "" {
				// Sin ISRC no hay FLAC por identidad exacta. Se acusa el
				// final con un vacío para que el llamador no espere su
				// ventana completa por un resultado que ya no va a llegar.
				c.ch <- streamSinPerdida{}
				return
			}
			log.Printf("[play] ISRC derivado en vuelo (%s) para %q/%q: el canal sin pérdida lo consulta", isrc, titulo, artista)
		}
		u, n := streaming.StreamLosslessPorISRC(r, isrc, calidad)
		c.ch <- streamSinPerdida{url: u, prov: n}
	}()
	return c
}

// paqueteConElMejorAudio elige quién suena: el audio ya resuelto por el camino
// rápido o el FLAC que el canal sin pérdida tenga listo dentro de su ventana.
//
// La ventana es CORTA a propósito: el canal resuelve en ~0,6 s cuando tiene el
// tema, y esperar más cambiaría un 320k ya sonando por un FLAC hipotético
// (medido: con 6 s de espera un tap parecía roto). Si el canal no llegó, el
// audio con pérdida suena igual: nunca se pierde la reproducción.
//
// Antes de bloquear se mira el canal SIN esperar: si una consulta anterior ya
// dejó el resultado en el buffer, se recoge aunque la ventana haya cerrado.
func paqueteConElMejorAudio(c *canalSinPerdida, params *streamPackageParams, url, name string) (string, string) {
	if c == nil || url == "" {
		return url, name
	}
	var res streamSinPerdida
	select {
	case res = <-c.ch:
	default:
		select {
		case res = <-c.ch:
		case <-time.After(c.restante()):
			log.Printf("[play] el canal sin pérdida no llegó dentro de su ventana (%s): sigue %s", c.ventana(), name)
			return url, name
		}
	}
	if res.url == "" {
		return url, name
	}
	// Mismo guard que el resto del camino: un clip no es la canción.
	if streaming.EsPreviewStream(res.url, res.prov, params.DurationMS, params.Quality) {
		return url, name
	}
	log.Printf("[play] canal sin pérdida (%s) resolvió en paralelo: suena el FLAC en vez de %s", res.prov, name)
	return res.url, res.prov
}
