package download

import (
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/audio"
)

// maxCaratulaBytes acota la carátula que se incrusta: una portada real pesa
// cientos de KB; un archivo mayor no es una portada y no se mete en el audio.
const maxCaratulaBytes = 6 << 20

// tagsSufijo se inserta ANTES de la extensión, que SIEMPRE queda al final:
// `cancion.flac` → `.cancion.tags.partial.flac`. El orden importa: tanto los
// escritores de tags (audio.WriteMetadata) como la verificación de audio
// reconocen el formato POR SUFIJO, así que un nombre terminado en `.partial`
// hacía fallar las dos cosas y el archivo etiquetado se descartaba solo.
const tagsSufijo = ".tags.partial"

// titulosEtiquetables son los contenedores cuyo escritor de tags es nativo
// (no dependemos de ffmpeg para que el archivo quede bien etiquetado).
var extensionesEtiquetables = map[string]bool{
	".flac": true, ".mp3": true, ".m4a": true, ".mp4": true,
}

// cacheCaratulas evita volver a bajar la MISMA portada por cada canción de un
// álbum: la clave es la URL y el valor los bytes ya listos para incrustar.
var (
	cacheCaratulasMu sync.Mutex
	cacheCaratulas   = map[string][]byte{}
)

// yaTieneEtiquetas reporta si el archivo ya trae la metadata que se le escribiría.
//
// Exigente a propósito: alcanza con que falte UN campo (o que la carátula no
// esté incrustada) para etiquetar. Así un archivo que el catálogo describe
// mejor que las etiquetas que traía se sigue mejorando, y solo se saltea el caso
// en el que no habría ningún cambio.
func yaTieneEtiquetas(ruta string, meta *audio.Metadata) bool {
	actual, err := audio.ReadFileMetadata(ruta)
	if err != nil {
		return false
	}
	if meta.Title != "" && !mismoTexto(actual.Title, meta.Title) {
		return false
	}
	if meta.Artist != "" && !mismoTexto(actual.Artist, meta.Artist) {
		return false
	}
	if meta.Album != "" && !mismoTexto(actual.Album, meta.Album) {
		return false
	}
	if meta.ISRC != "" && !strings.EqualFold(strings.TrimSpace(actual.ISRC), strings.TrimSpace(meta.ISRC)) {
		return false
	}
	// Sin carátula incrustada siempre vale la pena intentar escribirla.
	return actual.HasCover
}

// mismoTexto compara dos etiquetas ignorando espacios de los bordes.
func mismoTexto(actual, esperado string) bool {
	return strings.EqualFold(strings.TrimSpace(actual), strings.TrimSpace(esperado))
}

