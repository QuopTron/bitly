package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// ─────────────────────────────────────────────────────────────
// feed_fuentes_diag_test.go — Arnés del MATCHING ENTRE FUENTES.
//
// Por qué existe: la metadata de cada catálogo no es la de los demás. Amazon
// devuelve "KAROL G, Judeline & rusowsky" y duración 0; Apple devuelve
// "KAROL G, Judeline & rusowsky" con 225.835 ms; YouTube Music devuelve
// "KAROL G, rusowsky"; SoundCloud sólo tiene re-subidos. Una canción pedida
// desde cualquiera de esas fuentes tiene que terminar SONANDO, y el único modo
// de saberlo es medirlo fuente por fuente.
//
// Dos caminos, los dos del reproductor real:
//
//	TestTapTodasLasFuentesE2E — pide la canción a CADA fuente (como el detalle)
//	                            y toca con la metadata de esa fuente.
//	TestFeedTapItemsE2E       — toma los items del HOME FEED que coinciden con
//	                            la canción y los toca como los toca la app,
//	                            comprobando que la URL entregada sirve audio.
//
// El segundo es el que detectó el bug medido: el CDN del canal arcod contestaba
// 502 y la URL muerta llegaba igual al reproductor ("en el feed de Amazon me da
// reproducir y no es"), mientras la búsqueda en YouTube sí sonaba.
//
// Run:
//
//	cd go_backend && BITLY_STREAM_DIAG_FUENTES=1 go test ./internal/gobackend -run 'TestTapTodasLasFuentesE2E|TestFeedTapItemsE2E' -count=1 -v -timeout 900s
//
// Canción configurable: BITLY_TAP_CANCION / BITLY_TAP_ARTISTA.
// ─────────────────────────────────────────────────────────────

// tapDiag entorna el arnés: el registro real y la canción pedida.
func tapDiag(t *testing.T) (cancion, artista string) {
	t.Helper()
	if os.Getenv("BITLY_STREAM_DIAG_FUENTES") == "" {
		t.Skip("define BITLY_STREAM_DIAG_FUENTES=1 para medir contra las fuentes reales")
	}
	InitGlobalState()
	InitExtensionSystem(`{"extensions_dir":"","data_dir":""}`)
	LoadExtensionsFromDir(`{"dir_path":""}`)
	return envODefecto("BITLY_TAP_CANCION", "BbY WOW"), envODefecto("BITLY_TAP_ARTISTA", "KAROL G")
}

// TestTapTodasLasFuentesE2E toca la canción desde cada fuente con la metadata
// que ESA fuente devuelve.
func TestTapTodasLasFuentesE2E(t *testing.T) {
	cancion, artista := tapDiag(t)

	var resueltas, sinAudio, sinBuscador, sinSesion, sinResultados, sinEntorno []string
	for _, nombre := range reg.Names() {
		p := reg.Get(nombre)
		// Las fuentes de respaldo (musicbrainz, flac-rescue, internetarchive,
		// soulseek) no tienen catálogo propio: se prueban a través del rescate
		// de las otras.
		if p == nil || !esFuenteDeBusqueda(nombre) {
			continue
		}
		url, prov, nota := tapDeFuente(t, p, cancion, artista)
		switch {
		case url != "":
			resueltas = append(resueltas, nombre)
			t.Logf("[%s] OK  → %s (%s)", nombre, prov, nota)
		case nota == notaSinBuscador:
			sinBuscador = append(sinBuscador, nombre)
			t.Logf("[%s] sin buscador propio (no participa del matching por nombre)", nombre)
		case nota == notaSinSesion:
			sinSesion = append(sinSesion, nombre)
			t.Logf("[%s] sin sesión/credenciales en esta máquina", nombre)
		case nota == notaSinResultados:
			sinResultados = append(sinResultados, nombre)
			t.Logf("[%s] la búsqueda no devolvió nada (sin sesión o catálogo sin esa canción)", nombre)
		case nota == notaSinEntorno:
			sinEntorno = append(sinEntorno, nombre)
			t.Logf("[%s] falta una herramienta del entorno (no es un fallo de matching)", nombre)
		default:
			sinAudio = append(sinAudio, nombre)
			t.Logf("[%s] FALLA → %s", nombre, nota)
		}
	}
	t.Logf("resueltas=%v sinAudio=%v sinBuscador=%v sinSesion=%v sinResultados=%v sinEntorno=%v",
		resueltas, sinAudio, sinBuscador, sinSesion, sinResultados, sinEntorno)
	// Solo es fallo cuando la fuente PUDO devolver la canción y el audio no
	// llegó: las otras categorías son el estado de la máquina, no del matching.
	if len(sinAudio) > 0 {
		t.Errorf("fuentes que devolvieron %q y no consiguieron audio: %v", cancion, sinAudio)
	}
}

