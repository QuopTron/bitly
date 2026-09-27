package gobackend

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// providerByName finds a provider by name (case-insensitive).
func providerPorNombre(name string) provider.Provider {
	if reg == nil {
		return nil
	}
	if p := reg.Get(name); p != nil {
		return p
	}
	for _, n := range reg.Names() {
		if strings.EqualFold(n, name) {
			return reg.Get(n)
		}
	}
	return nil
}

// stringDetalle delega en el normalizador compartido del paquete provider: así
// el detalle lee `artists`/`album` en string, arreglo u objeto igual que la
// búsqueda y el feed, en vez de perder el dato cuando la extensión manda un
// arreglo.
func stringDetalle(m map[string]interface{}, keys ...string) string {
	return provider.TextoDeCampo(m, keys...)
}

// detailInt reads the first non-zero int from a list of keys (normalizador
// compartido: acepta número o string numérico).
func intDetalle(m map[string]interface{}, keys ...string) int {
	return provider.EnteroDeCampo(m, keys...)
}

// detailCover resolves a cover URL from the common key shapes (normalizador
// compartido: string, objeto {url} o arreglo de imágenes).
func portadaDetalle(m map[string]interface{}) string {
	return provider.PortadaDeCampo(m)
}
