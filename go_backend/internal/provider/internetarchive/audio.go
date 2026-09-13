// audio.go — Clasificación de archivos y resolución del audio de Internet
// Archive: qué archivos son audio, cuáles son lossless (FLAC) y cómo pasar de
// una pista a su URL de descarga reproducible.
//
// Por qué separado: la decisión "FLAC o MP3" es el corazón de esta fuente. Un
// item de archive.org publica el mismo concierto en varios formatos (Flac, VBR
// MP3, Ogg Vorbis, Spectrogram, Item Tile...), y hay que elegir el lossless
// cuando existe y caer al MP3 solo si no lo hay.
//
// Se conecta con: detalle.go y busqueda.go (selección de archivos).
// Parte del flujo: resolución de audio del proveedor.
package internetarchive

import (
	"fmt"
	"strconv"
	"strings"
)

// TipoAudio clasifica un archivo del item.
type TipoAudio int

const (
	// NoAudio es cualquier archivo que no es audio (imágenes, texto, torrents).
	NoAudio TipoAudio = iota
	// Lossy es audio comprimido (MP3, Ogg, AAC...).
	Lossy
	// Lossless es audio sin pérdida (FLAC, WAV, AIFF, ALAC).
	Lossless
)

// formatosNoAudio son subproductos que archive.org mete en TODOS los items de
// audio y que jamás deben tratarse como pistas reproducibles.
var formatosNoAudio = []string{
	"item tile", "jpeg", "png", "thumbnail", "spectrogram", "text",
	"metadata", "json", "xml", "zip", "bittorrent", "log", "cue sheet",
	"unknown", "gif", "pdf", "svg",
}

// clasificarArchivo decide qué es un archivo por su campo format.
func clasificarArchivo(formato string) TipoAudio {
	f := strings.ToLower(strings.TrimSpace(formato))
	if f == "" {
		return NoAudio
	}
	for _, falso := range formatosNoAudio {
		if strings.Contains(f, falso) {
			return NoAudio
		}
	}
	// Lossless primero: "24bit Flac" contiene "flac", y "flac" gana a "mp3"
	// aunque el nombre sea raro.
	for _, lossless := range []string{"flac", "wav", "aiff", "apple lossless", "alac"} {
		if strings.Contains(f, lossless) {
			return Lossless
		}
	}
	for _, lossy := range []string{"mp3", "ogg", "aac", "m4a", "opus", "vbr"} {
		if strings.Contains(f, lossy) {
			return Lossy
		}
	}
	return NoAudio
}

// esAudio util para los conteos de portada y de pistas.
func esAudio(formato string) bool { return clasificarArchivo(formato) != NoAudio }

// duracionMS convierte el campo length de archive.org a milisegundos.
//
// El servicio devuelve DOS formatos según el archivo, y ambos aparecen en el
// mismo item: "177.41" (segundos con decimales) y "34:38" (mm:ss). El resto del
// backend trabaja en milisegundos, así que se normaliza acá.
func duracionMS(bruto string) int {
	texto := strings.TrimSpace(bruto)
	if texto == "" {
		return 0
	}
	if strings.Contains(texto, ":") {
		total := 0.0
		for _, parte := range strings.Split(texto, ":") {
			valor, err := strconv.ParseFloat(strings.TrimSpace(parte), 64)
			if err != nil {
				return 0
			}
			total = total*60 + valor
		}
		return int(total * 1000)
	}
	valor, err := strconv.ParseFloat(texto, 64)
	if err != nil {
		return 0
	}
	return int(valor * 1000)
}

// tituloDesdeArchivo deriva un título legible del nombre del archivo cuando el
// item no publica el campo title (pasa en muchos conciertos).
//
// "inplainair2024-04-06_01.flac" → "inplainair2024-04-06_01" y se limpian los
// prefijos numéricos tipo "01 - " o "01.".
func tituloDesdeArchivo(nombre string) string {
	base := nombre
	if i := strings.LastIndex(base, "/"); i >= 0 {
		base = base[i+1:]
	}
	if i := strings.LastIndex(base, "."); i > 0 {
		base = base[:i]
	}
	base = strings.TrimSpace(base)
	if i := strings.Index(base, " - "); i > 0 && esSoloNumero(base[:i]) {
		base = strings.TrimSpace(base[i+3:])
	} else if i := strings.Index(base, ". "); i > 0 && esSoloNumero(base[:i]) {
		base = strings.TrimSpace(base[i+2:])
	}
	if base == "" {
		return nombre
	}
	return base
}

// esSoloNumero reporta si el texto es un número de pista (1, "01", "12").
func esSoloNumero(texto string) bool {
	texto = strings.TrimSpace(texto)
	if texto == "" || len(texto) > 4 {
		return false
	}
	_, err := strconv.Atoi(texto)
	return err == nil
}

// mismaCancion decide si [archivo] es el mismo tema que [referencia], para
// poder cambiar entre el FLAC y su MP3 hermano sin servir otra pista.
//
// El criterio es la pista (`track`) y, si no está, el nombre base sin
// extensión. Así "show_03.flac" y "show_03.mp3" se reconocen hermanos, pero
// "show_03.flac" y "show_13.mp3" no.
func mismaCancion(referencia Archivo, archivo Archivo) bool {
	if t := strings.TrimSpace(string(referencia.Track)); t != "" {
		if t == strings.TrimSpace(string(archivo.Track)) {
			return true
		}
	}
	return sinExtension(referencia.Name) == sinExtension(archivo.Name)
}

