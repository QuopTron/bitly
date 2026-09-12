package provider

import (
	"strings"
	"sync"
	"time"
)

// Precarga de metadata: adelantar el trabajo de red antes de que el usuario lo
// pida, para que abrir un resultado se sienta instantáneo.
//
// Estrategia: cuando una búsqueda termina, se calienta el DETALLE de los
// primeros resultados en segundo plano. Así, cuando el usuario toca uno, el
// getTrack/getAlbum ya está en la caché y no hay espera.
//
// Reglas de convivencia con las llamadas del usuario (el sandbox serializa, así
// que una precarga mal hecha retrasaría lo que el usuario sí está mirando):
//   - máximo pocos items por búsqueda (maxPrecargaPorBusqueda);
//   - un solo calentamiento por proveedor a la vez (una nueva búsqueda no
//     encola otro mientras el anterior corre);
//   - pausa inicial corta para que la primera interacción del usuario gane;
//   - secuencial, nunca en paralelo;
//   - jamás propaga errores ni bloquea: es especulativo.
//
// Se conecta con: metadata_cache.go y extension_provider_call.go.
// Parte del flujo: metadata de proveedores (precarga tras buscar).

const (
	maxPrecargaPorBusqueda = 3
	pausaAntesDePrecargar  = 400 * time.Millisecond
)

var (
	precargaMu       sync.Mutex
	precargaActiva   = map[string]bool{}
	precargaArranque = map[string]time.Time{}
	precargaMinGap   = 15 * time.Second
)

// precargarDetalleEnSegundoPlano calienta el detalle de [ids] (los primeros
// [max]) sin bloquear al llamador. Solo se calienta el id que todavía no está
// en caché, y se omite si el proveedor ya tiene un calentamiento en curso o si
// se calentó hace muy poco (evita ráfagas al teclear en el buscador).
func (p *ExtensionProvider) precargarDetalleEnSegundoPlano(method string, ids []string, max int) {
	if len(ids) == 0 || max <= 0 {
		return
	}
	if _, cacheable := bucketCacheMetadata(method); !cacheable {
		return
	}

	// Filtra ids vacíos/duplicados y recorta antes de tocar el lock global.
	vistos := map[string]bool{}
	pendientes := make([]string, 0, max)
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" || vistos[id] {
			continue
		}
		vistos[id] = true
		pendientes = append(pendientes, id)
		if len(pendientes) >= max {
			break
		}
	}
	if len(pendientes) == 0 {
		return
	}

	precargaMu.Lock()
	if precargaActiva[p.name] {
		precargaMu.Unlock()
		return
	}
	if last, ok := precargaArranque[p.name]; ok && time.Since(last) < precargaMinGap {
		precargaMu.Unlock()
		return
	}
	precargaActiva[p.name] = true
	precargaArranque[p.name] = time.Now()
	precargaMu.Unlock()

	go func() {
		defer func() {
			precargaMu.Lock()
			precargaActiva[p.name] = false
			precargaMu.Unlock()
		}()
		// Deja pasar la primera interacción del usuario antes de competir por
		// el sandbox (que serializa las llamadas JS).
		time.Sleep(pausaAntesDePrecargar)
		for _, id := range pendientes {
			// Si ya está en caché, otro camino lo trajo: no repetir la llamada.
			key := claveCacheMetadata(p.extID, method, []interface{}{id})
			if _, ok := leerCacheMetadata("detalle", key); ok {
				continue
			}
			// El resultado se descarta: lo importante es que quede cacheado.
			_, _ = p.callOp("detail", method, id)
		}
	}()
}

// PrecargarDetalle calienta de forma explícita la caché de detalle del
// proveedor [name] para los [ids] indicados, con una llamada al método JS
// [method] (por defecto "getTrack"). Devuelve cuántos ids se encolaron.
//
// La usa la app para adelantar lo que el usuario está por abrir (por ejemplo,
// los items visibles de una lista) sin esperar a que toque uno.
func (r *Registry) PrecargarDetalle(name, method string, ids []string) int {
	if r == nil {
		return 0
	}
	prov := r.Get(name)
	if prov == nil {
		return 0
	}
	ep, ok := prov.(*ExtensionProvider)
	if !ok {
		return 0
	}
	if method == "" {
		method = "getTrack"
	}
	if _, cacheable := bucketCacheMetadata(method); !cacheable {
		return 0
	}
	ep.precargarDetalleEnSegundoPlano(method, ids, maxPrecargaPorBusqueda)
	return len(ids)
}
