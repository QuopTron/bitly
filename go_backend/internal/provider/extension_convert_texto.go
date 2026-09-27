package provider

// extension_convert_texto.go — Normalizador ÚNICO de los campos que devuelven
// las extensiones, para que las nueve se lean igual.
//
// Por qué existe: cada extensión tiene una forma distinta de escribir lo mismo.
// `artists` puede ser un string ("A, B"), un arreglo (["A","B"]) o un arreglo de
// objetos ([{name:"A"}]) según la fuente; `album` a veces es un objeto
// ({id,title}) y otras un string; la duración llega como `duration_ms`, como
// `duration` en segundos o como "3:45"; el ISRC aparece como `isrc`, `isrc_code`
// o `isrcCode`; las carátulas como `cover_url`, `images` (arreglo de {url}) o
// `picture_xl`. Con un getString que solo aceptaba strings, un arreglo o un
// objeto se leía como "" SIN aviso: el artista, el álbum o el ISRC se perdían y
// el matching caía a una búsqueda por nombre donde aparece la versión
// equivocada (el caso "BbY WOW" de piano).
//
// Estos helpers son la ÚNICA vía de lectura de esos campos: los usan tanto los
// conversores de búsqueda/feed/detalle del paquete provider como los mappers de
// detalle del backend, así que las nueve extensiones quedan parseadas igual en
// todas las vistas.

import (
	"strconv"
	"strings"
)

// textoFlexible normaliza un valor JS suelto a texto.
//
//   - string  → tal cual (recortado)
//   - arreglo → sus elementos unidos por ", " (["A","B"] → "A, B")
//   - objeto  → su nombre/título ({name:"A"} o {title:"Album"} → "A"/"Album")
//
// Devolver "" para un valor ilegible es deliberado: significa "el campo no
// estaba", que es como lo tratan todos los llamadores.
func textoFlexible(v interface{}) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return strings.TrimSpace(t)
	case []interface{}:
		partes := make([]string, 0, len(t))
		for _, e := range t {
			if s := textoFlexible(e); s != "" {
				partes = append(partes, s)
			}
		}
		return strings.Join(partes, ", ")
	case map[string]interface{}:
		return getString(t, "name", "title", "text", "label", "artist", "artists")
	default:
		return ""
	}
}

// TextoDeCampo devuelve el primer campo presente con contenido, normalizado a
// texto. Salta los vacíos para que "artists vacío + artist con dato" siga
// tomando el dato.
func TextoDeCampo(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s := textoFlexible(v); s != "" {
				return s
			}
		}
	}
	return ""
}

// EnteroDeCampo lee el primer entero presente (número o string numérico).
func EnteroDeCampo(m map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		v, ok := m[k]
		if !ok || v == nil {
			continue
		}
		if n := enteroFlexible(v); n != 0 {
			return n
		}
	}
	return 0
}

func enteroFlexible(v interface{}) int {
	switch n := v.(type) {
	case float64:
		return int(n)
	case float32:
		return int(n)
	case int64:
		return int(n)
	case int:
		return n
	case string:
		s := strings.TrimSpace(n)
		if s == "" {
			return 0
		}
		if i, err := strconv.Atoi(s); err == nil {
			return i
		}
		if f, err := strconv.ParseFloat(s, 64); err == nil {
			return int(f)
		}
	}
	return 0
}

// DuracionDeCampo devuelve la duración en milisegundos, entendiendo las tres
// formas que usan las extensiones: `duration_ms`/`durationMs` (ms), `duration`
// numérica (segundos si es < 6000, ms si no) o "M:SS"/"H:MM:SS".
func DuracionDeCampo(m map[string]interface{}, keys ...string) int {
	for _, k := range keys {
		v, ok := m[k]
		if !ok || v == nil {
			continue
		}
		if ms := duracionFlexible(v); ms > 0 {
			return ms
		}
	}
	return 0
}

func duracionFlexible(v interface{}) int {
	switch t := v.(type) {
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return 0
		}
		if strings.Contains(s, ":") {
			return mmssAMs(s)
		}
		if f, err := strconv.ParseFloat(s, 64); err == nil {
			return segundosOMs(int(f))
		}
		return 0
	default:
		return segundosOMs(enteroFlexible(v))
	}
}

// segundosOMs interpreta un valor suelto: por debajo de 6000 son segundos (las
// APIs de catálogo suelen publicar la duración en segundos), de ahí para arriba
// ya son milisegundos. La cota cubre con margen cualquier canción real.
func segundosOMs(n int) int {
	if n <= 0 {
		return 0
	}
	if n < 6000 {
		return n * 1000
	}
	return n
}

// mmssAMs parsea "3:45" o "1:02:03" a milisegundos.
func mmssAMs(s string) int {
	partes := strings.Split(s, ":")
	if len(partes) < 2 || len(partes) > 3 {
		return 0
	}
	total := 0
	for _, p := range partes {
		n, err := strconv.Atoi(strings.TrimSpace(p))
		if err != nil || n < 0 {
			return 0
		}
		total = total*60 + n
	}
	return total * 1000
}

// ISRCDeCampo normaliza el ISRC con sus alias (`isrc`, `isrc_code`, `isrcCode`)
// y lo devuelve en mayúsculas, que es como lo comparan el resto del backend.
func ISRCDeCampo(m map[string]interface{}) string {
	return strings.ToUpper(TextoDeCampo(m, "isrc", "isrc_code", "isrcCode", "ISRC"))
}

// PortadaDeCampo resuelve la carátula desde las formas que usan las nueve
// extensiones: string directo, objeto con url/href/src, o arreglo de imágenes
// (Spotify/Apple publican primero la más grande).
func PortadaDeCampo(m map[string]interface{}) string {
	if s := getString(m, "cover_url", "coverUrl", "cover", "image_url", "imageUrl",
		"picture_xl", "picture_big", "picture_medium", "picture", "thumbnail"); s != "" {
		return s
	}
	for _, k := range []string{"images", "image"} {
		if v, ok := m[k]; ok && v != nil {
			if s := urlDeImagenes(v); s != "" {
				return s
			}
		}
	}
	return ""
}

func urlDeImagenes(v interface{}) string {
	switch t := v.(type) {
	case string:
		return strings.TrimSpace(t)
	case map[string]interface{}:
		return getString(t, "url", "href", "src", "cover_url", "coverUrl", "image_url")
	case []interface{}:
		for _, e := range t {
			if s := urlDeImagenes(e); s != "" {
				return s
			}
		}
	}
	return ""
}
