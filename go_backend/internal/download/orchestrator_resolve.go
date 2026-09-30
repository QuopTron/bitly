package download

import (
	"sync"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Per-provider track resolution cache. Key = provider name + a stable identity
// (ISRC, cross-provider ids, or title|artist). This makes the often-slow
// resolve step (amazon showSearch / name searches) run only once per track
// instead of once per provider / repeated play — a general speedup that applies
// to every source.
//
// Un ÚNICO candado cubre la caché Y los vuelos en curso: si fueran dos, un
// segundo pedido podía mirar la caché ANTES de que el líder la escribiera y el
// mapa de vuelos DESPUÉS de que el líder lo limpiara, y pagaba una segunda
// resolución idéntica — justo el caso que el single-flight existe para evitar.
var (
	resCacheMu    sync.Mutex
	resCache      = map[string]map[string][3]string{}
	resCacheOrder []struct{ provider, key string }
	resVuelo      = map[string]*vueloResolucion{}
)

const resCacheMaxKeys = 4000

// vueloResolucion colapsa resoluciones idénticas que corren a la vez. Ocurre
// de verdad: el proveedor preferido aparece dos veces en providersToTry, el
// feeder resuelve mientras las goroutines de warm todavía corren, y
// enrich/mejora/visualizer vuelven a pedir la misma clave por fuera. La caché
// normal solo evitaba el trabajo YA concluido; dos llegadas simultáneas
// pagaban el doble (búsqueda por nombre de amazon incluida).
type vueloResolucion struct {
	done              chan struct{}
	id, title, artist string
}

// cachedResolve returns the cached resolution (trackID, title, artist) when
// available; otherwise resolves via resolveProviderTrackID and caches the
// result. Empty [key] disables caching (nothing stable to key on).
func resolucionCacheada(p provider.Provider, name, key string, req Request) (string, string, string) {
	if key == "" {
		// Sin identidad estable no hay caché ni dedupe: cada llamada puede
		// estar preguntando por una entidad distinta.
		return resolverTrackIDProvider(p, name, req)
	}
	clave := name + "\x00" + key

	// Mirada y registro bajo el MISMO candado (ver comentario de resCacheMu).
	// El líder escribe la caché y limpia su vuelo en la MISMA sección crítica
	// (guardarResCache + el defer de abajo), así que quien no vea vuelo verá
	// caché.
	resCacheMu.Lock()
	if m, ok := resCache[name]; ok {
		if r, okCache := m[key]; okCache {
			resCacheMu.Unlock()
			return r[0], r[1], r[2]
		}
	}
	if v, ok := resVuelo[clave]; ok {
		resCacheMu.Unlock()
		<-v.done
		return v.id, v.title, v.artist
	}
	v := &vueloResolucion{done: make(chan struct{})}
	resVuelo[clave] = v
	resCacheMu.Unlock()

	// El publicador va en defer: un pánico dentro de un proveedor no puede
	// dejar a los esperando colgados para siempre en un canal nunca cerrado.
	defer func() {
		resCacheMu.Lock()
		delete(resVuelo, clave)
		resCacheMu.Unlock()
		close(v.done)
	}()
	v.id, v.title, v.artist = resolverTrackIDProvider(p, name, req)
	guardarResCache(name, key, v.id, v.title, v.artist)
	return v.id, v.title, v.artist
}

// guardarResCache guarda una resolución exitosa (con identidad, no un fallo)
// con una vida acotada por resCacheMaxKeys.
func guardarResCache(name, key, id, title, artist string) {
	if id == "" {
		return
	}
	resCacheMu.Lock()
	defer resCacheMu.Unlock()
	if len(resCacheOrder) >= resCacheMaxKeys {
		// Drop the oldest entries so the cache stays bounded.
		for len(resCacheOrder) >= resCacheMaxKeys/2 {
			old := resCacheOrder[0]
			resCacheOrder = resCacheOrder[1:]
			if m, ok := resCache[old.provider]; ok {
				delete(m, old.key)
				if len(m) == 0 {
					delete(resCache, old.provider)
				}
			}
		}
	}
	m := resCache[name]
	if m == nil {
		m = map[string][3]string{}
		resCache[name] = m
	}
	if _, exists := m[key]; !exists {
		m[key] = [3]string{id, title, artist}
		resCacheOrder = append(resCacheOrder, struct{ provider, key string }{name, key})
	}
}
