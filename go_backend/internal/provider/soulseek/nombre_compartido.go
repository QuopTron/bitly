// nombre_compartido.go — de la ruta compartida al par artista/título.
//
// POR QUÉ ES CLAVE
// Soulseek no tiene campos de metadata: lo único que llega es la RUTA del
// archivo como la nombra el otro usuario ("Daft Punk - One More Time.flac").
// El ranking del repo (provider.OriginalStrength → RankOriginalCandidates)
// exige título fuerte Y evidencia de artista, así que si se manda la ruta
// cruda como título, el candidato bueno se descarta y Soulseek nunca gana un
// match — aunque tenga el FLAC exacto.
//
// Lo que se hace acá es interpretar la convención que usa prácticamente toda
// la red: "Artista - Título", con guiones bajos por espacios, número de pista
// adelante y la carpeta ignorada. Es best-effort y conservador: si no hay
// separador reconocible, se devuelve el nombre limpio como título y artista
// vacío (el ranking sigue pudiendo aceptarlo por título fuerte).
package soulseek

import (
	"path"
	"strings"
)

// parsearNombreCompartido interpreta una ruta compartida.
//
//	"Music/Daft Punk/Discovery/01 - One More Time.flac"
//	    → artista "Daft Punk", título "One More Time"
//	"Daft Punk - One More Time.mp3"
//	    → artista "Daft Punk", título "One More Time"
//	"One_More_Time.flac"
//	    → artista "", título "One More Time"
func parsearNombreCompartido(ruta string) (artista, titulo string) {
	base := nombreBase(ruta)
	base = quitarExtension(base)
	base = strings.ReplaceAll(base, "_", " ")
	base = colapsarEspacios(base)
	if base == "" {
		return "", ""
	}

	// El número de pista se saca PRIMERO: en "01 - Daft Punk - Tema" el primer
	// guion separa la pista, no el artista. Hacerlo al revés daría artista "01".
	base = quitarNumeroDePista(base)

	// Separador " - " (guion CON espacios): el que usa la red para
	// "Artista - Título". Un guion pegado ("Guns N' Roses") no cuenta.
	if i := strings.Index(base, " - "); i > 0 {
		artista = strings.TrimSpace(base[:i])
		titulo = strings.TrimSpace(base[i+3:])
		// "Artista - Álbum - 01 - Título": al partir por el primero quedan más
		// segmentos; el título es el ÚLTIMO (el nombre de la pista), que es lo
		// que se busca como canción.
		if strings.Contains(titulo, " - ") {
			partes := strings.Split(titulo, " - ")
			titulo = strings.TrimSpace(quitarNumeroDePista(partes[len(partes)-1]))
		}
		if artista != "" && titulo != "" {
			return artista, titulo
		}
	}

	// El nombre no traía artista: se busca en la CARPETA, que es donde vive en
	// el layout más común de la red (<raíz>/<Artista>/<Álbum>/archivo).
	//
	// Por qué es seguro intentarlo: si el nombre de carpeta elegido no es el
	// artista, el puntaje de artista queda bajo y el candidato cae a la pasada
	// best-effort (la misma en la que caería con artista vacío) — o sea, un
	// acierto lo promueve a original estricto y un error NO lo empeora. Nunca
	// se descarta a nadie por esto.
	return artistaDesdeCarpetas(carpetasDe(ruta)), strings.TrimSpace(base)
}

// carpetasNoArtista son raíces/carpetas de contenedor: nunca son el artista.
var carpetasNoArtista = map[string]bool{
	"music": true, "musica": true, "música": true, "mi musica": true,
	"mi música": true, "musica compartida": true, "música compartida": true,
	"audio": true, "flac": true, "mp3": true, "lossless": true,
	"albums": true, "álbumes": true, "albumes": true, "discos": true,
	"downloads": true, "descargas": true, "descargado": true,
	"shared": true, "compartida": true, "compartido": true,
	"torrents": true, "soulseek": true, "soulseek downloads": true,
}

