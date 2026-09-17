package audio

import (
	"bytes"
	"strings"
)

// Átomos de etiqueta que entienden los reproductores (iTunes/Apple, ffmpeg,
// mpv). Los nombres con 0xA9 (©) son la convención de iTunes: escribir "nam" o
// tags sueltos dentro de udta NO los muestra ningún reproductor.
const (
	atomoTitulo       = "\xa9nam"
	atomoArtista      = "\xa9ART"
	atomoAlbumArtista = "aART"
	atomoAlbum        = "\xa9alb"
	atomoGenero       = "\xa9gen"
	atomoFecha        = "\xa9day"
)

// paresEtiquetaAtomo asocia la clave interna de Metadata con su átomo iTunes.
type parEtiquetaAtomo struct {
	clave string
	atomo string
}

var paresEtiquetaAtomo = []parEtiquetaAtomo{
	{"Title", atomoTitulo},
	{"Artist", atomoArtista},
	{"AlbumArtist", atomoAlbumArtista},
	{"Album", atomoAlbum},
	{"Genre", atomoGenero},
	{"Date", atomoFecha},
}

// atomosEtiquetasM4A arma los átomos de etiqueta del mapa de tags: los textos
// como átomos iTunes y el ISRC como átomo freeform (así lo guardan los
// reproductores, no hay átomo estándar para ISRC).
func atomosEtiquetasM4A(tags map[string]string) []byte {
	var out bytes.Buffer
	for _, par := range paresEtiquetaAtomo {
		if v := strings.TrimSpace(tags[par.clave]); v != "" {
			out.Write(armarAtomoTextoItunes(par.atomo, v))
		}
	}
	if isrc := strings.TrimSpace(tags["ISRC"]); isrc != "" {
		out.Write(construirAtomoFreeform("ISRC", isrc))
	}
	return out.Bytes()
}

// armarAtomoTextoItunes devuelve un átomo de texto tipo "©nam" con su átomo data
// adentro (tipo 1 = UTF-8, locale 0).
func armarAtomoTextoItunes(nombre, valor string) []byte {
	data := make([]byte, 0, 8+len(valor))
	data = append(data, 0, 0, 0, 1) // tipo de dato: UTF-8
	data = append(data, 0, 0, 0, 0) // locale
	data = append(data, valor...)
	return armarCajaMP4(nombre, armarCajaMP4("data", data))
}

// armarMetaConItunes arma un meta (full box: 4 bytes de versión/flags) con su
// hdlr 'mdir' (obligatorio para que los reproductores lean el ilst) y el ilst
// con [atomos].
func armarMetaConItunes(atomos []byte) []byte {
	hdlr := armarCajaMP4("hdlr", []byte(
		"\x00\x00\x00\x00"+ // versión + flags
			"\x00\x00\x00\x00"+ // pre_defined
			"mdir"+ // handler type
			"appl"+ // handler subtype
			"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", // reserved
	))
	ilst := armarCajaMP4("ilst", atomos)
	cuerpo := make([]byte, 0, 4+len(hdlr)+len(ilst))
	cuerpo = append(cuerpo, 0, 0, 0, 0) // versión + flags del meta
	cuerpo = append(cuerpo, hdlr...)
	cuerpo = append(cuerpo, ilst...)
	return armarCajaMP4("meta", cuerpo)
}

// armarUdtaConEtiquetas crea un udta nuevo con el meta de iTunes adentro, para
// los archivos (típicamente los que baja InnerTube/YouTube) que no traen udta.
func armarUdtaConEtiquetas(atomos []byte) []byte {
	return armarCajaMP4("udta", armarMetaConItunes(atomos))
}
