package streaming

import "github.com/zarz/bitly/go_backend/internal/provider"

// ordenProvidersStreaming devuelve las fuentes de AUDIO registradas, en el
// orden de proveedoresAudio.
//
// Qué cambió y por qué: antes esta lista se armaba con streamingProviders
// (todos los que saben streamear, catálogos incluidos) y filtraba por
// DownloadCapable. Eso metía en la carrera a spotify-web/qobuz-web/tidal-web/
// amazon/apple-music, que sin sesión firmada no pueden resolver una URL: en el
// emulador eso significaba que la fase exacta gastaba 1,5-5,8s (y hasta 6,4s en
// otros temas) devolviendo nada, retrasando el turno del re-subido que SÍ tenía
// el audio (ytmusic-spotiflac), y ocupando slots del pool de workers.
//
// Decisión de producto: los catálogos sirven para BUSCAR (identidad, ISRC, ids
// cross-proveedor), no para streamear. El audio sale de YouTube —sí o sí— y,
// cuando se pidió sin pérdida, de Internet Archive / Soulseek / flac-rescue.
// Ver proveedoresAudio en play_types.go.
//
// Se sigue filtrando por DownloadCapable(): una extensión registrada que no
// sabe resolver audio no puede aportar un stream, y sondearla solo cuesta un
// turno del pool.
func ordenProvidersStreaming(reg *provider.Registry) []string {
	if reg == nil {
		return nil
	}
	out := make([]string, 0, len(proveedoresAudio))
	for _, name := range proveedoresAudio {
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
	}
	return out
}

// ordenProvidersStreamingCalidad es ordenProvidersStreaming sabiendo la CALIDAD
// pedida: con un pedido sin pérdida pone primero a las fuentes que pueden darlo
// en vivo (flac-rescue / Internet Archive, ver fuentesLosslessSiempre).
//
// Por qué el orden importa: los turnos de la carrera son pocos (ver
// workersRescate), así que el orden decide QUIÉN alcanza a intentarlo. Medido en
// el emulador: el canal que resuelve el FLAC por ISRC iba cuarto, los que
// streamean ocupaban los dos turnos y el canal se saltaba por falta de slot
// —un tema que el catálogo SÍ tiene ("Tití Me Preguntó" / Bad Bunny, ISRC
// QM6MZ2214878) nunca llegaba a pedirse y la reproducción salía de YouTube—.
// Con un pedido sin pérdida el orden invierte esa prioridad: primero los que
// pueden entregar FLAC de verdad y el re-subido como respaldo, que es
// exactamente lo que la política de confianza hace con el RESULTADO.
func ordenProvidersStreamingCalidad(reg *provider.Registry, quality string) []string {
	todos := ordenProvidersStreaming(reg)
	if !calidadPideLossless(quality) {
		return todos
	}
	primero := make([]string, 0, len(todos))
	resto := make([]string, 0, len(todos))
	for _, n := range todos {
		if esFuenteLosslessSiempre(n) {
			primero = append(primero, n)
			continue
		}
		resto = append(resto, n)
	}
	return append(primero, resto...)
}

// workersRescate es el paralelismo de una carrera de rescate. Un pedido sin
// pérdida suma UN turno: sin él, la fuente que da el FLAC arranca recién cuando
// un re-subido suelta el suyo y, si nadie lo suelta antes del presupuesto, se
// saltea (ver carreraRescueConFiltro). Con pedidos con pérdida queda en 2, que
// es el valor medido: subirlo disparaba 429 de los proveedores y la tercera
// canción seguida se quedaba sin stream.
func workersRescate(quality string) int {
	if calidadPideLossless(quality) {
		return 3
	}
	return 2
}

// rescueProviderOnce probes ONE provider for a playable stream, honoring the
