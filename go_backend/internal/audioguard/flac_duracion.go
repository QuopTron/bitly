// flac_duracion.go — la única verificación de integridad que el protocolo de
// Soulseek NO puede dar.
//
// POR QUÉ HACE FALTA
// El protocolo no tiene checksums: la documentación lo dice explícitamente
// ("The protocol doesn't support hashing of file chunks for verification"), así
// que de la red solo llegan bytes y un tamaño. Contra un par desconocido eso
// deja dos preguntas sin responder: ¿el archivo llegó completo? y ¿es la
// grabación que pedí, o un remix/live/concierto con el mismo nombre?
//
// La cabecera del FLAC responde las dos: STREAMINFO lleva la frecuencia de
// muestreo y el TOTAL de muestras, o sea la duración exacta del audio que hay
// adentro. Contra la duración del catálogo (que ya conocemos gratis) confirma
// que el archivo es la canción correcta, y contra el tamaño esperado confirma
// que no llegó cortado.
package audioguard

import (
	"encoding/binary"
	"os"
)

// DuracionFLAC lee la duración real (en segundos) del audio de un FLAC.
//
// Devuelve ok=false cuando el archivo no es un FLAC legible o no declara sus
// muestras totales (algunos codificadores lo dejan en 0 al escribir a
// streaming). En ese caso NO se puede verificar identidad: el llamador debe
// decidir si acepta el archivo solo por su cabecera.
func DuracionFLAC(ruta string) (float64, bool) {
	f, err := os.Open(ruta)
	if err != nil {
		return 0, false
	}
	defer f.Close()

	// "fLaC" + cabecera del bloque de metadata (1 byte tipo/último + 3 de tamaño)
	// + STREAMINFO. Los campos que interesan están en los primeros 26 bytes.
	var buf [26]byte
	if _, err := readFull(f, buf[:]); err != nil {
		return 0, false
	}
	if string(buf[:4]) != "fLaC" {
		return 0, false
	}
	// El último bit de la 1ª cabecera marca el fin de metadatos y el tipo va en
	// los 7 bits altos; STREAMINFO es el tipo 0 y por spec va primero.
	if buf[4]&0x7F != 0 {
		return 0, false
	}

	// A partir del offset 8: min block(2) + max block(2) + min frame(3) +
	// max frame(3) = 10 bytes; después viene el bloque combinado de 8 bytes
	// con sample rate (20), canales-1 (3), bits por muestra-1 (5) y muestras
	// totales (36).
	combinado := binary.BigEndian.Uint64(buf[18:26])
	frecuencia := uint32(combinado >> 44)
	muestrasTotales := combinado & 0xFFFFFFFFF // 36 bits
	if frecuencia == 0 || muestrasTotales == 0 {
		return 0, false
	}
	return float64(muestrasTotales) / float64(frecuencia), true
}

// FrecuenciaYProfundidadFLAC devuelve (Hz, bits por muestra) del STREAMINFO.
// Sirve para rechazar un archivo que se anuncia como FLAC 24/96 y en realidad
// es un transcodificado de un MP3 (16/44.1): la extensión no prueba nada.
func FrecuenciaYProfundidadFLAC(ruta string) (int, int, bool) {
	f, err := os.Open(ruta)
	if err != nil {
		return 0, 0, false
	}
	defer f.Close()
	var buf [26]byte
	if _, err := readFull(f, buf[:]); err != nil {
		return 0, 0, false
	}
	if string(buf[:4]) != "fLaC" || buf[4]&0x7F != 0 {
		return 0, 0, false
	}
	combinado := binary.BigEndian.Uint64(buf[18:26])
	frecuencia := int(combinado >> 44)
	profundidad := int((combinado>>36)&0x1F) + 1
	if frecuencia == 0 {
		return 0, 0, false
	}
	return frecuencia, profundidad, true
}

// readFull es io.ReadFull pero local, para no arrastrar el import a cada
// llamador.
func readFull(f *os.File, buf []byte) (int, error) {
	total := 0
	for total < len(buf) {
		n, err := f.Read(buf[total:])
		total += n
		if err != nil {
			return total, err
		}
	}
	return total, nil
}
