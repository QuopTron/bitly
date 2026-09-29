// sessionpool_test.go — Pruebas del pool de credenciales.
//
// Cubre lo que puede fallar en producción:
//   - el parseo de ARLs en HTML/markdown/JSON/texto,
//   - que una credencial muerta NO llegue al usuario (se descarta),
//   - que una fuente caída no tumbe el pool entero,
//   - que la credencial propia del usuario SIEMPRE vaya primero,
//   - que la validación sea en PARALELO, acotada y con el orden intacto
//     (con una fuente de decenas de ARLs, en serie el guardado de ajustes
//     quedaba esperando minutos).
//
// Todo corre contra servidores httptest locales: ninguna prueba sale a la red
// ni necesita credenciales reales.
//
// Se conecta con: pool.go y deezer.go.
// Parte del flujo: red de seguridad del pool de sesiones.
package sessionpool

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

const arlValido = "0123456789abcdef0123456789abcdef"
const arlMuerto = "fedcba9876543210fedcba9876543210"

// gatewayFalso responde como el gateway de Deezer: solo los ARLs de
// [vivos] devuelven USER_ID.
func gatewayFalso(t *testing.T, vivos map[string]bool) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		arl := ""
		if c, err := r.Cookie("arl"); err == nil {
			arl = c.Value
		}
		if !vivos[arl] {
			// Sesión inválida: el gateway responde sin USER.
			_, _ = w.Write([]byte(`{"results":{"USER":{"USER_ID":"0"}}}`))
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"results": map[string]any{"USER": map[string]any{"USER_ID": "12345"}},
		})
	}))
}

func TestExtraerARLsDeCualquierFormato(t *testing.T) {
	casos := map[string]string{
		"texto plano": arlValido + "\notro texto",
		"markdown":    "| Pais | ARL |\n|---|---|\n| BR | `" + arlValido + "` |",
		"html":        "<td>" + arlValido + "</td>",
		"json":        `{"arl":"` + arlValido + `"}`,
	}
	for nombre, cuerpo := range casos {
		if got := ExtraerARLs(cuerpo); len(got) != 1 || got[0] != arlValido {
			t.Errorf("%s: esperaba el ARL, obtuve %v", nombre, got)
		}
	}
	if got := ExtraerARLs("sin credenciales aqui"); len(got) != 0 {
		t.Errorf("no debía extraer nada: %v", got)
	}
}

func TestCredencialMuertaNoLlegaAlUsuario(t *testing.T) {
	gateway := gatewayFalso(t, map[string]bool{arlValido: true})
	defer gateway.Close()

	fuente := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// La fuente mezcla un ARL bueno con uno baneado.
		_, _ = w.Write([]byte("bueno=" + arlValido + "\nmuerto=" + arlMuerto))
	}))
	defer fuente.Close()

	res := ConstruirPoolARP(nil, nil, []string{fuente.URL}, gateway.URL)
	if len(res.Usables) != 1 || res.Usables[0] != arlValido {
		t.Fatalf("el pool debía quedarse solo con el ARL vivo: %+v", res)
	}
	if res.Descartadas != 1 {
		t.Errorf("debía descartar 1, descartó %d", res.Descartadas)
	}
}

func TestFuenteCaidaNoTumbaElPool(t *testing.T) {
	gateway := gatewayFalso(t, map[string]bool{arlValido: true})
	defer gateway.Close()

	caida := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer caida.Close()

	viva := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(arlValido))
	}))
	defer viva.Close()

	res := ConstruirPoolARP(nil, nil, []string{caida.URL, viva.URL}, gateway.URL)
	if len(res.FuentesCaidas) != 1 {
		t.Errorf("debía reportar 1 fuente caída: %+v", res)
	}
	if len(res.Usables) != 1 {
		t.Errorf("la fuente viva debía aportar el ARL: %+v", res)
	}
}

func TestCredencialPropiaVaPrimero(t *testing.T) {
	// Gateway caído a propósito: las credenciales propias deben pasar
	// igual (no queremos romperle la app al usuario si el gateway falla).
	gateway := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer gateway.Close()

	fuente := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(arlValido))
	}))
	defer fuente.Close()

	res := ConstruirPoolARP(nil, []string{arlMuerto}, []string{fuente.URL}, gateway.URL)
	if len(res.Usables) == 0 || res.Usables[0] != arlMuerto {
		t.Fatalf("la credencial propia debía ir primera: %+v", res)
	}
}

func TestSepararCredencialesPegadasAMano(t *testing.T) {
	got := SepararCredenciales(arlValido + ", " + arlMuerto + "\n" + arlValido)
	if len(got) != 2 {
		t.Fatalf("esperaba 2 únicos, obtuve %v", got)
	}
	if got[0] != arlValido {
		t.Errorf("el orden no se respetó: %v", got)
	}
	// Basura corta no debe colarse como credencial.
	if len(SepararCredenciales("hola, si")) != 0 {
		t.Error("no debía aceptar texto corto como credencial")
	}
}

// arl sintético y único por posición (32 hex, como un ARL de verdad).
func arlFalso(i int) string { return fmt.Sprintf("%032x", i) }

