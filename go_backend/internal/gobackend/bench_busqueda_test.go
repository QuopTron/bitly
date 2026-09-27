// bench_busqueda_test.go — Camino caliente de la búsqueda por streaming.
//
// Por qué estos tres puntos y no otros:
//
//	GetSearchStreamResults  Flutter sondea esto cada ~80 ms durante TODA la
//	                        ventana de búsqueda (~160 sondeos por consulta).
//	                        Es, de lejos, la función más llamada del backend.
//	itemsAJSON              frontera de la API: serializa los items una vez por
//	                        fuente cuando el camino NO es el streaming.
//	anexarSearchStream      lo que corre MIENTRAS las fuentes responden: dedup
//	                        del lote contra el buffer y propagación de ISRC.
//	                        Era O(n²) (barrido lineal por item nuevo + doble
//	                        barrido en la propagación); desde el índice de
//	                        dedup es O(k·n) con k = fuentes que responden.
//	                        Hay dos formas de lote: una con todos los ISRC
//	                        (el caso barato) y otra con la mitad (el realista).
//
// El tamaño 120 es el de un resultado real de "Todas" (~112 items medidos en
// la optimización anterior), así que los números de acá son los del aparato.
//
// Se corre con:
//
//	go test ./internal/gobackend -run '^$' -bench BenchmarkBusqueda -benchmem
package gobackend

import (
	"fmt"
	"testing"
)

// itemsBusquedaBench arma N items con la forma y el peso de un resultado real
// (nombre, artistas, carátula, ids cross-provider, ISRC). El tamaño del JSON
// depende de estos campos: un item "pelado" mediría menos de lo que mide de
// verdad y el benchmark mentiría.
func itemsBusquedaBench(n int) []FeedItemGo {
	items := make([]FeedItemGo, n)
	for i := range items {
		items[i] = FeedItemGo{
			ID:          fmt.Sprintf("tidal:%d", 100000+i),
			Type:        "track",
			Name:        fmt.Sprintf("Cancion de prueba numero %d", i),
			Artists:     "Artista Ejemplo, Otro Artista",
			CoverURL:    fmt.Sprintf("https://resources.tidal.com/images/abcdef01/%d/640x640.jpg", i),
			Source:      "tidal-web",
			AlbumID:     fmt.Sprintf("album-%d", i/10),
			AlbumName:   "Album de Ejemplo (Deluxe Edition)",
			DurationMs:  200000 + i,
			ReleaseDate: "2024-05-17",
			ISRC:        fmt.Sprintf("USUM7%07d", i),
			SpotifyID:   fmt.Sprintf("4uLU6hMCjMI75M1A2tKUQC%d", i%10),
			DeezerID:    fmt.Sprintf("%d", 900000+i),
			TidalID:     fmt.Sprintf("%d", 100000+i),
		}
	}
	return items
}

// fijarBufferBusqueda deja el buffer de la búsqueda en un estado conocido con
// la respuesta serializada INVALIDADA: el próximo sondeo tiene que reconstruir
// el JSON completo, que es lo que pasa cada vez que entra un lote nuevo.
func fijarBufferBusqueda(items []FeedItemGo, gen int64) {
	currentSearchStream.mu.Lock()
	currentSearchStream.generation = gen
	currentSearchStream.items = items
	currentSearchStream.done = true
	currentSearchStream.fallidas = nil
	currentSearchStream.fuentesOk = 8
	currentSearchStream.jsonCache = ""
	currentSearchStream.mu.Unlock()
}

// ── Sondeo del streaming de búsqueda ─────────────────────────────────────

// BenchmarkBusquedaPollCacheado es el sondeo NORMAL: llegó el primer sondeo, el
// resto de la ventana no trae novedades, así que se devuelve la respuesta ya
// serializada. Este es el caso que se paga ~160 veces por búsqueda.
func BenchmarkBusquedaPollCacheado(b *testing.B) {
	items := itemsBusquedaBench(120)
	fijarBufferBusqueda(items, 1)
	// Un sondeo fuera de la medición: con esto el jsonCache ya está tibio.
	if GetSearchStreamResults() == "" {
		b.Fatal("sondeo inicial vacío")
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if GetSearchStreamResults() == "" {
			b.Fatal("respuesta vacía")
		}
	}
}

