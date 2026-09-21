// canales_red_test.go — Medición CONTRA LOS SERVICIOS REALES de los canales del
// rescate que todavía no tenían prueba de red: los ESPEJOS con contrato, el
// QOBUZ firmado, y el STREAM de arcod por el MISMO método que usa la carrera de
// reproducción (GetStreamURL), no por su función interna.
//
// Se activa a mano, porque depende de terceros:
//
//	BITLY_RESCATE_RED=1 go test ./internal/provider/flacrescue/ -run TestRed -v
//	BITLY_ARCORD_RED=1  go test ./internal/provider/flacrescue/ -run TestRedArcod -v
//
// Un canal CAÍDO se informa y no rompe nada (los espejos públicos llevan meses
// sin cuentas vivas: eso es un dato, no un bug de la app). Lo que SÍ falla es
// algo que se resolvió y no entrega lo prometido: un enlace que dice FLAC y
// manda MP3, o un stream sin soporte de Range (sin Range el reproductor tendría
// que bajar el archivo entero antes del primer segundo).

package flacrescue

import (
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

// isrcDePrueba es un tema real del catálogo (Bad Bunny - NUEVAYoL), el mismo
// que usan las otras pruebas de red del paquete.
const isrcDePrueba = "QMFMF2447055"

// pideTramo pide los primeros bytes de [enlace] con Range y devuelve el tipo de
// contenido y el tamaño TOTAL declarado (0 si el servidor no lo declara).
func pideTramo(t *testing.T, enlace string) (string, int64) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, enlace, nil)
	if err != nil {
		t.Fatalf("no se pudo armar la petición: %v", err)
	}
	req.Header.Set("Range", "bytes=0-3")
	resp, err := (&http.Client{Timeout: 40 * time.Second}).Do(req)
	if err != nil {
		t.Fatalf("no se pudo abrir el enlace: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusPartialContent {
		t.Fatalf("el enlace no soporta Range: status %d", resp.StatusCode)
	}
	cabecera := make([]byte, 4)
	if _, err := io.ReadFull(resp.Body, cabecera); err != nil {
		t.Fatalf("no se pudo leer la cabecera: %v", err)
	}
	if string(cabecera) != "fLaC" {
		t.Fatalf("el enlace no entrega FLAC (content-type %q, cabecera %q)",
			resp.Header.Get("Content-Type"), cabecera)
	}
	return resp.Header.Get("Content-Type"), totalDeRango(resp.Header.Get("Content-Range"))
}

// totalDeRango lee el total de un Content-Range "bytes 0-3/21345678".
func totalDeRango(cr string) int64 {
	i := strings.LastIndex(cr, "/")
	if i < 0 {
		return 0
	}
	n, err := strconv.ParseInt(strings.TrimSpace(cr[i+1:]), 10, 64)
	if err != nil {
		return 0
	}
	return n
}

// TestRedArcodStreamPorGetStreamURL comprueba el camino de STREAMING de arcod:
// el mismo método que llama la carrera de reproducción.
func TestRedArcodStreamPorGetStreamURL(t *testing.T) {
	if os.Getenv("BITLY_ARCORD_RED") == "" {
		t.Skip("define BITLY_ARCORD_RED=1 para medir el canal real")
	}
	cliente := NewClient()
	// TestMain apaga el canal (los tests del paquete son offline por contrato).
	cliente.arcodActivo = true

	inicio := time.Now()
	enlace, err := cliente.GetStreamURL(isrcDePrueba, "FLAC")
	if err != nil {
		t.Skipf("arcod no resolvió (%v)", err)
	}
	if !strings.HasPrefix(enlace, "https://") {
		t.Fatalf("el enlace no es reproducible: %q", enlace)
	}
	tipo, total := pideTramo(t, enlace)
	t.Logf("arcod stream en %dms: content-type=%q, %d bytes (%.1f MB) — Range ok",
		time.Since(inicio).Milliseconds(), tipo, total, float64(total)/1024/1024)
	// Una MUESTRA de 30 s en FLAC pesa ~5 MB; un tema completo, bastante más.
	// Sin esto, un preview con nombre de FLAC pasaría la prueba.
	if total > 0 && total < 8<<20 {
		t.Fatalf("el archivo es sospechosamente corto (%d bytes): ¿es una muestra?", total)
	}
}

