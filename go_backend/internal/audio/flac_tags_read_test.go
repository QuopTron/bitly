package audio

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

// flac_tags_read_test.go — Fija la lectura de etiquetas de un FLAC con un
// archivo SINTÉTICO: un FLAC real de 20 MB no puede vivir en el repo, y lo que
// se prueba acá es el recorrido de bloques (STREAMINFO + comentarios Vorbis +
// portada), no el audio.
//
// El caso que motivó el lector: los FLAC que entregan los sitios raspables ya
// traen título, artista, álbum, ISRC y portada. Sin poder leerlos, cada
// descarga reescribía 20 MB sin ganancia.

func TestLeeComentariosVorbisYPortadaDeFLAC(t *testing.T) {
	dir := t.TempDir()
	ruta := filepath.Join(dir, "pista.flac")
	if err := os.WriteFile(ruta, flacSintetico(), 0o644); err != nil {
		t.Fatal(err)
	}
	meta, err := ReadFileMetadata(ruta)
	if err != nil {
		t.Fatalf("no se pudo leer el FLAC: %v", err)
	}
	if meta.Title != "NUEVAYoL" || meta.Artist != "Bad Bunny" {
		t.Fatalf("título/artista mal leídos: %q / %q", meta.Title, meta.Artist)
	}
	if meta.Album != "DeBÍ TiRAR MáS FOToS" {
		t.Fatalf("álbum mal leído: %q", meta.Album)
	}
	if meta.ISRC != "QMFMF2447055" {
		t.Fatalf("ISRC mal leído: %q", meta.ISRC)
	}
	if !meta.HasCover {
		t.Fatal("debería detectar la portada incrustada")
	}
	if !meta.DuracionExacta || meta.SampleRate != 44100 {
		t.Fatalf("STREAMINFO mal leído: %+v", meta)
	}
	// La duración sale de los 36 bits bajos del mismo campo empaquetado que el
	// sample rate: leerla con otro desplazamiento daba 49 minutos por 3. Se
	// compara por rango para no atarse al redondeo del fixture.
	if meta.DurationMs < 183000 || meta.DurationMs > 183300 {
		t.Fatalf("duración mal leída: %d ms (esperado ~183 s)", meta.DurationMs)
	}
}

func TestFLACSinEtiquetasNoInventaMetadata(t *testing.T) {
	dir := t.TempDir()
	ruta := filepath.Join(dir, "pelado.flac")
	if err := os.WriteFile(ruta, flacSintetico(), 0o644); err != nil {
		t.Fatal(err)
	}
	// Se borra el bloque de comentarios: solo queda STREAMINFO y el padding.
	if err := os.WriteFile(ruta, flacSoloStreaminfo(), 0o644); err != nil {
		t.Fatal(err)
	}
	meta, err := ReadFileMetadata(ruta)
	if err != nil {
		t.Fatalf("no se pudo leer: %v", err)
	}
	if meta.Title != "" || meta.Artist != "" || meta.ISRC != "" || meta.HasCover {
		t.Fatalf("no debería haber metadata: %+v", meta)
	}
}

// flacSintetico arma "fLaC" + STREAMINFO + comentarios Vorbis + portada, con la
// estructura (y el orden) que usa un FLAC real.
func flacSintetico() []byte {
	var out []byte
	out = append(out, []byte("fLaC")...)
	out = append(out, bloqueFLAC(0, false, streaminfo(44100, 8075682))...) // 183 s a 44,1 kHz
	out = append(out, bloqueFLAC(bloqueComentariosVorbis, false, comentariosVorbis(
		"TITLE=NUEVAYoL",
		"ARTIST=Bad Bunny",
		"ALBUM=DeBÍ TiRAR MáS FOToS",
		"ISRC=QMFMF2447055",
		"GENRE=Reggaetón",
	))...)
	out = append(out, bloqueFLAC(bloquePortada, true, []byte{0x00, 0x00, 0x00, 0x03, 'i', 'm', 'g'})...)
	return append(out, []byte("frames de audio (irrelevante)")...)
}

func flacSoloStreaminfo() []byte {
	var out []byte
	out = append(out, []byte("fLaC")...)
	out = append(out, bloqueFLAC(0, true, streaminfo(44100, 8075682))...)
	return append(out, []byte("frames de audio")...)
}

// bloqueFLAC arma la cabecera de un bloque de metadata (último + tipo + 24 bits)
// seguida de su contenido.
func bloqueFLAC(tipo byte, ultimo bool, cuerpo []byte) []byte {
	cab := []byte{tipo, byte(len(cuerpo) >> 16), byte(len(cuerpo) >> 8), byte(len(cuerpo))}
	if ultimo {
		cab[0] |= 0x80
	}
	return append(cab, cuerpo...)
}

// streaminfo arma los 34 bytes de STREAMINFO: min/max block size, min/max frame
// size, y los 64 bits finales con sample rate (20), canales (3), bit depth (5)
// y total de muestras (36).
func streaminfo(sampleRate, totalSamples int) []byte {
	bloque := make([]byte, 34)
	binary.BigEndian.PutUint16(bloque[0:2], 4096)
	binary.BigEndian.PutUint16(bloque[2:4], 4096)
	// sample rate + canales-1 + bit depth-1 + total de muestras en 8 bytes.
	empaquetado := uint64(sampleRate)<<44 | uint64(1)<<41 | uint64(15)<<36 | uint64(totalSamples)
	binary.BigEndian.PutUint64(bloque[10:18], empaquetado)
	return bloque
}

// comentariosVorbis arma el bloque de comentarios: proveedor + cantidad +
// entradas con su tamaño en little-endian.
func comentariosVorbis(entradas ...string) []byte {
	vendor := []byte("Bitly")
	var buf []byte
	largo := make([]byte, 4)
	binary.LittleEndian.PutUint32(largo, uint32(len(vendor)))
	buf = append(buf, largo...)
	buf = append(buf, vendor...)
	binary.LittleEndian.PutUint32(largo, uint32(len(entradas)))
	buf = append(buf, largo...)
	for _, e := range entradas {
		binary.LittleEndian.PutUint32(largo, uint32(len(e)))
		buf = append(buf, largo...)
		buf = append(buf, e...)
	}
	return buf
}
