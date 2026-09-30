package gobackend

import (
	"os"
	"strings"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// TestTapCancionesNuevasE2E es el arnés de TAP ampliado: mismas mediciones que
// TestTapDiagE2E (tiempo total, proveedor ganador, desglose de red por host)
// sobre canciones que NO están en la lista curada — los ISRC salen del logcat
// de la app real, así que son los que el usuario toca de verdad.
//
// Por qué hacía falta: la lista curada son cuatro temas de siempre. Con el
// rescate sin pérdida optimizado (cascada desde Ajustes + relay en FLAC +
// pausa del relay) hace falta ver el efecto en temas NUEVOS, y sobre todo en la
// SEGUNDA vuelta del mismo tema: es donde debe aparecer la caché (una sola
// carrera por canción, no una por nivel de calidad que el streaming prueba).
//
// Cada caso imprime la línea de la fase de identificadores y el [rescate]
// carrera con el ms de CADA canal (ver resolucion_carrera.go): entre las dos se
// ve si los segundos se van en un canal colgado antes de contestar o en el
// presupuesto de la fase que lo espera.
//
// Run: cd go_backend && BITLY_STREAM_DIAG_CANCIONES=1 go test ./internal/gobackend \
//
//	-run TestTapCancionesNuevasE2E -count=1 -v -timeout 600s
func TestTapCancionesNuevasE2E(t *testing.T) {
	if os.Getenv("BITLY_STREAM_DIAG_CANCIONES") == "" {
		t.Skip("define BITLY_STREAM_DIAG_CANCIONES=1 para medir contra las fuentes reales")
	}
	// Igual que los otros arneses de tap: la suite apaga la caché de URLs de
	// stream (streaming/main_test.go) y acá se mide lo que corre el USUARIO.
	streaming.MemoStreamURL(true)
	t.Cleanup(func() { streaming.MemoStreamURL(false) })
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)

	cases := []struct{ label, payload string }{
		{
			// El tema que el código cita como "el catálogo SÍ lo tiene" (ver
			// ordenProvidersStreamingCalidad): sirve de control del canal sin
			// pérdida.
			"flac→Tití Me Preguntó · Bad Bunny (QM6MZ2214878)",
			`{"preferredProvider":"spotify-web","trackID":"3iP6GpBGj3K4uHOGrvRZrB","quality":"flac","fetchLyrics":"false","trackName":"Tití Me Preguntó","artistName":"Bad Bunny","isrc":"QM6MZ2214878","durationMs":240000,"allowFallback":true}`,
		},
		{
			// SEGUNDA vuelta del MISMO ISRC: si la clave de caché está partida
			// por el nivel pedido, acá se paga la carrera de canales otra vez.
			"flac→Tití Me Preguntó (2ª vuelta, mismo ISRC)",
			`{"preferredProvider":"spotify-web","trackID":"3iP6GpBGj3K4uHOGrvRZrB","quality":"flac","fetchLyrics":"false","trackName":"Tití Me Preguntó","artistName":"Bad Bunny","isrc":"QM6MZ2214878","durationMs":240000,"allowFallback":true}`,
		},
		{
			// Mismo ISRC pero pedido CON pérdida: comprueba que el pedido no
			// parte la caché (misma clave) y que igual se intenta el canal sin
			// pérdida como respaldo.
			"high→Tití Me Preguntó (mismo ISRC, pedido con pérdida)",
			`{"preferredProvider":"spotify-web","trackID":"3iP6GpBGj3K4uHOGrvRZrB","quality":"high","fetchLyrics":"false","trackName":"Tití Me Preguntó","artistName":"Bad Bunny","isrc":"QM6MZ2214878","durationMs":240000,"allowFallback":true}`,
		},
		{
			"flac→Moscow Mule · Bad Bunny (AUXN22255214)",
			`{"preferredProvider":"spotify-web","trackID":"6k0B2IZJZ1dnFY008mnzPs","quality":"flac","fetchLyrics":"false","trackName":"Moscow Mule","artistName":"Bad Bunny","isrc":"AUXN22255214","durationMs":246000,"allowFallback":true}`,
		},
		{
			"flac→LA CANCIÓN · J Balvin, Bad Bunny (USUM71911618)",
			`{"preferredProvider":"spotify-web","trackID":"0m0qJwjLXnQTXiq2uXsFcz","quality":"flac","fetchLyrics":"false","trackName":"LA CANCIÓN","artistName":"J Balvin, Bad Bunny","isrc":"USUM71911618","durationMs":242000,"allowFallback":true}`,
		},
		{
			// Fuente distinta (deezer) y SIN ISRC: mide el camino por nombre y
			// el id cross-provider, que es el que más depende del rescate.
			"flac→Ojitos Lindos · Bad Bunny, Bomba Estéreo (deezer, sin isrc)",
			`{"preferredProvider":"deezer","trackID":"1732520167","quality":"flac","fetchLyrics":"false","trackName":"Ojitos Lindos","artistName":"Bad Bunny, Bomba Estéreo","isrc":"","durationMs":258000,"allowFallback":true}`,
		},
	}

	for _, c := range cases {
		url, prov, err := correrCasoTap(t, c.label, c.payload)
		exigirFLACEnElTap(t, c.label, url, prov, err)
	}
}

// exigirFLACEnElTap es la red de REGRESIÓN del canal sin pérdida, detrás de una
// variable de entorno porque depende de la RED y de un relay de TERCEROS: con el
// relay caído (503, cupo agotado) el tap resuelve correctamente por un re-subido
// y exigir FLAC sería un falso fallo.
//
// Con BITLY_STREAM_DIAG_EXIGE_FLAC=1 se afirma que todo tap que consiguió audio
// vino del canal sin pérdida y con `fmt=6` (FLAC 16/44.1 del CDN de Qobuz). Es lo
// que evita volver a YouTube EN SILENCIO si un cambio posterior rompe la cascada
// de formatos, la pausa de un canal o el orden de preferencia — el escenario que
// ya pasó una vez y que costó el FLAC sin que ningún test lo notara.
//
// Run: BITLY_STREAM_DIAG_CANCIONES=1 BITLY_STREAM_DIAG_EXIGE_FLAC=1 go test ./internal/gobackend -run TestTapCancionesNuevasE2E -v
func exigirFLACEnElTap(t *testing.T, label, url, prov string, err error) {
	t.Helper()
	if os.Getenv("BITLY_STREAM_DIAG_EXIGE_FLAC") == "" {
		return
	}
	if err != nil || url == "" {
		t.Errorf("[%s] no resolvió audio: %v", label, err)
		return
	}
	if prov != "flac-rescue" {
		t.Errorf("[%s] ganó %q y no el canal sin pérdida; con el relay vivo el FLAC debería ganar", label, prov)
		return
	}
	if !strings.Contains(url, "fmt=6") {
		t.Errorf("[%s] flac-rescue devolvió un formato con pérdida: %s", label, url)
	}
}
