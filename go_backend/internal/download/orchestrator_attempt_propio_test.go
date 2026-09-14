package download

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
)

// El contrato se verifica en tiempo de compilación: si la firma de Soulseek
// dejara de coincidir con la interfaz, el proveedor NO sería despachado y la
// descarga P2P quedaría deshabilitada en silencio. Es el tipo de fallo que no
// se nota hasta que alguien pide un FLAC que existe y no llega.
var _ descargadorPropio = (*soulseek.Client)(nil)

// proveedorPropioFalso imita a Soulseek: NO puede dar una URL (el audio lo trae
// él mismo) y escribe el archivo directo en disco.
type proveedorPropioFalso struct {
	nombre       string
	contenido    []byte
	extension    string
	vecesStream  int
	duracionDada int
}

func (p *proveedorPropioFalso) Name() string { return p.nombre }

func (p *proveedorPropioFalso) SearchTracks(string, int) ([]provider.TrackResult, error) {
	return nil, nil
}
func (p *proveedorPropioFalso) SearchAlbums(string, int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (p *proveedorPropioFalso) SearchArtists(string, int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (p *proveedorPropioFalso) SearchPlaylists(string, int) ([]provider.PlaylistResult, error) {
	return nil, nil
}
func (p *proveedorPropioFalso) GetTrack(string) (*provider.TrackResult, error) { return nil, nil }
func (p *proveedorPropioFalso) GetTrackByISRC(string) (*provider.TrackResult, error) {
	return nil, nil
}
func (p *proveedorPropioFalso) GetAlbum(string) (*provider.AlbumResult, error) { return nil, nil }
func (p *proveedorPropioFalso) GetArtist(string) (*provider.ArtistResult, error) {
	return nil, nil
}

// GetStreamURL falla siempre: si el orquestador cae acá en vez de usar
// DescargarAArchivo, la descarga falla y el test lo detecta.
func (p *proveedorPropioFalso) GetStreamURL(string, string) (string, error) {
	p.vecesStream++
	return "", fmt.Errorf("este proveedor no expone URL")
}

func (p *proveedorPropioFalso) DescargarAArchivo(trackID, quality, destinoDir string, duracionEsperadaS int) (string, error) {
	p.duracionDada = duracionEsperadaS
	destino := filepath.Join(destinoDir, "pista."+p.extension)
	if err := os.WriteFile(destino, p.contenido, 0o600); err != nil {
		return "", err
	}
	return destino, nil
}

func nuevoOrquestadorCon(p provider.Provider) *Orchestrator {
	reg := provider.NewRegistry()
	reg.Register(p)
	return NewOrchestrator(reg)
}

// Un proveedor que trae el archivo por su cuenta tiene que ser despachado por
// DescargarAArchivo, NO por GetStreamURL. Si esta precedencia se rompe, el
// audio P2P de Soulseek deja de llegar aunque la búsqueda siga funcionando —
// un fallo silencioso que desde afuera se ve como "esa canción no está".
func TestProveedorPropioUsaSuDescargaYNoLaURL(t *testing.T) {
	outDir := t.TempDir()
	falso := &proveedorPropioFalso{
		nombre:    "falso-propio",
		extension: "flac",
		contenido: append([]byte("fLaC"), make([]byte, 8192)...),
	}
	o := nuevoOrquestadorCon(falso)

	res := o.attemptDownload(
		Request{ItemID: "track_1", Title: "Tema", Artist: "Artista", DurationMS: 210_000},
		falso.nombre, falso, "id-1", "Tema", "Artista", outDir,
	)

	if !res.Success {
		t.Fatalf("la descarga propia falló: %s", res.Error)
	}
	if falso.vecesStream != 0 {
		t.Fatalf("se llamó a GetStreamURL %d veces: el camino propio no tomó precedencia", falso.vecesStream)
	}
	if res.FilePath == "" {
		t.Fatal("no se devolvió la ruta del archivo descargado")
	}
	if _, err := os.Stat(res.FilePath); err != nil {
		t.Fatalf("el archivo finalizado no existe: %v", err)
	}
	// La duración del catálogo viaja al proveedor: es lo que le permite
	// verificar que la grabación sea la pedida y no un remix.
	if falso.duracionDada != 210 {
		t.Fatalf("la duración esperada llegó en %d s, se esperaban 210", falso.duracionDada)
	}
}

// Y si lo que quedó en disco es un binario, no se sirve: se descarta. Que la
// descarga la haya hecho "nuestro" proveedor no cambia nada — el archivo lo
// escribió un proceso que no controlamos.
func TestProveedorPropioDescartaBinario(t *testing.T) {
	outDir := t.TempDir()
	falso := &proveedorPropioFalso{
		nombre:    "falso-propio",
		extension: "flac",
		// Firma MZ con nombre .flac: el disfraz clásico.
		contenido: append([]byte{'M', 'Z', 0x90, 0x00}, make([]byte, 8192)...),
	}
	o := nuevoOrquestadorCon(falso)

	res := o.attemptDownload(
		Request{ItemID: "track_2", Title: "Tema", Artist: "Artista"},
		falso.nombre, falso, "id-2", "Tema", "Artista", outDir,
	)

	if res.Success {
		t.Fatalf("un ejecutable renombrado a .flac se sirvió como canción (%s)", res.FilePath)
	}
	restos, err := os.ReadDir(outDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(restos) != 0 {
		t.Fatalf("el binario rechazado quedó en disco: %v", restos)
	}
}
