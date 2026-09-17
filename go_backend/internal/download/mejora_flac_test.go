package download

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// flacFalso arma un archivo con la firma y el STREAMINFO de un FLAC: alcanza
// para lo que se verifica acá (firma + duración) sin depender de ffmpeg.
func flacFalso(t *testing.T, ruta string, sampleRate, totalSamples int) {
	t.Helper()
	datos := make([]byte, 0, 128)
	datos = append(datos, []byte("fLaC")...)
	// Bloque STREAMINFO: último bloque (0x80), tipo 0, largo 34.
	datos = append(datos, 0x80, 0x00, 0x00, 0x22)
	info := make([]byte, 34)
	binary.BigEndian.PutUint64(info[10:18], uint64(sampleRate)<<44|uint64(totalSamples))
	datos = append(datos, info...)
	for len(datos) < 128 {
		datos = append(datos, 0x00)
	}
	if err := os.WriteFile(ruta, datos, 0o644); err != nil {
		t.Fatalf("no se pudo escribir el FLAC de prueba: %v", err)
	}
}

func TestDebeMejorarSinPerdida(t *testing.T) {
	dir := t.TempDir()
	archivo := filepath.Join(dir, "cancion.m4a")
	if err := os.WriteFile(archivo, make([]byte, 256), 0o644); err != nil {
		t.Fatalf("no se pudo preparar el archivo: %v", err)
	}
	base := Request{
		ItemID:    "track_1_audio",
		Title:     "NUEVAYoL",
		ISRC:      "QMFMF2447055",
		Quality:   "FLAC",
		OutputDir: dir,
	}
	ok := func(res *Result) *Result { return res }

	casos := []struct {
		nombre string
		req    Request
		res    *Result
		quiero bool
	}{
		{
			nombre: "sin pérdida pedido y ganador con pérdida",
			req:    base,
			res:    ok(&Result{Success: true, Provider: "ytmusic-spotiflac", FilePath: archivo}),
			quiero: true,
		},
		{
			nombre: "el usuario no pidió sin pérdida",
			req:    func() Request { r := base; r.Quality = "HIGH"; return r }(),
			res:    ok(&Result{Success: true, Provider: "ytmusic-spotiflac", FilePath: archivo}),
			quiero: false,
		},
		{
			nombre: "el ganador ya entrega sin pérdida",
			req:    base,
			res:    ok(&Result{Success: true, Provider: "internetarchive", FilePath: archivo}),
			quiero: false,
		},
		{
			nombre: "soulseek también cuenta como sin pérdida",
			req:    base,
			res:    ok(&Result{Success: true, Provider: "soulseek", FilePath: archivo}),
			quiero: false,
		},
		{
			nombre: "el archivo quedó encriptado para el cliente",
			req:    base,
			res:    ok(&Result{Success: true, Provider: "amazon", FilePath: archivo, Encrypted: true}),
			quiero: false,
		},
		{
			nombre: "sin ISRC ni título no hay con qué buscar",
			req:    func() Request { r := base; r.ISRC = ""; r.Title = ""; return r }(),
			res:    ok(&Result{Success: true, Provider: "ytmusic-spotiflac", FilePath: archivo}),
			quiero: false,
		},
		{
			nombre: "la descarga no terminó bien",
			req:    base,
			res:    ok(&Result{Success: false, Provider: "ytmusic-spotiflac"}),
			quiero: false,
		},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			got, razon := debeMejorarSinPerdida(c.req, c.res)
			if got != c.quiero {
				t.Fatalf("debeMejorarSinPerdida = %v (motivo: %s), quería %v", got, razon, c.quiero)
			}
			if strings.TrimSpace(razon) == "" {
				t.Fatal("toda decisión debe traer su motivo")
			}
		})
	}
}
