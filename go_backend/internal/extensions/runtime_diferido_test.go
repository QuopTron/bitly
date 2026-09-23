// Tests del arranque diferido: registrar una extensión ya no compila su JS.
//
// El contrato que fijan:
//
//  1. Registrarla no la compila (que es lo que devolvía al arranque el costo
//     de las nueve extensiones empaquetadas).
//  2. El primer uso la compila, sin que el llamador sepa que había algo
//     diferido.
//  3. Los ajustes que llegan ANTES de la compilación se aplican igual, en el
//     mismo orden que si initialize() se hubiera llamado al arrancar. Sin esto
//     el ahorro se pagaría con credenciales perdidas.
//  4. Una extensión que no compila falla una sola vez, con su error.
package extensions

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

// fuenteDemo usa GLOBAL_SETTINGS para poder comprobar DESDE EL TEST que
// initialize() corrió antes de la primera llamada real.
const fuenteDemo = `
var GLOBAL_SETTINGS = null;
function initialize(settings) { GLOBAL_SETTINGS = settings; }
function eco(clave) { return GLOBAL_SETTINGS ? GLOBAL_SETTINGS[clave] : "sin-initialize"; }
function buscar(q, n) { return [q, n]; }
`

func registrarDemo(t *testing.T, rt *Runtime, extID, fuente string) *Sandbox {
	t.Helper()
	cfg := DefaultConfig()
	sb := rt.RegisterDeferred(fuente, extID, extID, cfg, t.TempDir())
	if sb == nil {
		t.Fatalf("RegisterDeferred(%s) devolvió nil", extID)
	}
	return sb
}

// El registro no debe compilar nada: es el corazón del ahorro del arranque.
func TestRegistrarDiferidoNoCompila(t *testing.T) {
	rt := NewRuntime()
	sb := registrarDemo(t, rt, "demo", fuenteDemo)

	if sb.IsLoaded() {
		t.Error("el sandbox quedó compilado al registrarlo")
	}
	if !rt.IsDeferred("demo") {
		t.Error("la extensión debería figurar como diferida")
	}
	if rt.Count() != 1 {
		t.Errorf("Count() = %d, se esperaba 1: una diferida ya está registrada", rt.Count())
	}
	// El sandbox existe igual: config, storage y sesión firmada están listos
	// desde el registro, que es lo que necesitan las comprobaciones de arranque.
	if rt.Sandbox("demo") == nil {
		t.Error("Sandbox() debe devolver el sandbox aunque no esté compilado")
	}
}

// El primer uso compila y la llamada funciona como si nunca hubiera estado
// diferida.
func TestPrimerUsoCompila(t *testing.T) {
	rt := NewRuntime()
	registrarDemo(t, rt, "demo", fuenteDemo)

	res, err := rt.CallMethod("demo", "buscar", "queen", 3)
	if err != nil {
		t.Fatalf("CallMethod compilando bajo demanda: %v", err)
	}
	lista, ok := res.([]interface{})
	if !ok || len(lista) != 2 || lista[0] != "queen" {
		t.Fatalf("resultado inesperado: %#v", res)
	}
	if rt.IsDeferred("demo") {
		t.Error("después del primer uso ya no debería figurar como diferida")
	}
	if !rt.Sandbox("demo").IsLoaded() {
		t.Error("el sandbox debería quedar compilado")
	}
}

// HasMethod también compila: es la única forma de saber si exporta el método, y
// es lo que usan las acciones a pedido del usuario.
func TestHasMethodCompila(t *testing.T) {
	rt := NewRuntime()
	registrarDemo(t, rt, "demo", fuenteDemo)

	if !rt.HasMethod("demo", "buscar") {
		t.Error("HasMethod(buscar) debería ser true")
	}
	if rt.HasMethod("demo", "noExiste") {
		t.Error("HasMethod(noExiste) debería ser false")
	}
}

// Lo que hace que el ahorro no cueste credenciales: un push que llega antes de
// la compilación se aplica en cuanto la extensión se compila.
func TestAjustesEncoladosSeAplicanAlCompilar(t *testing.T) {
	rt := NewRuntime()
	sb := registrarDemo(t, rt, "demo", fuenteDemo)

	// Todavía sin compilar: QueueSettings debe encolarlos (false = encolado).
	if sb.QueueSettings(map[string]string{"token": "abc"}) {
		t.Fatal("QueueSettings devolvió true para una extensión sin compilar")
	}
	if rt.Sandbox("demo").IsLoaded() {
		t.Fatal("encolar ajustes no debe compilar la extensión")
	}

	// Primera llamada real: initialize() con lo encolado tiene que haber corrido
	// ANTES, o el eco devolvería "sin-initialize".
	res, err := rt.CallMethod("demo", "eco", "token")
	if err != nil {
		t.Fatalf("CallMethod: %v", err)
	}
	if res != "abc" {
		t.Fatalf("eco(token) = %#v, se esperaba \"abc\": los ajustes encolados no se aplicaron al compilar", res)
	}
	if rt.IsDeferred("demo") {
		t.Error("la extensión debería quedar compilada")
	}
}

// Una vez compilada, QueueSettings avisa que el llamador debe aplicar
// initialize() directo (ya no hay compilación posterior que drene la cola).
func TestQueueSettingsTrasCompilarPideAplicarDirecto(t *testing.T) {
	rt := NewRuntime()
	sb := registrarDemo(t, rt, "demo", fuenteDemo)

	if _, err := rt.CallMethod("demo", "buscar", "x", 1); err != nil {
		t.Fatalf("CallMethod: %v", err)
	}
	if !sb.QueueSettings(map[string]string{"token": "zzz"}) {
		t.Fatal("QueueSettings debería devolver true con la extensión ya compilada")
	}
}

