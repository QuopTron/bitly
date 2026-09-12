package provider

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cache"
)

// Caché de metadata de los proveedores de extensión.
//
// TODAS las llamadas a una extensión (búsqueda, detalle y feed) pasan por
// ExtensionProvider.callOp. Cachear ahí cubre a las 9 fuentes de una sola vez
// y hace que repetir una búsqueda o volver a abrir un álbum sea instantáneo,
// sin volver a tocar la red — que es lo que el usuario percibe como lento.
//
// Qué se cachea y por cuánto:
//   - detalle (getTrack/getAlbum/getArtist/getPlaylist) → 10 min. Un álbum o
//     un artista cambian muy rara vez; volver a la ficha no debe re-consultar.
//   - búsqueda (searchTracks/customSearch/...) → 2 min. Suficiente para que
//     teclear, borrar y volver a buscar se sienta instantáneo sin servir
//     resultados viejos durante mucho tiempo.
//   - feed (getHomeFeed) → 5 min. El inicio se reabre constantemente.
//
// No se cachean los métodos de descarga/stream: su resultado depende del
// momento (URLs firmadas que expiran) y deben pedirse frescos siempre.
//
// Se reutiliza el Cache[T] genérico de internal/cache (TTL + limpieza en
// segundo plano) en vez de escribir otra implementación de caché.
//
// Se conecta con: extension_provider_call.go (lectura/escritura) y
// precarga.go (calentado en segundo plano).
// Parte del flujo: metadata de proveedores (búsqueda, detalle, feed).

const (
	ttlCacheDetalle  = 10 * time.Minute
	ttlCacheBusqueda = 2 * time.Minute
	ttlCacheFeed     = 5 * time.Minute
)

var (
	cacheMetadataOnce sync.Once
	cacheDetalle      *cache.Cache[interface{}]
	cacheBusqueda     *cache.Cache[interface{}]
	cacheFeed         *cache.Cache[interface{}]
)

// cachesMetadata inicializa (una vez) los tres buckets de caché.
func cachesMetadata() (*cache.Cache[interface{}], *cache.Cache[interface{}], *cache.Cache[interface{}]) {
	cacheMetadataOnce.Do(func() {
		cacheDetalle = cache.New[interface{}](ttlCacheDetalle, 5*time.Minute)
		cacheBusqueda = cache.New[interface{}](ttlCacheBusqueda, 5*time.Minute)
		cacheFeed = cache.New[interface{}](ttlCacheFeed, 5*time.Minute)
	})
	return cacheDetalle, cacheBusqueda, cacheFeed
}

// bucketCacheMetadata clasifica un método JS: devuelve el bucket al que
// pertenece y si es cacheable. Los métodos fuera de la lista (descargas,
// streams, helpers) nunca se cachean.
func bucketCacheMetadata(method string) (string, bool) {
	switch method {
	case "getTrack", "getAlbum", "getArtist", "getPlaylist":
		return "detalle", true
	case "searchTracks", "searchAlbums", "searchArtists", "searchPlaylists", "customSearch":
		return "busqueda", true
	case "getHomeFeed":
		return "feed", true
	}
	return "", false
}

// claveCacheMetadata construye una clave estable para (extensión, método, args).
// Los mapas de opciones (p. ej. el de customSearch) se serializan con las claves
// ordenadas para que el mismo pedido produzca siempre la misma clave.
func claveCacheMetadata(extID, method string, args []interface{}) string {
	var b strings.Builder
	b.WriteString(extID)
	b.WriteByte('\x00')
	b.WriteString(method)
	for _, a := range args {
		b.WriteByte('\x00')
		b.WriteString(argCacheKey(a))
	}
	return b.String()
}

func argCacheKey(v interface{}) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case map[string]interface{}:
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		var b strings.Builder
		b.WriteByte('{')
		for _, k := range keys {
			b.WriteString(k)
			b.WriteByte('=')
			b.WriteString(argCacheKey(t[k]))
			b.WriteByte(';')
		}
		b.WriteByte('}')
		return b.String()
	case []interface{}:
		var b strings.Builder
		b.WriteByte('[')
		for _, item := range t {
			b.WriteString(argCacheKey(item))
			b.WriteByte(';')
		}
		b.WriteByte(']')
		return b.String()
	default:
		return fmt.Sprint(v)
	}
}

// leerCacheMetadata devuelve una COPIA del valor cacheado. La copia importa:
// el valor original lo comparten todos los consumidores, y cualquiera que lo
// modifique (los converters arman structs a partir de estos mapas) corrompería
// las respuestas siguientes servidas desde caché.
func leerCacheMetadata(kind, key string) (interface{}, bool) {
	if key == "" {
		return nil, false
	}
	detalle, busqueda, feed := cachesMetadata()
	var bucket *cache.Cache[interface{}]
	switch kind {
	case "detalle":
		bucket = detalle
	case "busqueda":
		bucket = busqueda
	case "feed":
		bucket = feed
	default:
		return nil, false
	}
	value, ok := bucket.Get(key)
	if !ok {
		return nil, false
	}
	return copiarValorExportado(value), true
}

// guardarCacheMetadata almacena un resultado exitoso. Nunca se guarda nil: un
// nil puede venir de un proveedor en cooldown y no debe enmascarar su
// recuperación.
func guardarCacheMetadata(kind, key string, value interface{}) {
	if key == "" || value == nil {
		return
	}
	detalle, busqueda, feed := cachesMetadata()
	switch kind {
	case "detalle":
		detalle.Set(key, copiarValorExportado(value))
	case "busqueda":
		busqueda.Set(key, copiarValorExportado(value))
	case "feed":
		feed.Set(key, copiarValorExportado(value))
	}
}

// copiarValorExportado clona recursivamente lo que devuelve goja.Export()
// (mapas y slices anidados) para que la caché no comparta estructuras mutables
// con los consumidores.
func copiarValorExportado(v interface{}) interface{} {
	switch t := v.(type) {
	case map[string]interface{}:
		out := make(map[string]interface{}, len(t))
		for k, item := range t {
			out[k] = copiarValorExportado(item)
		}
		return out
	case []interface{}:
		out := make([]interface{}, len(t))
		for i, item := range t {
			out[i] = copiarValorExportado(item)
		}
		return out
	default:
		// Los escalares (string/number/bool/nil) son inmutables en la práctica.
		return v
	}
}

// LimpiarCacheMetadata vacía los tres buckets. Se expone para los ajustes de la
// app ("vaciar caché de metadata") y para los tests.
func LimpiarCacheMetadata() {
	detalle, busqueda, feed := cachesMetadata()
	detalle.Clear()
	busqueda.Clear()
	feed.Clear()
}

// EstadisticasCacheMetadata reporta cuántas entradas hay por bucket. Sirve para
// el panel de diagnóstico y para verificar en tests que la precarga pobló algo.
func EstadisticasCacheMetadata() map[string]int {
	detalle, busqueda, feed := cachesMetadata()
	return map[string]int{
		"detalle":  detalle.Len(),
		"busqueda": busqueda.Len(),
		"feed":     feed.Len(),
	}
}