// TestFeedTapItemsE2E toca los items del HOME FEED que coinciden con la canción,
// con la metadata EXACTA del feed (la que la app manda en el tap), y comprueba
// que la URL entregada al reproductor sirve audio de verdad.
func TestFeedTapItemsE2E(t *testing.T) {
	cancion, _ := tapDiag(t)

	var secciones []FeedSectionGo
	if err := json.Unmarshal([]byte(GetHomeFeed("es")), &secciones); err != nil {
		t.Fatalf("feed inválido: %v", err)
	}
	probados := 0
	for _, seccion := range secciones {
		for _, item := range seccion.Items {
			if item.Type != "track" || !nombreParecidoAlPedido(item.Name, cancion) {
				continue
			}
			probados++
			payload, _ := json.Marshal(map[string]any{
				"preferredProvider": item.Source,
				"trackID":           item.ID,
				"quality":           "flac",
				"fetchLyrics":       "false",
				"trackName":         item.Name,
				"artistName":        item.Artists,
				"album":             item.AlbumName,
				"isrc":              item.ISRC,
				"durationMs":        item.DurationMs,
				"allowFallback":     true,
			})
			inicio := time.Now()
			respuesta := GetStreamPackage(string(payload))
			var pkg struct {
				AudioURL string `json:"audioUrl"`
				Provider string `json:"provider"`
				Quality  string `json:"quality"`
				Error    string `json:"error"`
			}
			if err := json.Unmarshal([]byte(respuesta), &pkg); err != nil {
				t.Errorf("[%s] respuesta ilegible: %.200s", item.Source, respuesta)
				continue
			}
			estado := comprobarReproducible(pkg.AudioURL)
			t.Logf("[%s] %q / %q (dur=%d isrc=%q) → %s prov=%q quality=%q repro=%s err=%q",
				item.Source, item.Name, item.Artists, item.DurationMs, item.ISRC,
				time.Since(inicio).Round(time.Millisecond), pkg.Provider, pkg.Quality, estado, pkg.Error)
			// Un item del feed que no termina en audio reproducible es el bug:
			// el usuario toca y no suena.
			if pkg.AudioURL == "" || !strings.HasPrefix(estado, "206") {
				t.Errorf("[%s] el tap del item del feed no entrega audio reproducible (url=%q repro=%s err=%q)",
					item.Source, pkg.AudioURL, estado, pkg.Error)
			}
		}
	}
	if probados == 0 {
		t.Skipf("el feed no trajo ningún track %q en esta máquina", cancion)
	}
	t.Logf("items del feed probados: %d", probados)
}

// ————— helpers —————

// Motivos clasificados: lo que NO es fallo de matching.
const (
	notaSinBuscador   = "sin buscador"
	notaSinSesion     = "sin sesión"
	notaSinResultados = "sin resultados"
	notaSinEntorno    = "sin entorno"
)

