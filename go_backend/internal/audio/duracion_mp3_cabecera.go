// ─────────────────────────────────────────────────────────────
// duracion_mp3_cabecera.go — Cabecera de frame MPEG (MP3) y tablas.
//
// Por qué existe: para saber la duración real de un MP3 hay que leer sus
// frames (Xing/Info o conteo), y eso empieza por interpretar la cabecera de 4
// bytes: versión, layer, bitrate, velocidad de muestreo, padding y tamaño del
// frame. Antes la duración se estimaba con "tamaño ÷ 192 kbps", un número
// inventado que hacía rechazar descargas completas como si fueran previews.
//
// Se conecta con: duracion_mp3.go (recorrido de frames).
// Parte del flujo: lectura de metadata de audio.
// ─────────────────────────────────────────────────────────────

package audio

// Tablas de bitrate y velocidades de muestreo. OJO con la clave: los bits de
// layer de la cabecera valen 01=Layer III, 10=Layer II, 11=Layer I, así que
// cada tabla está indexada por ESE valor (no por el número de layer).
var (
	bitratesMPEG1 = map[int][]int{
		1: {0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320},  // Layer III
		2: {0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384}, // Layer II
		3: {0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448},
	}
	bitratesMPEG2 = map[int][]int{
		1: {0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160}, // Layer III
		2: {0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160}, // Layer II
		3: {0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256},
	}
	sampleRatesMPEG = map[int][]int{
		3: {44100, 48000, 32000}, // MPEG 1
		2: {22050, 24000, 16000}, // MPEG 2
		0: {11025, 12000, 8000},  // MPEG 2.5
	}
)

// cabeceraMP3 describe un frame MPEG válido.
type cabeceraMP3 struct {
	version          int // 3=MPEG1, 2=MPEG2, 0=MPEG2.5
	layer            int // 1=Layer III, 2=Layer II, 3=Layer I
	bitrateKbps      int
	sampleRate       int
	padding          int
	largoFrame       int
	muestrasPorFrame int
}

// parsearCabeceraMP3 interpreta 4 bytes de cabecera de frame. ok=false si no
// hay sincronía válida: los MP3 pueden traer basura antes del primer frame.
func parsearCabeceraMP3(b []byte) (cabeceraMP3, bool) {
	var c cabeceraMP3
	if len(b) < 4 || b[0] != 0xFF || b[1]&0xE0 != 0xE0 {
		return c, false
	}
	c.version = int(b[1]>>3) & 0x3
	c.layer = int(b[1]>>1) & 0x3
	bitrateIdx := int(b[2]>>4) & 0xF
	sampleIdx := int(b[2]>>2) & 0x3
	c.padding = int(b[2]>>1) & 0x1
	if c.version == 1 || c.layer == 0 || bitrateIdx == 0 ||
		bitrateIdx == 15 || sampleIdx == 3 {
		return c, false
	}
	velocidades, ok := sampleRatesMPEG[c.version]
	if !ok {
		return c, false
	}
	c.sampleRate = velocidades[sampleIdx]
	tabla := bitratesMPEG1
	if c.version != 3 {
		tabla = bitratesMPEG2
	}
	bitrates, ok := tabla[c.layer]
	if !ok {
		return c, false
	}
	c.bitrateKbps = bitrates[bitrateIdx]
	switch c.layer {
	case 3: // Layer I
		c.muestrasPorFrame = 384
		c.largoFrame = (12*c.bitrateKbps*1000/c.sampleRate + c.padding) * 4
	case 2: // Layer II
		c.muestrasPorFrame = 1152
		c.largoFrame = 144*c.bitrateKbps*1000/c.sampleRate + c.padding
	default: // Layer III
		if c.version == 3 {
			c.muestrasPorFrame = 1152
			c.largoFrame = 144*c.bitrateKbps*1000/c.sampleRate + c.padding
		} else {
			c.muestrasPorFrame = 576
			c.largoFrame = 72*c.bitrateKbps*1000/c.sampleRate + c.padding
		}
	}
	if c.largoFrame <= 0 || c.sampleRate <= 0 {
		return c, false
	}
	return c, true
}
