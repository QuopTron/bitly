// flac_duracion_test.go — la duración del FLAC se verifica contra un STREAMINFO
// construido a mano (bit a bit), no contra un archivo de ejemplo: así el test
// comprueba el LAYOUT de los campos, que es donde está todo el riesgo.
package audioguard

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

// flacConStreaminfo arma "fLaC" + bloque STREAMINFO + basura, con los valores
// pedidos. El orden de los campos sigue el spec de FLAC.
func flacConStreaminfo(t *testing.T, frecuencia uint32, profundidad int, canales int, muestras uint64, tam int) string {
	t.Helper()
	cabecera := make([]byte, 26)
	copy(cabecera[0:4], "fLaC")
	// Cabecera del bloque: tipo 0 (STREAMINFO) y último bloque (bit alto).
	cabecera[4] = 0x80
	// 34 bytes de STREAMINFO.
	binary.BigEndian.PutUint32(cabecera[5:9], 0x00000022)
	// min/max block size y min/max frame: 10 bytes de campos que no usamos.
	// Bloque combinado en el offset 18.
	combinado := uint64(frecuencia)<<44 |
		uint64(canales-1)<<41 |
		uint64(profundidad-1)<<36 |
		(muestras & 0xFFFFFFFFF)
	binary.BigEndian.PutUint64(cabecera[18:26], combinado)

	contenido := make([]byte, tam)
	copy(contenido, cabecera)
	ruta := filepath.Join(t.TempDir(), "pista.flac")
	if err := os.WriteFile(ruta, contenido, 0o600); err != nil {
		t.Fatalf("no se pudo escribir: %v", err)
	}
	return ruta
}

func TestDuracionFLAC(t *testing.T) {
	// 44100 Hz x 320 s = 14.112.000 muestras, 16 bits, estéreo.
	ruta := flacConStreaminfo(t, 44100, 16, 2, 44100*320, 4096)
	dur, ok := DuracionFLAC(ruta)
	if !ok {
		t.Fatal("debería poder leer la duración")
	}
	if dur < 319.9 || dur > 320.1 {
		t.Fatalf("duración %.3f, se esperaba 320", dur)
	}

	// Hi-res: 96 kHz / 24 bits a 245.5 s.
	hi := flacConStreaminfo(t, 96000, 24, 2, 96000*245+48000, 4096)
	if d, ok := DuracionFLAC(hi); !ok || d < 245.4 || d > 245.6 {
		t.Fatalf("duración hi-res %.3f (ok=%v), se esperaba 245.5", d, ok)
	}
	hz, bits, ok := FrecuenciaYProfundidadFLAC(hi)
	if !ok || hz != 96000 || bits != 24 {
		t.Fatalf("cabecera hi-res mal leída: %d Hz %d bits (ok=%v)", hz, bits, ok)
	}

	// Un FLAC que dice 16 bits/44.1k (el caso del MP3 re-codificado a FLAC):
	// frecuencia y profundidad bajas, que es lo que delata el transcode.
	hz2, bits2, _ := FrecuenciaYProfundidadFLAC(ruta)
	if hz2 != 44100 || bits2 != 16 {
		t.Fatalf("cabecera estándar mal leída: %d Hz %d bits", hz2, bits2)
	}
}

func TestDuracionFLACNoSeInventa(t *testing.T) {
	dir := t.TempDir()

	// Un MP3 no es un FLAC: no debe reportar duración.
	mp3 := filepath.Join(dir, "pista.mp3")
	if err := os.WriteFile(mp3, append([]byte("ID3\x03\x00\x00\x00"), make([]byte, 64)...), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, ok := DuracionFLAC(mp3); ok {
		t.Fatal("un MP3 no puede reportar duración de FLAC")
	}

	// FLAC truncado (no llegan los 26 bytes de cabecera): sin duración.
	corto := filepath.Join(dir, "corto.flac")
	if err := os.WriteFile(corto, []byte("fLaC\x80\x00\x00"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, ok := DuracionFLAC(corto); ok {
		t.Fatal("un FLAC truncado no puede reportar duración")
	}

	// FLAC que declara 0 muestras totales (codificado en streaming): se admite
	// que NO se puede verificar, en vez de devolver una duración falsa de 0.
	cero := flacConStreaminfo(t, 44100, 16, 2, 0, 4096)
	if _, ok := DuracionFLAC(cero); ok {
		t.Fatal("sin muestras totales no hay duración verificable")
	}

	// Ruta inexistente.
	if _, ok := DuracionFLAC(filepath.Join(dir, "nada.flac")); ok {
		t.Fatal("una ruta inexistente no puede dar duración")
	}
}
