package download

import (
	"log"
	"os"
	"path/filepath"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/flacrescue"
	"github.com/zarz/bitly/go_backend/internal/provider/internetarchive"
)

// TestE2EMejoraFLACConInternetArchive es un arnés para probar el camino real:
// archivo con pérdida en disco -> mejora silenciosa -> FLAC validado en su
// lugar. Sin ISRC usa Internet Archive (que solo tiene MP3 para este tema, así
// que sirve como caso negativo: NO debe reemplazar nada).
func TestE2EMejoraFLACConInternetArchive(t *testing.T) {
	arnesMejoraFLAC(t, Request{
		ItemID:  "track_e2e_audio",
		Title:   "Clair de Lune",
		Artist:  "Claude Debussy",
		Quality: "FLAC",
	})
}

// TestE2EMejoraFLACConSitioReal usa un ISRC real y comprueba la cadena
// completa de punta a punta: el worker consulta los SITIOS raspables, baja el
// FLAC de verdad y lo deja en el lugar del archivo con pérdida.
//
// Se activa a mano (depende de un sitio de terceros):
//
//	BITLY_SITIO_FLAC=1 go test ./internal/download/ -run TestE2EMejoraFLACConSitioReal -v
func TestE2EMejoraFLACConSitioReal(t *testing.T) {
	if os.Getenv("BITLY_SITIO_FLAC") == "" {
		t.Skip("define BITLY_SITIO_FLAC=1 para probar el sitio real")
	}
	// "NUEVAYoL" de Bad Bunny: ISRC y duración del catálogo.
	arnesMejoraFLAC(t, Request{
		ItemID:     "track_e2e_sitio",
		Title:      "NUEVAYoL",
		Artist:     "Bad Bunny",
		ISRC:       "QMFMF2447055",
		DurationMS: 183000,
		Quality:    "FLAC",
	})
}

// arnesMejoraFLAC arma un archivo con pérdida y corre la mejora sobre él,
// dejando en el log qué quedó en la carpeta al terminar.
func arnesMejoraFLAC(t *testing.T, req Request) {
	t.Helper()
	dir := t.TempDir()
	viejo := filepath.Join(dir, "track_e2e_audio.m4a")
	if err := os.WriteFile(viejo, make([]byte, 4096), 0o644); err != nil {
		t.Fatal(err)
	}
	req.OutputDir = dir

	reg := provider.NewRegistry()
	reg.Register(internetarchive.NewClient(nil))
	reg.Register(flacrescue.NewClient())
	o := NewOrchestrator(reg)
	o.tracker.Add(req.ItemID, req.Title, "ytmusic-spotiflac")

	log.Printf("=== ARNÉS: mejora de %q (%s)", req.Title, filepath.Base(viejo))
	o.intentarMejoraFLAC(trabajoMejoraFLAC{
		req:        req,
		outDir:     dir,
		rutaActual: viejo,
		ganador:    "ytmusic-spotiflac",
	})

	entradas, _ := os.ReadDir(dir)
	for _, e := range entradas {
		info, _ := e.Info()
		log.Printf("=== ARNÉS: quedó %s (%d bytes)", e.Name(), info.Size())
	}
	destino := rutaFLACPara(viejo)
	if ok, motivo := esFLACSinPerdida(destino); ok {
		log.Printf("=== ARNÉS: ✔ FLAC en su lugar (%s), viejo borrado: %v",
			destino, !existe(viejo))
	} else {
		log.Printf("=== ARNÉS: sin FLAC todavía (%s)", motivo)
	}
}

func existe(ruta string) bool {
	_, err := os.Stat(ruta)
	return err == nil
}