// tapDeFuente reproduce el toque de la canción desde [p]: primero su propia
// búsqueda (lo que la app recibiría), después el camino rápido si la fuente
// streamea y, si no entrega audio, el rescate con SU metadata.
func tapDeFuente(t *testing.T, p provider.Provider, cancion, artista string) (string, string, string) {
	t.Helper()
	consulta := strings.TrimSpace(cancion + " " + artista)

	inicio := time.Now()
	res, err := p.SearchTracks(consulta, 10)
	busqueda := time.Since(inicio).Round(time.Millisecond)
	if err != nil {
		motivo := err.Error()
		switch {
		case strings.Contains(motivo, "not found"):
			return "", "", notaSinBuscador
		case strings.Contains(motivo, "yt-dlp"), strings.Contains(motivo, "executable file not found"):
			// La fuente de youtube baja con un binario externo: sin yt-dlp en la
			// máquina su búsqueda no puede correr. Es el entorno, no el matching.
			return "", "", notaSinEntorno
		case pareceFaltaDeSesion(motivo):
			return "", "", notaSinSesion
		}
		return "", "", "la búsqueda falló: " + motivo
	}
	if len(res) == 0 {
		return "", "", notaSinResultados
	}
	// Mismo ranking que usa el rescate: el original por título/artista,
	// desempatado por duración (la fuente puede no exponer ISRC).
	mejor := provider.BestOriginalDuracion(cancion, artista, 0, res)
	if mejor == nil {
		mejor = &res[0]
	}
	t.Logf("[%s] búsqueda=%s → %q / %q / %dms isrc=%q",
		p.Name(), busqueda, mejor.Title, mejor.Artist, mejor.Duration, mejor.ISRC)

	if streaming.IsFullStreamProvider(p.Name()) {
		if url, prov, err := streaming.StreamQuick(reg, p.Name(), mejor.ID, "high", mejor.ISRC,
			mejor.SpotifyID, mejor.DeezerID, mejor.TidalID, mejor.QobuzID,
			mejor.Title, mejor.Artist, mejor.Duration); err == nil && url != "" {
			return url, prov, "camino rápido"
		}
	}

	inicio = time.Now()
	url, prov, err := streaming.RescueStreamURL(reg, "high", mejor.ISRC,
		mejor.SpotifyID, mejor.DeezerID, mejor.TidalID, mejor.QobuzID,
		mejor.Title, mejor.Artist, mejor.Album, mejor.Duration)
	transcurrido := time.Since(inicio).Round(time.Millisecond)
	if err != nil || url == "" {
		motivo := "el rescate no encontró audio"
		if err != nil {
			motivo += ": " + err.Error()
		}
		return "", "", motivo
	}
	return url, prov, "rescate en " + transcurrido.String()
}

// comprobarReproducible pide un byte de [u] como lo hace el reproductor al
// empezar y devuelve su estado ("206 Partial Content", "502 ...", "error ...").
func comprobarReproducible(u string) string {
	if u == "" {
		return "sin url"
	}
	if strings.HasPrefix(u, "file://") {
		return "206 archivo local"
	}
	req, err := http.NewRequest(http.MethodGet, u, nil)
	if err != nil {
		return "error " + err.Error()
	}
	req.Header.Set("Range", "bytes=0-0")
	req.Header.Set("User-Agent", "Mozilla/5.0")
	resp, err := (&http.Client{Timeout: 20 * time.Second}).Do(req)
	if err != nil {
		return "error " + err.Error()
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1))
	return fmt.Sprintf("%d %s", resp.StatusCode, http.StatusText(resp.StatusCode))
}

// nombreParecidoAlPedido compara plegado y sin ruido: "BbY WOW" tiene que
// encontrar el item del feed aunque el título venga con sufijos.
func nombreParecidoAlPedido(nombre, pedido string) bool {
	n := provider.FoldTrack(nombre)
	p := provider.FoldTrack(pedido)
	if n == "" || p == "" {
		return false
	}
	return strings.Contains(n, p) || strings.Contains(p, n)
}

// pareceFaltaDeSesion reconoce los errores de una fuente sin credenciales o sin
// sesión firmada: no son fallos del matching, son el estado de la máquina.
func pareceFaltaDeSesion(motivo string) bool {
	minuscula := strings.ToLower(motivo)
	for _, marca := range []string{
		"client_id", "client_secret", "developer token", "token set",
		"sin sesión", "no session", "unauthorized", "401", "forbidden", "403",
		"not authenticated", "login", "arl", "verification required",
	} {
		if strings.Contains(minuscula, marca) {
			return true
		}
	}
	return false
}

// envODefecto lee una variable de entorno o devuelve [defecto].
func envODefecto(clave, defecto string) string {
	if v := strings.TrimSpace(os.Getenv(clave)); v != "" {
		return v
	}
	return defecto
}
