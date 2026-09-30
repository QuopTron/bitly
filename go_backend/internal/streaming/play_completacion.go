// ─────────────────────────────────────────────────────────────
// play_completacion.go — La COMPLETACIÓN del paquete de stream, acotada.
//
// Por qué existe: cuando el audio ya está resuelto, lo que le falta al paquete
// (el track resuelto por nombre, las letras) es una MEJORA, nunca un
// requisito. Antes corría en serie y sin techo justo en esa recta final: una
// búsqueda por nombre completa fácilmente medio segundo y GetLyrics puede
// tirar uno o dos, así que el paquete salía tarde aunque el stream llevara
// segundos listo. Era el mismo defecto de forma que se corrigió en
// play_package.go con la metadata, pero en la cola del paquete.
//
// Ahora los dos trabajos se lanzan EN PARALELO y el paquete espera como mucho
// [esperaCompletacionTardia] por los dos juntos. Lo que no llega a tiempo
// sigue en segundo plano y no se pierde:
//
//   - el track deja su resultado en la CACHÉ de metadata (play_metacache.go),
//     así el siguiente pedido de esta misma canción sí lo encuentra completo;
//   - las letras no tienen caché, pero quien las necesita puede pedirlas otra
//     vez por la RPC fetchLyrics (y el reproductor ni las pide en línea: manda
//     fetchLyrics=false).
//
// Se conecta con: play_package.go (la cola del paquete), play_metacache.go.
// Parte del flujo: entrega del paquete de stream al reproductor.
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"log"
	"time"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// esperaCompletacionTardia es lo que el paquete espera por la completación
// DESPUÉS de que el audio ya está. Es una gracia, no un presupuesto: sirve
// para cosechar lo que estaba a la vuelta de la esquina (una búsqueda que
// responde en milisegundos) sin abrirle una ventana a lo que está lejos.
//
// Es `var` para que los tests puedan acortarlo.
var esperaCompletacionTardia = 300 * time.Millisecond

// buscarTrackPorNombre resuelve el track en [proveedor] por nombre y, si algo
// encontró, lo deja en la caché de metadata para el siguiente pedido.
//
// Nunca revienta al llamador: corre dentro de su propia goroutine, y una
// extensión que panicée ahí tumbaría el proceso entero (mismo motivo por el
// que la fase de identidad de play_package.go lleva su recover).
func buscarTrackPorNombre(reg *provider.Registry, proveedor, clave, trackName, artistName string) (t *provider.TrackResult) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[play] completación: pánico buscando %q en %s: %v", trackName+" "+artistName, proveedor, r)
			t = nil
		}
	}()
	if reg == nil {
		return nil
	}
	p := reg.Get(proveedor)
	if p == nil {
		return nil
	}
	results, _ := p.SearchTracks(trackName+" "+artistName, 8)
	if len(results) == 0 {
		return nil
	}
	t = provider.BestOriginal(trackName, artistName, results)
	if t != nil {
		guardarMetadata(clave, t)
	}
	return t
}

// pedirLetras busca las letras en su cliente. Igual que la búsqueda de arriba:
// con recover, porque también corre suelta y las fuentes son extensiones.
func pedirLetras(lyricsClient *lyrics.Client, trackName, artistName string) (l *lyrics.Lyrics) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[play] completación: pánico buscando letras de %q: %v", trackName+" "+artistName, r)
			l = nil
		}
	}()
	if lyricsClient == nil {
		return nil
	}
	lyr, err := lyricsClient.GetLyrics(trackName, artistName, 0)
	if err != nil {
		return nil
	}
	return lyr
}
