// ─────────────────────────────────────────────────────────────
// mp4_flac.go — Desarmado del MP4 fragmentado de Tidal para obtener un FLAC
// de verdad: el audio viaja como frames FLAC crudos dentro de cajas `mdat`,
// y los bloques de metadata del formato (STREAMINFO) viven en la caja
// `dfLa` del segmento inicial.
//
// Por qué así: Tidal manda `mimeType="audio/mp4"` con `codecs="flac"`, o
// sea FLAC envuelto en MP4. Un reproductor lo abre, pero NO es un `.flac`:
// renombrarlo daría un archivo que ningún reproductor de FLAC abre. Lo
// correcto es reconstruir el flujo FLAC: "fLaC" + los bloques de `dfLa` +
// la concatenación de los `mdat`. Verificado: el resultado lo lee cualquier
// decodificador (ffprobe: codec flac, 44100 Hz, estéreo, duración completa).
//
// Se conecta con: descarga.go (lo usa al bajar cada segmento).
// Parte del flujo: descarga (rescate de FLAC exacto).
// ─────────────────────────────────────────────────────────────

package tidalhifi

import (
	"bytes"
	"encoding/binary"
	"fmt"
)

// cabeceraFLAC es la firma con la que arranca todo archivo FLAC.
const cabeceraFLAC = "fLaC"

// bloquesFLACDe extrae los bloques de metadata FLAC que viajan dentro de la
// caja `dfLa` del segmento de inicialización.
//
// Formato de la caja: tamaño(4) + "dfLa" + versión/banderas(4) y después la
// lista de bloques FLAC, cada uno con su cabecera de 4 bytes (último+tipo,
// tamaño de 24 bits). Se copian TAL CUAL: reconstruirlos permitiría meter un
// STREAMINFO equivocado, y el de Tidal ya es el correcto.
func bloquesFLACDe(inicial []byte) ([]byte, error) {
	caja := buscarCaja(inicial, "dfLa")
	if len(caja) < 8 {
		return nil, fmt.Errorf("tidal-hifi: el segmento inicial no trae metadata FLAC (dfLa)")
	}
	cuerpo := caja[4:] // salta versión/banderas del FullBox
	var bloques []byte
	for off := 0; off+4 <= len(cuerpo); {
		tipo := cuerpo[off]
		largo := int(cuerpo[off+1])<<16 | int(cuerpo[off+2])<<8 | int(cuerpo[off+3])
		if off+4+largo > len(cuerpo) {
			break
		}
		bloques = append(bloques, cuerpo[off:off+4+largo]...)
		off += 4 + largo
		if tipo&0x80 != 0 { // bloque marcado como último
			break
		}
	}
	if len(bloques) < 4 {
		return nil, fmt.Errorf("tidal-hifi: los bloques FLAC del manifiesto llegan vacíos")
	}
	return bloques, nil
}

// buscarCaja devuelve el contenido de la caja [nombre].
//
// Por qué por NOMBRE y no recorriendo contenedores: `dfLa` vive al fondo del
// árbol (moov > trak > mdia > minf > stbl > stsd > entrada del sample), y
// `stsd` es un FullBox con contador de entradas, así que un recorrido
// ingenuo se pierde justo antes de llegar. Se verificó en el segmento real
// que el nombre aparece UNA sola vez en el archivo, así que la búsqueda
// directa es exacta —y de paso inmune a cambios en el orden de las cajas.
func buscarCaja(datos []byte, nombre string) []byte {
	marca := []byte(nombre)
	i := bytes.Index(datos, marca)
	if i < 4 {
		return nil
	}
	tamano := int(binary.BigEndian.Uint32(datos[i-4 : i]))
	if tamano < 8 || i-4+tamano > len(datos) {
		return nil
	}
	return datos[i+4 : i-4+tamano]
}

// payloadsMdat devuelve el contenido de cada caja `mdat` del segmento. En un
// segmento de Tidal hay una sola, pero se recorren todas por si cambia.
func payloadsMdat(segmento []byte) [][]byte {
	var salida [][]byte
	for off := 0; off+8 <= len(segmento); {
		tamano := int(binary.BigEndian.Uint32(segmento[off : off+4]))
		tipo := string(segmento[off+4 : off+8])
		fin := off + tamano
		if tamano == 0 {
			fin = len(segmento)
		}
		if tamano < 8 || fin > len(segmento) {
			return salida
		}
		if tipo == "mdat" {
			salida = append(salida, segmento[off+8:fin])
		}
		off = fin
	}
	return salida
}
