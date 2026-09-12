package extensions

import (
	"time"

	"github.com/dop251/goja"
)

// jsCallback envuelve una función JS opcional (por ejemplo el `onProgress` de
// file.downloadSegments) para invocarla desde Go de forma segura.
//
// Clave de seguridad: goja NO es thread-safe. Las operaciones que paralelizan
// trabajo en Go (descarga de segmentos) deben recoger sus resultados en la
// goroutine que tiene el lock del VM y llamar al callback SOLO desde ahí. Este
// helper existe para que ese contrato sea explícito.
//
// Se conecta con: file_segments.go y file_transform.go.
// Parte del flujo: APIs del sandbox de extensiones (reporte de progreso).
type jsCallback struct {
	vm            *goja.Runtime
	fn            goja.Callable
	lastMs        int64
	minIntervalMs int64
}

// newJSCallback envuelve [value] si es una función; si no lo es, el callback
// queda inerte y todas las llamadas se vuelven no-ops (las extensiones pasan
// `onProgress` opcional).
func newJSCallback(vm *goja.Runtime, value goja.Value, minIntervalMs int64) *jsCallback {
	cb := &jsCallback{vm: vm, minIntervalMs: minIntervalMs}
	if vm == nil || value == nil || goja.IsUndefined(value) || goja.IsNull(value) {
		return cb
	}
	fn, ok := goja.AssertFunction(value)
	if !ok {
		return cb
	}
	cb.fn = fn
	return cb
}

// call invoca el callback con rate-limit (evita inundar el VM con un evento por
// byte leído). Un callback ausente o que lance no rompe la operación: el
// progreso es informativo.
func (c *jsCallback) call(args ...interface{}) {
	if c == nil || c.fn == nil || c.vm == nil {
		return
	}
	now := time.Now().UnixMilli()
	if now-c.lastMs < c.minIntervalMs {
		return
	}
	c.lastMs = now
	c.invoke(args...)
}

// callFinal invoca el callback sin rate-limit, para el evento de cierre (100%).
func (c *jsCallback) callFinal(args ...interface{}) {
	if c == nil || c.fn == nil || c.vm == nil {
		return
	}
	c.invoke(args...)
}

func (c *jsCallback) invoke(args ...interface{}) {
	values := make([]goja.Value, len(args))
	for i, a := range args {
		values[i] = c.vm.ToValue(a)
	}
	// Un callback que lance (por ejemplo una cancelación de la UI) no debe
	// tumbar la descarga o el descifrado a mitad de camino.
	_, _ = c.fn(goja.Undefined(), values...)
}