func esCarpetaRaiz(c string) bool {
	return carpetasNoArtista[strings.ToLower(strings.TrimSpace(c))]
}

// carpetasDe devuelve las carpetas de la ruta (sin el archivo), en orden.
func carpetasDe(ruta string) []string {
	normalizada := strings.ReplaceAll(ruta, "\\", "/")
	dir := path.Dir(normalizada)
	if dir == "." || dir == "/" || dir == "" {
		return nil
	}
	var salida []string
	for _, parte := range strings.Split(dir, "/") {
		parte = strings.TrimSpace(parte)
		// Se descartan las raíces vacías ("C:" queda como "C:" por el
		// ReplaceAll, así que también se filtra por prefijo de unidad).
		if parte == "" || parte == "." || parte == ".." || strings.HasSuffix(parte, ":") {
			continue
		}
		salida = append(salida, parte)
	}
	return salida
}

// artistaDesdeCarpetas aplica la convención <raíz>/<Artista>/<Álbum>/archivo:
// se salta la raíz conocida y el artista es el PRIMER nivel que queda después.
func artistaDesdeCarpetas(carpetas []string) string {
	inicio := 0
	for i, c := range carpetas {
		if esCarpetaRaiz(c) {
			inicio = i + 1
		}
	}
	if inicio >= len(carpetas) {
		return ""
	}
	candidato := strings.TrimSpace(carpetas[inicio])
	if esCarpetaRaiz(candidato) || esNumeroDePista(candidato) {
		return ""
	}
	return candidato
}

// nombreBase devuelve el último componente de la ruta, aceptando los dos
// separadores (la red mezcla "\" de Windows y "/").
func nombreBase(ruta string) string {
	ruta = strings.ReplaceAll(ruta, "\\", "/")
	return path.Base(ruta)
}

func quitarExtension(base string) string {
	i := strings.LastIndex(base, ".")
	if i <= 0 {
		return base
	}
	// Solo se corta si lo que sigue al último punto parece una extensión (sin
	// espacios): así "Mr. Brightside" no pierde medio título cuando el par no
	// declaró extensión.
	if strings.ContainsRune(base[i+1:], ' ') {
		return base
	}
	return base[:i]
}

// quitarNumeroDePista saca el "01 - ", "01. ", "1_" o "[01] " del principio.
func quitarNumeroDePista(s string) string {
	s = strings.TrimSpace(s)
	// Corchetes tipo "[01] Tema".
	if strings.HasPrefix(s, "[") {
		if fin := strings.Index(s, "]"); fin > 0 && fin <= 4 {
			resto := strings.TrimSpace(s[fin+1:])
			if resto != "" && esSoloDigitos(s[1:fin]) {
				s = resto
			}
		}
	}
	i := 0
	for i < len(s) && s[i] >= '0' && s[i] <= '9' {
		i++
	}
	if i == 0 || i > 3 {
		return s
	}
	// Después de los dígitos tiene que venir un separador de pista; si no,
	// "24K Magic" perdería el número y quedaría "K Magic".
	resto := s[i:]
	recortado := strings.TrimLeft(resto, " .-_")
	if len(recortado) == len(resto) {
		return s
	}
	return strings.TrimSpace(recortado)
}

// esNumeroDePista reporta si el texto es SOLO un número de pista ("01", "[3]").
// Se usa para no confundir una carpeta "01" con el nombre de un artista.
func esNumeroDePista(s string) bool {
	t := strings.TrimSpace(s)
	t = strings.TrimSpace(strings.Trim(t, "[]() "))
	if t == "" || len(t) > 3 {
		return false
	}
	return esSoloDigitos(t)
}

func esSoloDigitos(s string) bool {
	if s == "" {
		return false
	}
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

func colapsarEspacios(s string) string {
	campos := strings.Fields(s)
	return strings.Join(campos, " ")
}
