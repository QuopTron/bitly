package gobackend

import (
	"encoding/json"
	"os"
	"sort"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// TestTapDiagE2E mide el camino del TOQUE real (el que usa el reproductor con
// allowFallback=true) contra los proveedores reales: primero la fase de
// IDENTIFICADORES de RescueStreamURL y después el rescate. Los logs de Go no
// llegan a logcat en Android (el stderr nativo del proceso va a /dev/null), así
// que el arnés del host es la única forma de leer estos números en un aparato
// —el mismo método con el que se construyó la tabla de latencia de la fase de
// metadata.
//
// Qué decide este número: si "identificadores" se come un segundo o más del
// toque, esa fase serial delante del rescate vale la pena atacarla; si son unos
// cientos de milisegundos, el tiempo está donde ya está instrumentado el
// rescate. Ver la nota de latencia en streaming.RescueStreamURL.
//
// Se llama a RescueStreamURL (y no a GetStreamPackage con allowFallback=true) a
// propósito: así se mide la resolución del stream SIN riesgo de caer en la
// descarga de respaldo, que es lenta y escribe en disco.
//
// Run: cd go_backend && BITLY_STREAM_DIAG=1 go test ./internal/gobackend -run TestTapDiagE2E -count=1 -v -timeout 600s
//
// Para probar UNA canción concreta, pasá el payload completo en
// BITLY_STREAM_DIAG_PAYLOAD:
//
//	BITLY_STREAM_DIAG=1 BITLY_STREAM_DIAG_PAYLOAD='{"preferredProvider":"youtube","quality":"flac","trackName":"BbY WOW","artistName":"KAROL G","durationMs":225000,"allowFallback":true}' go test ./internal/gobackend -run TestTapDiagE2E -count=1 -v -timeout 600s
func TestTapDiagE2E(t *testing.T) {
	if os.Getenv("BITLY_STREAM_DIAG") == "" {
		t.Skip("set BITLY_STREAM_DIAG=1 to run the real-network tap diagnostic")
	}
	// La suite apaga la caché de URLs de stream (streaming/main_test.go); acá
	// se mide lo que corre el USUARIO, así que se vuelve a encender.
	streaming.MemoStreamURL(true)
	t.Cleanup(func() { streaming.MemoStreamURL(false) })
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	// Bitly: con BITLY_STREAM_DIAG_PAYLOAD se prueba UNA canción concreta (el
	// payload completo de GetStreamPackage) en vez de la lista curada.
	if extra := os.Getenv("BITLY_STREAM_DIAG_PAYLOAD"); extra != "" {
		correrCasoTap(t, "env", extra)
		return
	}

	// Mismos casos que TestStreamDiagE2E (fuentes preview/DRM: spotify-web,
	// apple-music, amazon), que son justo los que NO entran por StreamQuick y
	// por lo tanto sí pasan por la fase de identificadores.
	cases := []struct{ label, payload string }{
		{
			"spotify-web→Columbia Quevedo (BK4DA2310533)",
			`{"preferredProvider":"spotify-web","trackID":"6XbtvPmIpyCbjuT0e8cQtp","quality":"high","fetchLyrics":"false","trackName":"Columbia","artistName":"Quevedo","isrc":"BK4DA2310533","durationMs":212000,"spotifyId":"6XbtvPmIpyCbjuT0e8cQtp","allowFallback":true}`,
		},
		{
			"apple-music→El Clavo Remix (USSD11800222)",
			`{"preferredProvider":"apple-music","trackID":"2UU1XiId16k6Bz1g8M9hnC","quality":"high","fetchLyrics":"false","trackName":"El Clavo (feat. Maluma) - Remix","artistName":"Prince Royce, Maluma","isrc":"USSD11800222","durationMs":204000,"spotifyId":"2UU1XiId16k6Bz1g8M9hnC","allowFallback":true}`,
		},
		{
			"amazon→Percuma Mahalini (sin isrc)",
			`{"preferredProvider":"amazon","trackID":"B0D9XYZ","quality":"high","fetchLyrics":"false","trackName":"Percuma","artistName":"Mahalini","isrc":"","durationMs":250000,"allowFallback":true}`,
		},
		{
			"apple-music→neo roneo (USWB12403528)",
			`{"preferredProvider":"apple-music","trackID":"7zoVtzzASRtacCvgQKLFaS","quality":"high","fetchLyrics":"false","trackName":"neo roneo","artistName":"rusowsky, LATIN MAFIA","isrc":"USWB12403528","durationMs":186000,"spotifyId":"7zoVtzzASRtacCvgQKLFaS","allowFallback":true}`,
		},
	}

	for _, c := range cases {
		correrCasoTap(t, c.label, c.payload)
	}
}

// correrCasoTap mide un payload contra los proveedores reales, registra el
// tiempo total, el proveedor ganador y la URL, y DEVUELVE esa resolución sin
// recortar para que el llamador pueda hacer sus propias aserciones (ver
// exigirFLACEnElTap en tap_canciones_nuevas_test.go).
func correrCasoTap(t *testing.T, label, payload string) (string, string, error) {
	t.Helper()
	var p streamPackageParams
	if err := json.Unmarshal([]byte(payload), &p); err != nil {
		t.Fatalf("payload inválido (%s): %v", label, err)
	}
	// El contador de peticiones HTTP se reinicia ANTES de cada caso, así el
	// total que sale en el log es exactamente lo que costó ESTE tap. Ver
	// httpclient/conteo.go.
	httpclient.ReiniciarConteo()
	start := time.Now()
	url, prov, err := streaming.RescueStreamURL(reg, p.Quality, p.ISRC, p.SpotifyID, p.DeezerID, p.TidalID, p.QobuzID, p.TrackName, p.ArtistName, p.AlbumName, p.DurationMS)
	elapsed := time.Since(start).Round(time.Millisecond)
	recortada := url
	if len(recortada) > 90 {
		recortada = recortada[:90] + "..."
	}
	t.Logf("[%s] TOTAL=%s provider=%q url=%q error=%v", label, elapsed, prov, recortada, err)
	logRedTap(t, label, elapsed)
	return url, prov, err
}

// logRedTap saca el desglose de peticiones HTTP por host de UN tap: es el
// número que dice cuántas idas a la red cuesta el toque y contra qué hosts,
// que es lo que decide por dónde atacar la optimización.
func logRedTap(t *testing.T, label string, elapsed time.Duration) {
	t.Helper()
	estado := httpclient.EstadoConteo()
	t.Logf("[%s] RED=%d peticiones en %v (ventana de %.2f s)",
		label, estado.Total, elapsed.Round(time.Millisecond), estado.Segundos)
	if estado.Otros > 0 {
		t.Logf("[%s] RED=%d peticiones a hosts fuera del tope del mapa", label, estado.Otros)
	}

	type par struct {
		host string
		n    int64
	}
	pares := make([]par, 0, len(estado.PorHost))
	for h, n := range estado.PorHost {
		pares = append(pares, par{h, n})
	}
	sort.Slice(pares, func(i, j int) bool {
		if pares[i].n != pares[j].n {
			return pares[i].n > pares[j].n
		}
		return pares[i].host < pares[j].host
	})
	const tope = 10
	for i, p := range pares {
		if i >= tope {
			t.Logf("[%s] RED=… y %d hosts más", label, len(pares)-tope)
			break
		}
		t.Logf("[%s] RED   %5d  %s", label, p.n, p.host)
	}
}
