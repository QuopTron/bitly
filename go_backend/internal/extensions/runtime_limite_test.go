// Fija el freno de tiempo de las llamadas a extensiones.
//
// Por qué existe: goja no tiene tope de memoria y hasta ahora el interrupt se
// LIMPIABA pero nunca se armaba, así que un bucle sin fin en una extensión
// dejaba esa extensión viva para siempre —asignando mientras Android no mataba
// la app— y bloqueaba a todos los llamadores siguientes. El contrato que fija
// esta prueba:
//
//  1. Un método que no termina se corta por el límite y el llamador recibe el
//     motivo, no un cuelgue.
//  2. La VM queda USABLE después: el interrupt se limpia al volver, así que la
//     siguiente llamada a esa extensión funciona (sin el ClearInterrupt del
//     defer, fallaría sola).

package extensions

import (
	"strings"
	"testing"
	"time"
)

// fuenteColgada tiene un método que no termina nunca y otro normal, para poder
// comprobar que el sandbox sobrevive al corte.
const fuenteColgada = `
function bucle() { while (true) {} }
function eco() { return "ok"; }
`

func TestUnaLlamadaColgadaSeCortaYLaVMQuedaUsable(t *testing.T) {
	rt := NewRuntime()
	registrarDemo(t, rt, "colgada", fuenteColgada)

	// El límite real son 60 s: el test lo acorta para no esperarlos.
	original := limiteLlamadaJS
	limiteLlamadaJS = 200 * time.Millisecond
	defer func() { limiteLlamadaJS = original }()

	inicio := time.Now()
	_, err := rt.CallMethod("colgada", "bucle")
	if err == nil {
		t.Fatal("un bucle sin fin debe cortarse por el límite de ejecución")
	}
	if !strings.Contains(err.Error(), motivoLlamadaJSAgotada) {
		t.Fatalf("el error debe decir por qué se cortó: %v", err)
	}
	// Margen generoso: lo que se prueba es que TERMINA, no cuánto tarda.
	if transcurrido := time.Since(inicio); transcurrido > 10*time.Second {
		t.Fatalf("el corte tardó %v; debería ser casi inmediato tras el límite", transcurrido)
	}
	if !rt.Sandbox("colgada").IsLoaded() {
		t.Fatal("el sandbox debe seguir cargado después del corte")
	}

	// Y la extensión sigue sirviendo: el interrupt no puede quedar pegado.
	res, err := rt.CallMethod("colgada", "eco")
	if err != nil {
		t.Fatalf("la llamada siguiente debe funcionar: %v", err)
	}
	if res != "ok" {
		t.Fatalf("eco() devolvió %v, se esperaba \"ok\"", res)
	}
}
