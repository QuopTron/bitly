package audio

import (
	"encoding/binary"
	"fmt"
	"os"
)

func readFLAC(path string, meta *Metadata) (*Metadata, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Read FLAC metadata markers
	header := make([]byte, 42)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	// FLAC starts with "fLaC"
	if string(header[:4]) != "fLaC" {
		return nil, fmt.Errorf("audio: not a FLAC file")
	}

	// Los últimos 8 bytes del STREAMINFO empaquetan, en un solo campo: sample
	// rate (20 bits), canales-1 (3), bits por muestra-1 (5) y TOTAL DE MUESTRAS
	// (36). Se leen del MISMO entero: la duración son los 36 bits bajos, no un
	// campo aparte. Leerlos con un desplazamiento propio daba duraciones
	// absurdas (una canción de 3 minutos figuraba como 49) y rompía cualquier
	// decisión que dependa del dato.
	empaquetado := binary.BigEndian.Uint64(header[18:26])
	meta.SampleRate = int(empaquetado >> 44 & 0xFFFFF)
	meta.BitDepth = int(empaquetado>>36&0x1F) + 1
	totalSamples := int64(empaquetado & 0xFFFFFFFFF)
	if totalSamples > 0 && meta.SampleRate > 0 {
		meta.DurationMs = int(totalSamples * 1000 / int64(meta.SampleRate))
		// STREAMINFO declara la cantidad total de muestras: la duración es real.
		meta.DuracionExacta = true
	}

	// El bitrate solo se puede calcular con una duración de al menos un segundo:
	// dividir por DurationMs/1000 daba división por cero (panic del backend)
	// con cualquier FLAC de menos de 1s (candidatas truncadas, previews).
	if meta.DurationMs >= 1000 {
		meta.Bitrate = int(int64(meta.FileSize) * 8 / (int64(meta.DurationMs) / 1000) / 1000)
	}
	// Las etiquetas del FLAC viven en los comentarios Vorbis, no en STREAMINFO:
	// sin esto la metadata salía vacía para cualquier FLAC.
	leerEtiquetasFLAC(f, meta)
	return meta, nil
}

func readMP3(path string, meta *Metadata) (*Metadata, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	header := make([]byte, 10)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	// Salto del tag ID3v2 (cabecera de 10 bytes + tamaño synchsafe). Sin ID3 el
	// audio arranca en 0.
	inicioAudio := int64(0)
	if string(header[:3]) == "ID3" {
		tagSize := int64(header[6])<<21 | int64(header[7])<<14 |
			int64(header[8])<<7 | int64(header[9])
		inicioAudio = 10 + tagSize
	}

	// Duración REAL (Xing/Info o conteo de frames). Si no se puede afirmar,
	// queda sin marca y ninguna verificación debe apoyarse en ella: la
	// estimación por tamaño y bitrate supuesto reportaba 87s para una canción
	// de 200s y el guard anti-preview tiraba descargas completas.
	if ms, ok := duracionMP3(f, inicioAudio); ok && ms > 0 {
		meta.DurationMs = int(ms)
		meta.DuracionExacta = true
		if ms >= 1000 {
			meta.Bitrate = int(meta.FileSize * 8 / (ms / 1000) / 1000)
		}
	}

	meta.SampleRate = 44100
	meta.BitDepth = 16
	return meta, nil
}

func readMP4(path string, meta *Metadata) (*Metadata, error) {
	// MP4/M4A: duración REAL desde moov→mvhd (timescale + duration). Antes se
	// estimaba con "tamaño ÷ 256 kbps", que inventaba la duración.
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	if ms, ok := duracionMP4(f); ok && ms > 0 {
		meta.DurationMs = int(ms)
		meta.DuracionExacta = true
		if ms >= 1000 {
			meta.Bitrate = int(meta.FileSize * 8 / (ms / 1000) / 1000)
		}
	}
	meta.SampleRate = 44100
	meta.BitDepth = 16
	return meta, nil
}

func readOGG(path string, meta *Metadata) (*Metadata, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	header := make([]byte, 28)
	if _, err := f.Read(header); err != nil {
		return nil, err
	}

	if string(header[:4]) != "OggS" {
		return nil, fmt.Errorf("audio: not an OGG file")
	}

	// Vorbis header: sample rate at bytes 12-15
	meta.SampleRate = int(header[12]) | int(header[13])<<8 |
		int(header[14])<<16 | int(header[15])<<24
	meta.BitDepth = 16

	// Estimate bitrate
	meta.Bitrate = 160
	if meta.SampleRate > 0 {
		samples := meta.FileSize / 2 // ~2 bytes per sample approximated
		meta.DurationMs = int(samples * 1000 / int64(meta.SampleRate))
	}
	return meta, nil
}

func readWAV(path string, meta *Metadata) (*Metadata, error) {
	meta.SampleRate = 44100
	meta.BitDepth = 16
	meta.Bitrate = 1411 // CD quality
	// Los divisores se comprueban antes: un WAV con cabecera rara (bit depth 0)
	// dividía por cero y tumbaba el backend.
	bytesPorMuestra := int64(meta.BitDepth / 8)
	if meta.FileSize > 44 && meta.SampleRate > 0 && bytesPorMuestra > 0 {
		audioBytes := meta.FileSize - 44
		meta.DurationMs = int(audioBytes * 8 / int64(meta.SampleRate) / bytesPorMuestra / 2 * 1000)
		// PCM sin comprimir: el tamaño ES la duración.
		meta.DuracionExacta = true
	}
	return meta, nil
}

func readAIFF(path string, meta *Metadata) (*Metadata, error) {
	meta.SampleRate = 44100
	meta.BitDepth = 16
	meta.Bitrate = 1411
	return meta, nil
}

// readBits reads n bits from a byte slice (big-endian).
func readBits(data []byte, n int) int64 {
	var result int64
	for i := 0; i < len(data) && n > 0; {
		bits := 8
		if n < 8 {
			bits = n
		}
		result = (result << bits) | int64(data[i]>>(8-bits))
		n -= bits
		i++
	}
	return result
}
