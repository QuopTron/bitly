// sessionpool_test.go — Pruebas del pool de credenciales.
//
// Cubre lo que puede fallar en producción:
//   - el parseo de ARLs en HTML/markdown/JSON/texto,
//   - que una credencial muerta NO llegue al usuario (se descarta),
//   - que una fuente caída no tumbe el pool entero,
//   - que la credencial propia del usuario SIEMPRE vaya primero.
//
// Se conecta con: pool.go y deezer.go.
// Parte del flujo: red de seguridad del pool de sesiones.
package sessionpool

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
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
