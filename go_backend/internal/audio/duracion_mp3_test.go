// duracion_mp3_test.go — Fija la duración REAL de MP3.
//
// Por qué importa: con la estimación vieja (tamaño ÷ 192 kbps) una canción
// completa de 200s se reportaba como 87s y el guard anti-preview de las
// descargas la tiraba como si fuera un clip de 30s. Estas pruebas construyen
// archivos MP3 con frames sintéticos (cabeceras válidas, cero relleno) para
// comprobar que la duración sale del archivo y NO de una suposición.
//
// Se conecta con: duracion_mp3_cabecera.go + duracion_mp3_frames.go (readMP3).
// Parte del flujo: lectura de metadata de audio.
package audio

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

// frameMP3_128 arma un frame MPEG1 Layer III de 128 kbps a 44.1 kHz: cabecera
// válida de 4 bytes y relleno hasta el largo real (417 bytes con padding 0).
func frameMP3_128() []byte {
	largo := 144 * 128000 / 44100
	frame := make([]byte, largo)
	frame[0] = 0xFF
	frame[1] = 0xFB // MPEG1, Layer III, sin CRC
	frame[2] = 0x90 // bitrate 128 (índice 9), 44.1 kHz, sin padding
	frame[3] = 0x00
	return frame
}

// mp3Sintetico escribe [frames] frames consecutivos (sin Xing) y devuelve la ruta.
func mp3Sintetico(t *testing.T, frames int, conID3 bool) string {
	t.Helper()
	dir := t.TempDir()
	ruta := filepath.Join(dir, "prueba.mp3")
	datos := []byte{}
	if conID3 {
		// ID3v2.3 con 100 bytes de cuerpo (tamaño synchsafe en 4 bytes).
		cabecera := []byte{'I', 'D', '3', 3, 0, 0, 0, 0, 0, 100}
		datos = append(datos, cabecera...)
		datos = append(datos, make([]byte, 100)...)
	}
	for i := 0; i < frames; i++ {
		datos = append(datos, frameMP3_128()...)
	}
	if err := os.WriteFile(ruta, datos, 0o644); err != nil {
		t.Fatalf("no se pudo escribir el mp3: %v", err)
	}
	return ruta
}

func TestDuracionMP3PorConteoDeFrames(t *testing.T) {
	// 100 frames de 1152 muestras a 44.1 kHz = 2612 ms.
	ruta := mp3Sintetico(t, 100, false)
	meta, err := ReadFileMetadata(ruta)
	if err != nil {
		t.Fatalf("ReadFileMetadata: %v", err)
	}
	if !meta.DuracionExacta {
		t.Fatal("la duración debía quedar marcada como exacta")
	}
	if meta.DurationMs < 2600 || meta.DurationMs > 2625 {
		t.Fatalf("duración = %d ms, esperaba ~2612", meta.DurationMs)
	}
}

func TestDuracionMP3ConTagID3AlInicio(t *testing.T) {
	// El tag ID3v2 empuja el audio: si no se salta, el conteo empieza en basura
	// y no hay sincronía (antes ni se intentaba).
	ruta := mp3Sintetico(t, 50, true)
	meta, err := ReadFileMetadata(ruta)
	if err != nil {
		t.Fatalf("ReadFileMetadata: %v", err)
	}
	if !meta.DuracionExacta || meta.DurationMs == 0 {
		t.Fatalf("sin duración exacta tras el ID3: %+v", meta)
	}
}

func TestDuracionMP3ConCabeceraXing(t *testing.T) {
	// Un MP3 VBR declara la cantidad de frames en Xing: se usa esa cuenta
	// (exacta) en vez de recorrer el archivo.
	ruta := mp3Sintetico(t, 1, false)
	datos, err := os.ReadFile(ruta)
	if err != nil {
		t.Fatalf("lectura: %v", err)
	}
	xing := append([]byte("Xing"), 0, 0, 0, 1) // flags: frames presentes
	cuenta := make([]byte, 4)
	binary.BigEndian.PutUint32(cuenta, 400)
	datos = append(datos[:8], append(append(xing, cuenta...), datos[8:]...)...)
	if err := os.WriteFile(ruta, datos, 0o644); err != nil {
		t.Fatalf("escritura: %v", err)
	}
	meta, err := ReadFileMetadata(ruta)
	if err != nil {
		t.Fatalf("ReadFileMetadata: %v", err)
	}
	// 400 frames × 1152 / 44100 = 10448 ms.
	if !meta.DuracionExacta || meta.DurationMs < 10400 || meta.DurationMs > 10500 {
		t.Fatalf("duración Xing = %d ms (exacta=%v), esperaba ~10448",
			meta.DurationMs, meta.DuracionExacta)
	}
}