// gatewayConDemora responde "sesión viva" a todo y cuenta cuántas
// validaciones atiende a la vez, para poder afirmar que son en paralelo.
func gatewayConDemora(demora time.Duration, enCurso, maxEnCurso *int32) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ahora := atomic.AddInt32(enCurso, 1)
		for {
			previo := atomic.LoadInt32(maxEnCurso)
			if ahora <= previo || atomic.CompareAndSwapInt32(maxEnCurso, previo, ahora) {
				break
			}
		}
		time.Sleep(demora)
		atomic.AddInt32(enCurso, -1)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"results": map[string]any{"USER": map[string]any{"USER_ID": "42"}},
		})
	}))
}

// fuenteDeARLs sirve un ARL por línea (lo que pega el usuario en la fuente).
func fuenteDeARLs(valores []string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var cuerpo strings.Builder
		for _, v := range valores {
			fmt.Fprintf(&cuerpo, "arl=%s\n", v)
		}
		_, _ = w.Write([]byte(cuerpo.String()))
	}))
}

func TestPoolValidaEnParalelo(t *testing.T) {
	const credenciales = 12
	const demora = 200 * time.Millisecond

	var enCurso, maxEnCurso int32
	gateway := gatewayConDemora(demora, &enCurso, &maxEnCurso)
	defer gateway.Close()

	valores := make([]string, 0, credenciales)
	for i := 0; i < credenciales; i++ {
		valores = append(valores, arlFalso(i))
	}
	fuente := fuenteDeARLs(valores)
	defer fuente.Close()

	inicio := time.Now()
	res := ConstruirPoolARP(nil, nil, []string{fuente.URL}, gateway.URL)
	transcurrido := time.Since(inicio)

	if len(res.Usables) != credenciales {
		t.Fatalf("esperaba %d ARLs vivos, obtuve %+v", credenciales, res)
	}
	if len(res.FuentesCaidas) != 0 || res.Descartadas != 0 {
		t.Errorf("no debía descartar nada: %+v", res)
	}
	if max := atomic.LoadInt32(&maxEnCurso); max < 2 {
		t.Errorf("las validaciones fueron en serie (máximo %d a la vez)", max)
	}
	// En serie esto serían 12 × 200 ms. El margen es amplio para no
	// depender de la carga de la máquina que corre las pruebas.
	if serie := credenciales * demora; transcurrido >= serie/2 {
		t.Errorf("tardó %v; validando de a una serían %v", transcurrido, serie)
	}
}

func TestPoolAcotaLasValidaciones(t *testing.T) {
	const total = maxValidaciones * 2

	var validadas int32
	gateway := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&validadas, 1)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"results": map[string]any{"USER": map[string]any{"USER_ID": "42"}},
		})
	}))
	defer gateway.Close()

	valores := make([]string, 0, total)
	for i := 0; i < total; i++ {
		valores = append(valores, arlFalso(i))
	}
	fuente := fuenteDeARLs(valores)
	defer fuente.Close()

	res := ConstruirPoolARP(nil, nil, []string{fuente.URL}, gateway.URL)

	if got := atomic.LoadInt32(&validadas); got > maxValidaciones {
		t.Errorf("validó %d credenciales; el tope es %d", got, maxValidaciones)
	}
	if res.Omitidas != total-maxValidaciones {
		t.Errorf("omitidas = %d, se esperaban %d", res.Omitidas, total-maxValidaciones)
	}
	if len(res.Usables)+res.Descartadas+res.Omitidas != total {
		t.Errorf("se perdió una candidata en el camino: %+v", res)
	}
}

func TestPoolNoValidaDosVecesLaMismaCredencial(t *testing.T) {
	var validadas int32
	gateway := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&validadas, 1)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"results": map[string]any{"USER": map[string]any{"USER_ID": "42"}},
		})
	}))
	defer gateway.Close()

	// La misma credencial tres veces (con distinta forma: suelta y en
	// "clave=valor", como aparece en una tabla pegada de la web).
	fuente := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "%s\narl=%s\n\n%s", arlValido, arlValido, arlValido)
	}))
	defer fuente.Close()

	res := ConstruirPoolARP(nil, nil, []string{fuente.URL}, gateway.URL)
	if got := atomic.LoadInt32(&validadas); got != 1 {
		t.Errorf("validó %d veces la misma credencial; debía ser 1", got)
	}
	if len(res.Usables) != 1 {
		t.Errorf("esperaba 1 usable, obtuve %+v", res)
	}
}

func TestPoolConservaElOrdenAunqueTerminenDesordenadas(t *testing.T) {
	// La PRIMERA credencial es la lenta (y la muerta): si el resultado se
	// armara según quién termina primero, el orden cambiaría.
	lenta := arlFalso(1)
	viva1 := arlFalso(2)
	viva2 := arlFalso(3)

	gateway := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, _ := r.Cookie("arl")
		if c != nil && c.Value == lenta {
			time.Sleep(150 * time.Millisecond)
			_, _ = w.Write([]byte(`{"results":{"USER":{"USER_ID":"0"}}}`))
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"results": map[string]any{"USER": map[string]any{"USER_ID": "42"}},
		})
	}))
	defer gateway.Close()

	fuente := fuenteDeARLs([]string{lenta, viva1, viva2})
	defer fuente.Close()

	res := ConstruirPoolARP(nil, nil, []string{fuente.URL}, gateway.URL)
	if len(res.Usables) != 2 || res.Usables[0] != viva1 || res.Usables[1] != viva2 {
		t.Fatalf("el orden de la fuente no se respetó: %+v", res)
	}
	if res.Descartadas != 1 {
		t.Errorf("descartadas = %d, se esperaba 1", res.Descartadas)
	}
}
