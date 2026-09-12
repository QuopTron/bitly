// Índice ISRC de la música LOCAL del usuario.
//
// Qué hace: une las dos piezas que ya existían sueltas en el backend —
// library.Scan (que lee metadata de una carpeta) y cache.ISRCIndex (que
// indexa ISRC) — en una sola tabla "ISRC → archivo en disco".
//
// Para qué sirve: cuando el usuario importa su música (compras de Amazon,
// archivos de iTunes Match, FLAC propios), el resto de la app puede saber
// qué canciones YA TIENE. Con eso:
//   - no se vuelven a descargar (Faltantes devuelve solo lo que falta),
//   - se puede reproducir el archivo local (RutaLocal).
//
// Se conecta con: library.Scan (rastreo), cache.ISRCIndex (índice real),
// exports_library.go (puente hacia Flutter) y, a futuro, el orquestador de
// descargas (que consulta Faltantes antes de bajar).
package library

import (
	"sync"

	"github.com/zarz/bitly/go_backend/internal/audio"
	"github.com/zarz/bitly/go_backend/internal/cache"
)

// IndiceLocal mantiene el mapa ISRC → archivo local. Envuelve un
// cache.ISRCIndex (thread-safe) y agrega la parte de biblioteca: rellenar la
// ruta real del archivo y responder consultas de "qué me falta".
type IndiceLocal struct {
	mu  sync.RWMutex
	idx *cache.ISRCIndex
}

// completarISRC rellena el ISRC de una entrada ya escaneada.
//
// Hace falta porque internal/audio NO devuelve el ISRC al leer (solo lo escribe
// al etiquetar): los parsers reales de ISRC viven en internal/cache. Sin esto,
// la música importada quedaría sin ISRC y el dedupe no la reconocería.
func completarISRC(entrada *Entry) {
	if entrada == nil {
		return
	}
	if entrada.Metadata == nil {
		entrada.Metadata = &audio.Metadata{FilePath: entrada.FilePath, FileSize: entrada.Size}
	}
	if entrada.Metadata.ISRC != "" {
		return
	}
	isrc, ref := cache.ExtraerISRCDeArchivo(entrada.FilePath)
	if isrc == "" {
		return
	}
	entrada.Metadata.ISRC = isrc
	if ref == nil {
		return
	}
	if entrada.Metadata.Title == "" {
		entrada.Metadata.Title = ref.Title
	}
	if entrada.Metadata.Artist == "" {
		entrada.Metadata.Artist = ref.ArtistName
	}
	if entrada.Metadata.Album == "" {
		entrada.Metadata.Album = ref.AlbumName
	}
}

// NuevoIndiceLocal crea un índice vacío, listo para indexar una carpeta.
func NuevoIndiceLocal() *IndiceLocal {
	return &IndiceLocal{idx: cache.NewISRCIndex()}
}

// IndexarDirectorio escanea una carpeta completa en paralelo y guarda cada
// archivo por su ISRC. Es incremental: los archivos sin cambios se saltan.
// Devuelve cuántos ISRC quedaron indexados en total.
func (i *IndiceLocal) IndexarDirectorio(directorio string) (int, error) {
	i.mu.Lock()
	defer i.mu.Unlock()
	if directorio == "" {
		return i.idx.Len(), nil
	}
	if err := i.idx.BuildIndex(directorio); err != nil {
		return i.idx.Len(), err
	}
	return i.idx.Len(), nil
}

// IndexarEntradas mete al índice las entradas ya escaneadas por library.Scan.
// Sirve cuando el rastreo y la lectura de metadata ya se hicieron aparte.
func (i *IndiceLocal) IndexarEntradas(entradas []Entry) int {
	i.mu.Lock()
	defer i.mu.Unlock()
	agregados := 0
	for _, entrada := range entradas {
		if entrada.Metadata == nil {
			continue
		}
		isrc := entrada.Metadata.ISRC
		if isrc == "" {
			continue
		}
		i.idx.Add(isrc, &cache.TrackRef{
			Title:      entrada.Metadata.Title,
			ArtistName: entrada.Metadata.Artist,
			AlbumName:  entrada.Metadata.Album,
			Provider:   "local",
			FilePath:   entrada.FilePath,
		})
		agregados++
	}
	return agregados
}

// Faltantes devuelve, de la lista de ISRCs recibida, solo los que NO están en
// la biblioteca local. Es lo que evita volver a descargar lo que ya se tiene.
func (i *IndiceLocal) Faltantes(isrcs []string) []string {
	if len(isrcs) == 0 {
		return nil
	}
	i.mu.RLock()
	defer i.mu.RUnlock()
	var faltan []string
	vistos := make(map[string]bool, len(isrcs))
	for _, isrc := range isrcs {
		if isrc == "" || vistos[isrc] {
			continue
		}
		vistos[isrc] = true
		if !i.idx.Has(isrc) {
			faltan = append(faltan, isrc)
		}
	}
	return faltan
}

// RutaLocal devuelve la ruta del archivo para un ISRC, o "" si no está.
func (i *IndiceLocal) RutaLocal(isrc string) string {
	i.mu.RLock()
	defer i.mu.RUnlock()
	ref, ok := i.idx.Lookup(isrc)
	if !ok || ref == nil {
		return ""
	}
	return ref.FilePath
}

// Cantidad devuelve cuántos ISRC hay indexados.
func (i *IndiceLocal) Cantidad() int {
	i.mu.RLock()
	defer i.mu.RUnlock()
	return i.idx.Len()
}

// Limpiar vacía el índice (lo usa el cambio de carpeta o el re-escaneo total).
func (i *IndiceLocal) Limpiar() {
	i.mu.Lock()
	defer i.mu.Unlock()
	i.idx.Clear()
}