// etiquetarDescarga escribe las etiquetas del catálogo (título/artista/álbum/
// ISRC) y la carátula DENTRO del archivo recién descargado.
//
// Por qué existe: los escritores de tags modifican el archivo con os.WriteFile
// (no atómico) y una descarga no puede quedar corrupta por un corte a mitad de
// la escritura. Por eso se trabaja sobre una COPIA temporal, se verifica que
// siga siendo audio decodificable y recién ahí se reemplaza el original con un
// rename (atómico en el mismo disco).
//
// Es best-effort de punta a punta: si el formato no se soporta, si la carátula
// no se puede bajar o si cualquier paso falla, la descarga queda tal cual (el
// archivo ya es reproducible y la app lee la carátula de su propia caché).
func (o *Orchestrator) etiquetarDescarga(res *Result, req Request) {
	if res == nil || res.FilePath == "" {
		return
	}
	if !extensionesEtiquetables[strings.ToLower(filepath.Ext(res.FilePath))] {
		return
	}
	// Los nombres salen de la petición: es la metadata del catálogo que resolvió
	// el feed (título/artista/álbum/ISRC).
	meta := &audio.Metadata{
		Title:  elegirTexto(req.Title),
		Artist: elegirTexto(req.Artist),
		Album:  elegirTexto(req.Album),
		ISRC:   req.ISRC,
	}
	if meta.Title == "" && meta.Artist == "" && meta.Album == "" && meta.ISRC == "" {
		return
	}
	// Archivo que YA trae la metadata del catálogo (los FLAC de los sitios
	// raspables vienen con título, artista, álbum, ISRC y portada): reescribir
	// 20 MB para no cambiar nada cuesta tiempo del usuario y expone el archivo
	// al escritor de tags sin ganancia.
	if yaTieneEtiquetas(res.FilePath, meta) {
		return
	}

	// La copia de trabajo CONSERVA la extensión real AL FINAL (los escritores de
	// tags y la verificación de audio eligen el formato por sufijo) y va oculta
	// para que ningún escaneo de la carpeta de descargas la tome como un archivo
	// más.
	base := filepath.Base(res.FilePath)
	ext := filepath.Ext(base)
	tmp := filepath.Join(filepath.Dir(res.FilePath),
		"."+strings.TrimSuffix(base, ext)+tagsSufijo+ext)
	if err := copiarArchivo(res.FilePath, tmp); err != nil {
		log.Printf("[tags] no se pudo copiar %s para etiquetar: %v", res.FilePath, err)
		return
	}
	limpiar := func() { _ = os.Remove(tmp) }

	if err := audio.WriteMetadata(tmp, meta); err != nil {
		log.Printf("[tags] metadata no soportada en %s: %v", res.FilePath, err)
	}
	if data := caratulaDe(req.CoverURL); len(data) > 0 {
		if err := audio.WriteCover(tmp, data); err != nil {
			log.Printf("[tags] carátula no incrustada en %s: %v", res.FilePath, err)
		}
	}
	// El archivo etiquetado tiene que seguir siendo audio válido: si algo salió
	// mal, se descarta la copia y queda el original intacto.
	if !esArchivoCacheReproducible(tmp) {
		log.Printf("[tags] el archivo etiquetado deja de ser reproducible, se conserva el original: %s", res.FilePath)
		limpiar()
		return
	}
	if err := os.Rename(tmp, res.FilePath); err != nil {
		log.Printf("[tags] no se pudo reemplazar %s: %v", res.FilePath, err)
		limpiar()
	}
}

// caratulaDe devuelve los bytes de la portada, usando la caché por URL. Un
// fallo (URL vacía, 404, demasiado grande) devuelve nil y no corta nada.
func caratulaDe(url string) []byte {
	url = strings.TrimSpace(url)
	if url == "" || !strings.HasPrefix(url, "http") {
		return nil
	}
	cacheCaratulasMu.Lock()
	if data, ok := cacheCaratulas[url]; ok {
		cacheCaratulasMu.Unlock()
		return data
	}
	cacheCaratulasMu.Unlock()

	cliente := &http.Client{Timeout: 15 * time.Second}
	resp, err := cliente.Get(url)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxCaratulaBytes))
	if err != nil || len(data) == 0 {
		return nil
	}
	cacheCaratulasMu.Lock()
	// Caché acotada: sin tope, recorrer una biblioteca entera acumularía MB en
	// memoria por portadas que ya no se vuelven a usar.
	if len(cacheCaratulas) > 32 {
		cacheCaratulas = map[string][]byte{}
	}
	cacheCaratulas[url] = data
	cacheCaratulasMu.Unlock()
	return data
}

// copiarArchivo copia [origen] a [destino] en streaming (sin cargar el audio
// entero en memoria).
func copiarArchivo(origen, destino string) error {
	in, err := os.Open(origen)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(destino)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		_ = os.Remove(destino)
		return err
	}
	if err := out.Sync(); err != nil {
		out.Close()
		_ = os.Remove(destino)
		return err
	}
	return out.Close()
}

// elegirTexto devuelve el primer texto no vacío.
func elegirTexto(valores ...string) string {
	for _, v := range valores {
		if t := strings.TrimSpace(v); t != "" {
			return t
		}
	}
	return ""
}