// Ocho goroutines pidiendo la misma extensión a la vez: una sola compilación y
// ninguna llamada perdida (con -race esto además prueba que no hay carrera).
func TestPrimerUsoConcurrente(t *testing.T) {
	rt := NewRuntime()
	registrarDemo(t, rt, "demo", fuenteDemo)

	const n = 8
	var wg sync.WaitGroup
	errs := make([]error, n)
	vals := make([]interface{}, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			vals[i], errs[i] = rt.CallMethod("demo", "eco", "token")
		}(i)
	}
	wg.Wait()

	for i := 0; i < n; i++ {
		if errs[i] != nil {
			t.Fatalf("goroutine %d: %v", i, errs[i])
		}
		if vals[i] != "sin-initialize" {
			t.Fatalf("goroutine %d: %#v", i, vals[i])
		}
	}
	if rt.IsDeferred("demo") {
		t.Error("debería quedar compilada")
	}
}

// Un JS que no compila falla con su error y NO se reintenta en cada llamada: la
// VM a medio armar no debe quedar publicada como si estuviera lista.
func TestFuenteRotaFallaUnaVezYNoQuedaCargada(t *testing.T) {
	rt := NewRuntime()
	registrarDemo(t, rt, "rota", "function ( { esto no es JS")

	err1 := rt.EnsureLoaded("rota")
	if err1 == nil {
		t.Fatal("compilar un JS inválido debería devolver error")
	}
	if rt.Sandbox("rota").IsLoaded() {
		t.Error("una extensión que no compiló no puede quedar marcada como cargada")
	}
	if err2 := rt.EnsureLoaded("rota"); err2 == nil || err2.Error() != err1.Error() {
		t.Errorf("el error debería ser estable entre llamadas: %v vs %v", err1, err2)
	}
	if _, err := rt.CallMethod("rota", "buscar"); err == nil {
		t.Error("CallMethod sobre una extensión rota debería fallar")
	}
}

// El sandbox existe desde el registro, así que el manifest puede colgarle el
// SignedSession antes de compilar y el listado sigue viéndolo. Si esto se
// rompiera, el keepalive de Cloudflare dejaría de encontrar sus extensiones al
// arrancar (que es justo cuando corre).
func TestSesionFirmadaVisibleAntesDeCompilar(t *testing.T) {
	rt := NewRuntime()
	sb := registrarDemo(t, rt, "firmada", fuenteDemo)
	sb.SignedSession = &SignedSessionConfig{Namespace: "demo", BaseURL: "https://demo"}
	sb.Session = &SignedSessionState{}

	if rt.Sandbox("firmada").IsLoaded() {
		t.Fatal("colgarle la sesión firmada no debería compilarla")
	}
	ids := rt.SignedSessionSandboxIDs()
	if len(ids) != 1 || ids[0] != "firmada" {
		t.Fatalf("SignedSessionSandboxIDs() = %v, se esperaba [firmada] sin compilar", ids)
	}
}

// Close vacía también las diferidas: no debe quedar nada pendiente de compilar.
func TestCloseDescartaDiferidas(t *testing.T) {
	rt := NewRuntime()
	registrarDemo(t, rt, "demo", fuenteDemo)

	rt.Close()

	if rt.Count() != 0 {
		t.Errorf("Count() tras Close = %d, se esperaba 0", rt.Count())
	}
	if rt.IsDeferred("demo") {
		t.Error("Close debe descartar las diferidas")
	}
	if err := rt.EnsureLoaded("demo"); err != nil {
		t.Errorf("EnsureLoaded tras Close no debería fallar: %v", err)
	}
	if rt.Sandbox("demo") != nil {
		t.Error("el sandbox no debería seguir registrado tras Close")
	}
}

// RunJS (extensiones instaladas en disco) compila de inmediato y queda marcada
// como cargada: si IsLoaded() mintiera, el push de ajustes la creería diferida,
// encolaría las credenciales y nadie las drenaría nunca.
func TestRunJSQuedaCargada(t *testing.T) {
	rt := NewRuntime()
	if _, err := rt.RunJS(fuenteDemo, "disco", "disco", DefaultConfig(), t.TempDir()); err != nil {
		t.Fatalf("RunJS: %v", err)
	}

	sb := rt.Sandbox("disco")
	if !sb.IsLoaded() {
		t.Fatal("RunJS debería dejar el sandbox marcado como cargado")
	}
	if sb.QueueSettings(map[string]string{"token": "t"}) != true {
		t.Fatal("QueueSettings debería pedir aplicar directo (true) en un sandbox ya cargado")
	}
}

// El bucle de drenaje no puede quedarse girando: con ajustes que llegan durante
// la compilación se aplica el último y se corta.
func TestAjustesQueLleganDuranteLaCompilacion(t *testing.T) {
	rt := NewRuntime()
	sb := registrarDemo(t, rt, "demo", fuenteDemo)
	sb.QueueSettings(map[string]string{"token": "primero"})

	// Simula un push que entra justo mientras se compila: se aplica como último,
	// después del encolado original.
	hecho := make(chan struct{})
	go func() {
		defer close(hecho)
		rt.EnsureLoaded("demo")
	}()
	time.Sleep(10 * time.Millisecond)
	sb.QueueSettings(map[string]string{"token": "segundo"})
	<-hecho

	res, err := rt.CallMethod("demo", "eco", "token")
	if err != nil {
		t.Fatalf("CallMethod: %v", err)
	}
	if res != "segundo" && res != "primero" {
		t.Fatalf("eco(token) = %#v, se esperaba alguno de los ajustes aplicados", res)
	}
	if fmt.Sprint(res) == "sin-initialize" {
		t.Fatal("algún ajuste tenía que quedar aplicado")
	}
}