// TestRedEspejosConContrato mide cada espejo de fábrica, uno por uno.
func TestRedEspejosConContrato(t *testing.T) {
	if os.Getenv("BITLY_RESCATE_RED") == "" {
		t.Skip("define BITLY_RESCATE_RED=1 para medir los canales reales")
	}
	if len(defaultMirrors) == 0 {
		t.Skip("no hay espejos de fábrica configurados")
	}
	// Se pregunta por cada espejo DIRECTAMENTE: la cascada normal probaría antes
	// el canal Qobuz firmado y arcod, y acá se quiere el dato de cada espejo.
	for _, espejo := range defaultMirrors {
		espejo := espejo
		t.Run(espejo, func(t *testing.T) {
			cliente := NewClient()
			inicio := time.Now()
			enlace, err := cliente.resolverEnEspejo(espejo, isrcDePrueba, "FLAC")
			if err != nil {
				// Un espejo sin cuentas vivas no rompe la medición: se informa.
				t.Skipf("no respondió (%v)", err)
			}
			tipo, total := pideTramo(t, enlace)
			t.Logf("%s en %dms: content-type=%q, %d bytes (%.1f MB)",
				espejo, time.Since(inicio).Milliseconds(), tipo, total,
				float64(total)/1024/1024)
		})
	}
}

// TestRedQobuzFirmado mide el canal "Qobuz firmado": si consigue firma, si
// Qobuz le entrega FLAC o lo degrada a MP3, y cuánto tarda.
func TestRedQobuzFirmado(t *testing.T) {
	if os.Getenv("BITLY_RESCATE_RED") == "" {
		t.Skip("define BITLY_RESCATE_RED=1 para medir los canales reales")
	}
	// El origen de claves de fábrica quedó guardado antes de que TestMain lo
	// apagara para los tests offline.
	clavesDeFabrica := origenDeClavesDeFabrica()
	if len(clavesDeFabrica) == 0 {
		t.Skip("no hay orígenes de claves de fábrica")
	}
	defaultKeysURLs = clavesDeFabrica

	cliente := NewClient()
	informe := cliente.DiagnosticoQobuz()
	t.Logf("Qobuz firmado: estado=%s fuente=%s formato=%q en %dms — %s",
		informe.Estado, informe.Fuente, informe.Formato, informe.Ms, informe.Detalle)

	switch informe.Estado {
	case EstadoSinClaves:
		// El origen de claves está caído o publica claves que Qobuz ya no
		// acepta: es el estado que hay que ver para saber si hace falta otro
		// origen. No se falla: el rescate por sitios/arcod sigue igual.
		t.Logf("⚠ sin claves usables: el canal queda apagado (los otros canales siguen)")
	case EstadoFlac:
		// Se confirma con el audio: el diagnóstico ya pidió FLAC, y acá se
		// verifica que el enlace entregue FLAC de verdad y no una muestra.
		enlace, err := cliente.resolverQobuzFirmado(isrcDePrueba, "FLAC")
		if err != nil {
			t.Logf("⚠ el informe dice FLAC pero la resolución falló: %v", err)
			return
		}
		_, total := pideTramo(t, enlace)
		t.Logf("✓ FLAC real con Range: %d bytes (%.1f MB)", total, float64(total)/1024/1024)
		if total > 0 && total < 8<<20 {
			t.Fatalf("el archivo es sospechosamente corto (%d bytes): ¿es una muestra?", total)
		}
	case EstadoMp3:
		t.Logf("⚠ las claves sirven pero Qobuz degrada a MP3 320 (sin token de suscriptor)")
	}
}
