// bench_carrera_test.go — Carrera de descargas (consumeCandidates).
//
// Qué se mide y por qué así:
//
//   - Se llama a consumeCandidates DIRECTO, no a Download(): Download agrega
//     enriquecimiento de ISRC, resolución en paralelo y el rescate por video
//     oficial, que son llamadas de RED. Meterlas acá convertiría el benchmark
//     en una medición de internet. Lo que se quiere medir es la maquinaria de
//     la carrera: feeder, goroutines de intento, canales, evaluación del
//     resultado y corte.
//   - El logger se silencia: cada candidata fallida imprime una línea, y con
//     miles de iteraciones eso sería medir la consola, no la carrera. En el
//     aparato ese mismo log va a logcat, así que tampoco es representativo.
//   - Reutiliza proveedorFalso / audioFLAC / servidorStream de
//     descarga_integration_test.go para no inventar dobles nuevos.
//
// Se corre con:
//
//	go test ./internal/download -run '^$' -bench BenchmarkCarrera -benchmem
package download

import (
	"fmt"
	"io"
	"log"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// silenciarLogCarrera apaga el logger durante el benchmark y lo restaura al
// terminar.
func silenciarLogCarrera(b *testing.B) {
	b.Helper()
	previo := log.Writer()
	log.SetOutput(io.Discard)
	b.Cleanup(func() { log.SetOutput(previo) })
}

// BenchmarkCarreraGanaElPrimero mide la carrera cuando la fuente dueña entrega
// el archivo: es el caso normal (una sola candidata en el try-list) y su costo
// es la maquinaria de la carrera + la escritura a disco del audio.
func BenchmarkCarreraGanaElPrimero(b *testing.B) {
	silenciarLogCarrera(b)

	srv := servidorStream(audioFLAC())
	defer srv.Close()

	p := &proveedorFalso{nombre: "bench-carrera-ok", streamURL: srv.URL + "/stream.flac"}
	reg := provider.NewRegistry()
	reg.Register(p)
	o := NewOrchestrator(reg)

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		// La preparación (carpeta nueva por iteración, alta en el tracker) no
		// es parte de lo que se mide.
		b.StopTimer()
		req := Request{
			ItemID:   fmt.Sprintf("bench_ok_%d", i),
			Title:    "Cancion de prueba",
			Artist:   "Artista de prueba",
			Provider: p.nombre,
			TrackID:  "bench-id-1",
			Quality:  "LOSSLESS",
		}
		o.tracker.Add(req.ItemID, req.Title, req.Provider)
		dir := b.TempDir()
		st := &fallbackState{fallbackStart: time.Now()}
		feeder := o.nuevoFeeder([]string{p.nombre}, req, req.ISRC, st)
		b.StartTimer()

		res := o.consumeCandidates(feeder, req, dir, st)

		if res == nil || !res.Success || res.FilePath == "" {
			b.Fatalf("la carrera debía ganar con archivo en disco, devolvió %+v", res)
		}
	}
}

// BenchmarkCarreraSinCandidatos mide lo que pasa cuando NINGUNA fuente puede
// entregar audio: la carrera tiene que devolver el fallo ENSEGUIDA.
//
// Este es el benchmark de regresión del bug que hacía que una descarga
// condenada a fallar tardara los 50 s completos del presupuesto en avisar
// (el bucle se quedaba dormido esperando un evento que nunca llegaba). Si
// alguna vez vuelve a pasar, acá se ve como microsegundos contra minutos.
//
// El proveedor devuelve URL vacía SIN error a propósito: así no marca cooldown
// y todas las iteraciones recorren exactamente el mismo camino.
func BenchmarkCarreraSinCandidatos(b *testing.B) {
	silenciarLogCarrera(b)

	sinStream := &proveedorFalso{nombre: "bench-carrera-fallo"}
	reg := provider.NewRegistry()
	reg.Register(sinStream)
	o := NewOrchestrator(reg)

	dir := b.TempDir()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		b.StopTimer()
		req := Request{
			ItemID:   fmt.Sprintf("bench_fallo_%d", i),
			Title:    "Cancion de prueba",
			Artist:   "Artista de prueba",
			Provider: sinStream.nombre,
			TrackID:  "bench-id-2",
			Quality:  "LOSSLESS",
		}
		o.tracker.Add(req.ItemID, req.Title, req.Provider)
		st := &fallbackState{fallbackStart: time.Now()}
		feeder := o.nuevoFeeder([]string{sinStream.nombre}, req, req.ISRC, st)
		b.StartTimer()

		inicio := time.Now()
		res := o.consumeCandidates(feeder, req, dir, st)
		tardanza := time.Since(inicio)

		if res != nil {
			b.Fatalf("no debía ganar ninguna fuente, devolvió %+v", res)
		}
		// El presupuesto real es de 50 s. Cualquier cosa por encima de 1 s acá
		// significa que la carrera volvió a esperar el presupuesto.
		if tardanza > time.Second {
			b.Fatalf("el fallo tardó %s: la carrera volvió a esperar el presupuesto", tardanza)
		}
	}
}
