package streaming

import (
	"sort"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

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
	enLista := map[string]bool{}
	for _, name := range proveedoresAudio {
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
		enLista[name] = true
	}
	// Las fuentes de la lista fija son las únicas que NO dependen de una sesión.
	// Después se suman —sin tocar la lista— las extensiones cuya sesión firmada
	// ya está lista (cuenta propia o credencial del pool): ésas SÍ pueden
	// entregar audio en vivo, y son justamente las que la política vieja dejaba
	// afuera por no poder resolver sin sesión. Ver fuentesAudioConSesion.
	out = append(out, fuentesAudioConSesion(reg, enLista)...)
	return out
}

// fuentePuedeStreamear informa si [name] puede resolver audio EN VIVO ahora
// mismo. Es una variable a propósito: el backend —el único que ve las
// credenciales guardadas (Ajustes → Credenciales, propias o del pool)— la
// reemplaza en su init con el predicado real; los tests la sustituyen para
// probar el orden sin credenciales de verdad.
//
// Por defecto NADIE puede, que es el comportamiento de fábrica: una extensión
// sin credenciales no resuelve audio y sondearla es tiempo muerto (medido:
// 1,5-5,8s por turno devolviendo nada, que retrasaba al re-subido que sí tenía
// el audio).
var fuentePuedeStreamear = func(name string) bool { return false }

// SetFuenteStreameable instala el predicado de credenciales. Lo llama el
// backend en su init; un valor nil se ignora para no dejar la carrera sin
// predicado.
func SetFuenteStreameable(f func(name string) bool) {
	if f != nil {
		fuentePuedeStreamear = f
	}
}

// fuenteStreameableAhora dice si [name] puede entregar audio en vivo con lo que
// tiene ahora: registrada, con capacidad de descarga (una extensión de metadata
// sin audio nunca entra) y con credenciales listas.
func fuenteStreameableAhora(reg *provider.Registry, name string) bool {
	if reg == nil || esProveedorSoloDescarga(name) {
		return false
	}
	p := reg.Get(name)
	if p == nil {
		return false
	}
	if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
		return false
	}
	return fuentePuedeStreamear(name)
}

// fuentesAudioConSesion son las extensiones que pueden streamear AHORA (sesión
// firmada lista) y que NO están en la lista fija. El orden sale de
// streamingProviders para conservar la preferencia histórica, y después se
// agregan los nombres registrados que falten (p. ej. extensiones que no están
// en esa lista) en orden alfabético para que el resultado sea determinista.
func fuentesAudioConSesion(reg *provider.Registry, ya map[string]bool) []string {
	if reg == nil {
		return nil
	}
	var out []string
	tomar := func(name string) {
		if ya[name] || !fuenteStreameableAhora(reg, name) {
			return
		}
		out = append(out, name)
		ya[name] = true
	}
	for _, name := range streamingProviders {
		tomar(name)
	}
	resto := make([]string, 0, 8)
	for _, name := range reg.Names() {
		if !ya[name] && !esProveedorSoloDescarga(name) {
			resto = append(resto, name)
		}
	}
	sort.Strings(resto)
	for _, name := range resto {
		tomar(name)
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
		// Es lossless "de verdad" la fuente que no depende de sesión
		// (flac-rescue/Internet Archive) o la extensión con sesión lista cuya
		// capacidad es sin pérdida (deezer/qobuz-web/tidal-web/amazon). Así el
		// pedido sin pérdida les da el primer turno también a ellas.
		if esFuenteLosslessSiempre(n) || (esProveedorLossless(n) && fuenteStreameableAhora(reg, n)) {
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
