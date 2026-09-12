// route_youtube_test.go — Guard de la SEPARACIÓN DE RUTAS de YouTube.
//
// Qué fija: en Go, el audio y el video de YouTube se piden por caminos
// distintos y con contratos distintos sobre el MISMO método de la extensión:
//
//   - audio  -> ExtensionProvider.GetStreamURL  -> getDownloadUrl(id, quality)
//     (formato solo-audio: es lo que suena)
//   - video  -> ExtensionProvider.GetVisualizerURL -> getDownloadUrl(id, quality, true)
//     (itag=18, el único formato con cuadros: visualizador y descarga de video)
//
// Por qué importa: si el audio pidiera el formato de video, YouTube sonaría a
// ~128 kbps multiplexado aunque hubiera PO token y formatos solo-audio
// disponibles — y desde afuera parece "YouTube suena mal" o "no hay FLAC", no
// un error de código. El tercer argumento (forceVideo) es toda la diferencia,
// así que acá se verifica que el audio NO lo mande y el video SÍ.
//
// Se conecta con: extension_provider_detail.go (GetStreamURL/GetVisualizerURL),
// download/orchestrator_video.go (la ruta de video) y streaming/play_package.go
// (la ruta de audio).
package provider

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// registra una extensión falsa que devuelve un marcador distinto según reciba
// o no forceVideo, y devuelve su proveedor listo para llamar.
func proveedorDeRutas(t *testing.T) *ExtensionProvider {
	t.Helper()
	rt := extensions.NewRuntime()
	cfg := extensions.DefaultConfig()
	cfg.TimeoutMs = 30000
	script := `
registerExtension({
  name: "rutas-falsas",
  // El marcador distingue el camino: audio (sin forceVideo) vs video (con él).
  getDownloadUrl: function (id, quality, forceVideo) {
    return forceVideo ? "https://video.example/itag-18" : "https://audio.example/itag-251";
  },
  searchTracks: function () { return []; },
  getTrack: function () { return null; },
});
`
	if _, err := rt.RunJS(script, "rutas-falsas", "rutas-falsas", cfg, t.TempDir()); err != nil {
		t.Fatalf("no pude cargar la extensión falsa: %v", err)
	}
	return NewExtensionProvider("rutas-falsas", "rutas-falsas", rt)
}

// La ruta de AUDIO no debe pedir el formato de video.
func TestRutaDeAudioNoPideFormatoDeVideo(t *testing.T) {
	p := proveedorDeRutas(t)
	url, err := p.GetStreamURL("dQw4w9WgXcQ", "FLAC")
	if err != nil {
		t.Fatalf("GetStreamURL falló: %v", err)
	}
	if url != "https://audio.example/itag-251" {
		t.Fatalf("la ruta de audio pidió el formato de VIDEO (url=%q): el audio de YouTube sonaría muxed a ~128k", url)
	}
}

// La ruta de VIDEO sí debe pedirlo (visualizador y descarga de video necesitan
// cuadros; un formato solo-audio no renderiza nada).
func TestRutaDeVideoPideFormatoDeVideo(t *testing.T) {
	p := proveedorDeRutas(t)
	url, err := p.GetVisualizerURL("dQw4w9WgXcQ", "FLAC")
	if err != nil {
		t.Fatalf("GetVisualizerURL falló: %v", err)
	}
	if url != "https://video.example/itag-18" {
		t.Fatalf("la ruta de video no pidió el formato de video (url=%q)", url)
	}
}