// sinExtension quita el directorio y la extensión de un nombre de archivo.
func sinExtension(nombre string) string {
	base := nombre
	if i := strings.LastIndex(base, "/"); i >= 0 {
		base = base[i+1:]
	}
	if i := strings.LastIndex(base, "."); i > 0 {
		base = base[:i]
	}
	return strings.ToLower(strings.TrimSpace(base))
}

// quiereLossless interpreta la calidad pedida por el reproductor. Cualquier
// valor desconocido se trata como lossless: la fuente es FLAC y degradar sin
// que lo pidan contradice el motivo por el que existe esta fuente.
func quiereLossless(quality string) bool {
	switch strings.ToUpper(strings.TrimSpace(quality)) {
	case "MP3", "MP3_320", "MP3_128", "320", "128", "HIGH", "LOW", "LOSSY":
		return false
	default:
		return true
	}
}

// elegirArchivo escoge, dentro del item, el archivo que corresponde a [id] con
// el mejor formato para [quality]:
//
//  1. si el archivo del id ya tiene el formato pedido, se usa ese;
//  2. si no, se busca su hermano (misma pista) del formato pedido;
//  3. si no hay hermano, se devuelve el archivo del id tal cual.
func elegirArchivo(item *Item, archivo Archivo, quality string) (Archivo, error) {
	if item == nil {
		return Archivo{}, fmt.Errorf("%s: item vacío", name)
	}
	tipo := clasificarArchivo(archivo.Format)
	if tipo == NoAudio {
		return Archivo{}, fmt.Errorf("%s: %q no es audio", name, archivo.Name)
	}

	lossless := quiereLossless(quality)
	if (tipo == Lossless) == lossless {
		return archivo, nil
	}

	deseado := Lossy
	if lossless {
		deseado = Lossless
	}
	var candidatos []Archivo
	for _, f := range item.Files {
		if clasificarArchivo(f.Format) != deseado || !mismaCancion(archivo, f) {
			continue
		}
		candidatos = append(candidatos, f)
	}
	if len(candidatos) == 0 {
		// Sin hermano del formato pedido: mejor servir algo reproducible que
		// fallar (el reproductor acepta el MP3, y el FLAC suena igual de bien).
		return archivo, nil
	}
	return mejorDe(candidatos, deseado), nil
}

// mejorDe ordena los candidatos del mismo tipo y devuelve el mejor. En lossy
// prefiere MP3 sobre Ogg/Opus (más compatible con media_kit); en lossless, FLAC.
func mejorDe(candidatos []Archivo, deseado TipoAudio) Archivo {
	mejor := candidatos[0]
	mejorPuntaje := puntajeFormato(mejor.Format, deseado)
	for _, c := range candidatos[1:] {
		if p := puntajeFormato(c.Format, deseado); p > mejorPuntaje {
			mejor, mejorPuntaje = c, p
		}
	}
	return mejor
}

// puntajeFormato puntúa un formato para elegir entre hermanos.
func puntajeFormato(formato string, deseado TipoAudio) int {
	f := strings.ToLower(formato)
	if deseado == Lossless {
		switch {
		case strings.Contains(f, "24bit"), strings.Contains(f, "24-bit"), strings.Contains(f, "hi-res"):
			return 3
		case strings.Contains(f, "flac"):
			return 2
		default: // wav/aiff/alac
			return 1
		}
	}
	switch {
	case strings.Contains(f, "mp3"):
		return 2
	default: // ogg/opus/aac
		return 1
	}
}

// GetStreamURL resuelve una pista a su URL de audio directa. Es un simple
// armado de URL (el item y sus archivos ya se validaron al buscar), pero se
// re-consulta el item para que el id siga siendo válido aunque el archivo haya
// cambiado de nombre.
//
// La URL sale apuntando al nodo directo del item cuando la metadata lo publica:
// eso se lleva el salto de /download/ y baja el arranque de ~1,7 s a ~0,7 s.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	identifier, archivo, err := partirID(id)
	if err != nil {
		return "", err
	}
	item, err := c.obtenerItem(identifier)
	if err != nil {
		return "", err
	}
	elegido := coincidirArchivo(item, archivo)
	if elegido == nil {
		return "", fmt.Errorf("%s: %q ya no existe en %s", name, archivo, identifier)
	}
	final, err := elegirArchivo(item, *elegido, quality)
	if err != nil {
		return "", err
	}
	return c.urlAudio(item, identifier, final.Name), nil
}

// coincidirArchivo busca [nombre] dentro del item tolerando el escapado de URL
// y diferencias de mayúsculas.
func coincidirArchivo(item *Item, nombre string) *Archivo {
	if item == nil {
		return nil
	}
	for i := range item.Files {
		if item.Files[i].Name == nombre {
			return &item.Files[i]
		}
	}
	objetivo := strings.ToLower(strings.TrimSpace(nombre))
	for i := range item.Files {
		if strings.ToLower(item.Files[i].Name) == objetivo {
			return &item.Files[i]
		}
	}
	// Último recurso: mismo nombre base (el item pudo re-encodear el sufijo).
	base := sinExtension(nombre)
	for i := range item.Files {
		if esAudio(item.Files[i].Format) && sinExtension(item.Files[i].Name) == base {
			return &item.Files[i]
		}
	}
	return nil
}