// BenchmarkBusquedaPollSerializando es el sondeo que SÍ tiene que trabajar:
// llegó un lote nuevo (o cambió `done`), se copia la lista entera y se vuelve a
// serializar. Mide el techo del sondeo.
func BenchmarkBusquedaPollSerializando(b *testing.B) {
	items := itemsBusquedaBench(120)

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fijarBufferBusqueda(items, int64(i)+1)
		if GetSearchStreamResults() == "" {
			b.Fatal("respuesta vacía")
		}
	}
}

// BenchmarkBusquedaItemsAJSON mide la frontera de serialización cruda (lo que
// el camino NO-streaming paga una vez por fuente).
func BenchmarkBusquedaItemsAJSON(b *testing.B) {
	for _, n := range []int{20, 120} {
		items := itemsBusquedaBench(n)
		b.Run(fmt.Sprintf("items=%d", n), func(b *testing.B) {
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				if out := itemsAJSON(items); len(out) < 2 {
					b.Fatal("serialización vacía")
				}
			}
		})
	}
}

// itemsBusquedaBenchISRCParcial arma el lote REALISTA de "Todas": la mitad de
// las fuentes publica el ISRC y la otra mitad no (YouTube y SoundCloud no lo
// traen en la búsqueda). Ese es el caso que hace trabajar a la propagación:
// con todos los items con ISRC el trabajo ni arranca, así que medir solo con
// itemsBusquedaBench escondería justo el camino lento.
func itemsBusquedaBenchISRCParcial(n int) []FeedItemGo {
	items := itemsBusquedaBench(n)
	for i := range items {
		if i%2 == 1 {
			items[i].ISRC = ""
		}
	}
	return items
}

// BenchmarkBusquedaAnexarLoteISRCParcial mide el mismo lote pero con la mitad
// de los ISRC ausentes: la propagación tiene que emparejar por nombre+artista
// normalizados y duración. Antes eso era un doble barrido que recalculaba las
// dos claves en cada par; ahora la clave se calcula una vez por item.
func BenchmarkBusquedaAnexarLoteISRCParcial(b *testing.B) {
	for _, n := range []int{20, 120} {
		lote := itemsBusquedaBenchISRCParcial(n)
		b.Run(fmt.Sprintf("items=%d", n), func(b *testing.B) {
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				b.StopTimer()
				currentSearchStream.mu.Lock()
				currentSearchStream.generation = int64(i) + 1
				currentSearchStream.items = nil
				currentSearchStream.jsonCache = ""
				currentSearchStream.mu.Unlock()
				b.StartTimer()

				anexarSearchStream(int64(i)+1, lote)

				if len(currentSearchStream.items) != n {
					b.Fatalf("se esperaban %d items, quedaron %d", n, len(currentSearchStream.items))
				}
			}
		})
	}
}

// BenchmarkBusquedaAnexarLote mide el trabajo por lote que entra al buffer:
// dedup contra todo lo ya recibido (O(n²)) + propagación de ISRC sobre toda la
// lista. Con varias fuentes respondiendo, esto corre una vez por fuente.
func BenchmarkBusquedaAnexarLote(b *testing.B) {
	for _, n := range []int{20, 120} {
		lote := itemsBusquedaBench(n)
		b.Run(fmt.Sprintf("items=%d", n), func(b *testing.B) {
			b.ReportAllocs()
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				// Fuera de la medición: dejar el buffer vacío es preparación,
				// no el trabajo que se quiere medir.
				b.StopTimer()
				currentSearchStream.mu.Lock()
				currentSearchStream.generation = int64(i) + 1
				currentSearchStream.items = nil
				currentSearchStream.jsonCache = ""
				currentSearchStream.mu.Unlock()
				b.StartTimer()

				anexarSearchStream(int64(i)+1, lote)

				if len(currentSearchStream.items) != n {
					b.Fatalf("se esperaban %d items, quedaron %d", n, len(currentSearchStream.items))
				}
			}
		})
	}
}
