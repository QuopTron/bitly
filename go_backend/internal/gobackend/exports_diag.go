package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// =========================================================================
// DIAGNÓSTICO DE RED
// =========================================================================

// RedEstado devuelve el snapshot del conteo de peticiones HTTP salientes
// (total, por host, por método) como JSON.
//
// Para qué sirve: medir el COSTE en idas a la red de una operación real —
// un toque de stream o una descarga— antes y después de las optimizaciones.
// El patrón es reiniciar → hacer UNA operación → leer, y así el total que se
// ve es exactamente lo que costó esa operación.
//
// No expone nada sensible: solo host, método y número de peticiones.
func RedEstado() string {
	d, _ := json.Marshal(httpclient.EstadoConteo())
	return string(d)
}

// RedReiniciar deja el acumulado en cero y devuelve el snapshot nuevo (JSON
// con total 0), para que el llamador pueda hacer reiniciar-y-leer en una sola
// petición.
func RedReiniciar() string {
	httpclient.ReiniciarConteo()
	return RedEstado()
}
