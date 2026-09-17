// ─────────────────────────────────────────────────────────────
// duracion_mp3_frames.go — Duración REAL de un MP3 recorriendo sus frames.
//
// Por qué existe: la duración estimada con "tamaño ÷ bitrate supuesto" hacía
// que una canción de 200s se midiera como 87s, y el guard anti-preview de las
// descargas rechazaba archivos completos como si fueran clips de 30s. Acá la
// duración sale del archivo: la cuenta de frames del Xing/Info cuando está, y
// si no, el conteo de frames (exacto también con bitrate variable).
//
// Se conecta con: formats.go (readMP3) y duracion_mp3_cabecera.go (tablas).
// Parte del flujo: lectura de metadata de audio.
// ─────────────────────────────────────────────────────────────

package audio

import (
	"bufio"
	"encoding/binary"
	"io"
	"os"
)

// maxFramesContados acota el recorrido: un MP3 de una hora son ~150k frames;
// más que eso no compensa el costo y la duración se declara no afirmable.
const maxFramesContados = 300000

// duracionMP3 lee la duración real desde [inicio] (primer byte de audio, ya
// salteado el tag ID3v2). Devuelve ok=false cuando el archivo no permite
// afirmar la duración: sin dato fiable, ninguna verificación debe juzgarla.
func duracionMP3(f *os.File, inicio int64) (int64, bool) {
	if inicio < 0 {
		inicio = 0
	}
	if _, err := f.Seek(inicio, io.SeekStart); err != nil {
		return 0, false
	}
	br := bufio.NewReaderSize(f, 64<<10)

	// Buscar el primer frame: hasta 8 KiB de etiquetas o basura antes.
	var primera cabeceraMP3
	encontrada := false
	ventana := make([]byte, 4)
	for i := 0; i < 2048; i++ {
		if _, err := io.ReadFull(br, ventana); err != nil {
			return 0, false
		}
		if c, ok := parsearCabeceraMP3(ventana); ok && c.largoFrame >= 24 {
			primera = c
			encontrada = true
			break
		}
	}
	if !encontrada {
		return 0, false
	}

	// Resto del primer frame (la cabecera de 4 bytes ya se leyó): sirve para
	// buscar el Xing/Info y deja el cursor alineado en el segundo frame. Leer
	// los `largoFrame` bytes completos se comería la cabecera del segundo
	// frame y el recorrido se desalinearía (leería ceros).
	cuerpo := make([]byte, primera.largoFrame-4)
	if _, err := io.ReadFull(br, cuerpo); err != nil {
		return 0, false
	}
	if frames, ok := framesXing(cuerpo); ok && frames > 0 {
		return int64(frames) * int64(primera.muestrasPorFrame) * 1000 /
			int64(primera.sampleRate), true
	}

	// Sin Xing: recorrer frames. Si el recorrido no termina, la suma queda
	// corta y NO se puede usar como duración.
	total := int64(primera.muestrasPorFrame) * 1000 / int64(primera.sampleRate)
	for i := 1; i < maxFramesContados; i++ {
		if _, err := io.ReadFull(br, ventana); err != nil {
			if err == io.EOF || err == io.ErrUnexpectedEOF {
				return total, true
			}
			return 0, false
		}
		c, ok := parsearCabeceraMP3(ventana)
		if !ok {
			return 0, false
		}
		total += int64(c.muestrasPorFrame) * 1000 / int64(c.sampleRate)
		if err := saltarFrames(br, c); err != nil {
			return 0, false
		}
	}
	return 0, false // demasiado largo para recorrerlo: no se afirma la duración
}

// framesXing lee la cuenta de frames del Xing/Info dentro del PRIMER frame
// completo, si está presente (es la vía instantánea y exacta en VBR).
func framesXing(cuerpo []byte) (int, bool) {
	for i := 4; i+12 <= len(cuerpo); i++ {
		marca := string(cuerpo[i : i+4])
		if marca != "Xing" && marca != "Info" {
			continue
		}
		flags := binary.BigEndian.Uint32(cuerpo[i+4 : i+8])
		if flags&0x1 == 0 {
			return 0, false
		}
		return int(binary.BigEndian.Uint32(cuerpo[i+8 : i+12])), true
	}
	return 0, false
}

// saltarFrames descarta el resto del frame actual (ya se leyó su cabecera).
func saltarFrames(br *bufio.Reader, c cabeceraMP3) error {
	resto := int64(c.largoFrame) - 4
	if resto <= 0 {
		return nil
	}
	_, err := br.Discard(int(resto))
	return err
}
