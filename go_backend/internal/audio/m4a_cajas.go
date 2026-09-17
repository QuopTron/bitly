package audio

import "errors"

// errM4AEstructura marca un MP4 cuyas cajas no se pudieron recorrer: en ese caso
// se conserva el archivo original en vez de escribir algo a medias.
var errM4AEstructura = errors.New("ERR_M4A_ESTRUCTURA: cajas MP4 ilegibles")

// cajaMP4 ubica una caja dentro de un buffer: [inicio] apunta a su tamaño y
// [fin] al byte siguiente al final de la caja.
type cajaMP4 struct {
	tipo   string
	inicio int
	fin    int
}

// leerCajasMP4 recorre UN nivel de cajas de [data] (contenido de una caja, sin
// su propia cabecera). Devuelve ok=false si hay bytes que no forman una caja
// válida: reescribir a ciegas un archivo así lo rompería.
func leerCajasMP4(data []byte) ([]cajaMP4, bool) {
	var cajas []cajaMP4
	off := 0
	for off < len(data) {
		if off+8 > len(data) {
			return nil, false
		}
		size := int(data[off])<<24 | int(data[off+1])<<16 |
			int(data[off+2])<<8 | int(data[off+3])
		if size < 8 || off+size > len(data) {
			return nil, false
		}
		cajas = append(cajas, cajaMP4{
			tipo:   string(data[off+4 : off+8]),
			inicio: off,
			fin:    off + size,
		})
		off += size
	}
	return cajas, true
}

// armarCajaMP4 devuelve la caja COMPLETA: tamaño + tipo + contenido.
//
// Es la pieza que faltaba: los escritores recorrían las cajas hijas y volcaban
// solo su contenido, así que el resultado quedaba sin la cabecera del contenedor
// (un moov sin su caja, con mvhd/trak/udta sueltos al tope del archivo) y ningún
// reproductor podía abrir la canción descargada.
func armarCajaMP4(tipo string, contenido []byte) []byte {
	total := uint32(8 + len(contenido))
	out := make([]byte, 0, 8+len(contenido))
	out = append(out, byte(total>>24), byte(total>>16), byte(total>>8), byte(total))
	out = append(out, tipo...)
	return append(out, contenido...)
}

// reemplazarHijaMP4 recorre las cajas de [contenido] y reemplaza la primera de
// tipo [tipo] por lo que devuelva [reemplazo] (que debe venir completo, con su
// cabecera). El resto se copia tal cual y el resultado NO incluye cabecera
// propia: eso lo hace el llamador con armarCajaMP4.
func reemplazarHijaMP4(
	contenido []byte,
	tipo string,
	reemplazo func(contenidoHija []byte) ([]byte, error),
) ([]byte, error) {
	cajas, ok := leerCajasMP4(contenido)
	if !ok {
		return nil, errM4AEstructura
	}
	out := make([]byte, 0, len(contenido))
	reemplazada := false
	for _, c := range cajas {
		hija := contenido[c.inicio:c.fin]
		if c.tipo != tipo {
			out = append(out, hija...)
			continue
		}
		nueva, err := reemplazo(hija)
		if err != nil {
			return nil, err
		}
		out = append(out, nueva...)
		reemplazada = true
	}
	if !reemplazada {
		return nil, errM4AEstructura
	}
	return out, nil
}
