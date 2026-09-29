package premium

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

// servidorRegistro levanta un Worker de mentira que responde el estado indicado
// y anota las llamadas: así se comprueba que la app CONSULTA y que MARCA usado.
func servidorRegistro(t *testing.T, estado string) (*httptest.Server, *[]string, *sync.Mutex) {
	t.Helper()
	var llamadas []string
	var mu sync.Mutex

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		llamadas = append(llamadas, r.URL.Path)
		mu.Unlock()

		w.Header().Set("Content-Type", "application/json")
		switch {
		case r.URL.Path == "/verificar":
			_ = json.NewEncoder(w).Encode(map[string]string{"estado": estado})
		case r.URL.Path == "/usar":
			_ = json.NewEncoder(w).Encode(map[string]string{"ok": "true"})
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	t.Cleanup(srv.Close)
	return srv, &llamadas, &mu
}

func TestRegistroWorkerActivoActivaYMarcausado(t *testing.T) {
	srv, llamadas, mu := servidorRegistro(t, "activo")
	t.Setenv("BITLY_PREMIUM_REGISTRO_URL", srv.URL)

	c := NewChecker(nil)
	if err := c.ValidateAppCode(codigoLegacyDePrueba(t, "pablo", time.Now().Add(time.Hour))); err != nil {
		t.Fatalf("código activo en el registro rechazado: %v", err)
	}
	if !c.IsPremium() {
		t.Fatal("no activó premium")
	}

	mu.Lock()
	defer mu.Unlock()
	tieneVerificar, tieneUsar := false, false
	for _, p := range *llamadas {
		if p == "/verificar" {
			tieneVerificar = true
		}
		if p == "/usar" {
			tieneUsar = true
		}
	}
	if !tieneVerificar || !tieneUsar {
		t.Fatalf("el registro no vio las dos llamadas: %v", *llamadas)
	}
}

func TestRegistroWorkerUsadoBloquea(t *testing.T) {
	srv, _, _ := servidorRegistro(t, "usado")
	t.Setenv("BITLY_PREMIUM_REGISTRO_URL", srv.URL)

	c := NewChecker(nil)
	err := c.ValidateAppCode(codigoLegacyDePrueba(t, "pablo", time.Now().Add(time.Hour)))
	if MotivoDeError(err) != "codigo_usado" {
		t.Fatalf("motivo %q (error: %v)", MotivoDeError(err), err)
	}
	if c.IsPremium() {
		t.Fatal("un código usado no puede activar premium")
	}
}

// El caso que motivó todo esto: el Worker puede no estar activo. Sin registro la
// activación sigue (la firma es local) y el "usado" queda anotado para después.
func TestRegistroWorkerCaidoNoBloqueaYEncola(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("BITLY_PREMIUM_DIR", dir)
	// Puerto cerrado: la conexión se rechaza al instante (sin esperar el timeout).
	t.Setenv("BITLY_PREMIUM_REGISTRO_URL", "http://127.0.0.1:1")

	c := NewChecker(nil)
	code := codigoLegacyDePrueba(t, "pablo", time.Now().Add(time.Hour))
	if err := c.ValidateAppCode(code); err != nil {
		t.Fatalf("con el registro caído igual tiene que activar: %v", err)
	}
	if !c.IsPremium() {
		t.Fatal("no activó premium")
	}
	if n := UsadosPendientesCuenta(); n != 1 {
		t.Fatalf("pendientes = %d (esperado 1)", n)
	}

	// Y cuando el registro vuelve, el reintento lo deja al día.
	srv, llamadas, mu := servidorRegistro(t, "activo")
	t.Setenv("BITLY_PREMIUM_REGISTRO_URL", srv.URL)
	ReintentarUsadosPendientes()

	if n := UsadosPendientesCuenta(); n != 0 {
		t.Fatalf("después del reintento quedaron %d pendientes", n)
	}
	mu.Lock()
	defer mu.Unlock()
	uso := false
	for _, p := range *llamadas {
		if p == "/usar" {
			uso = true
		}
	}
	if !uso {
		t.Fatalf("el reintento no marcó el código: %v", *llamadas)
	}
}

func TestColaPendientesNoDuplica(t *testing.T) {
	t.Setenv("BITLY_PREMIUM_DIR", t.TempDir())

	encolarUsadoPendiente("codigo-uno")
	encolarUsadoPendiente("codigo-uno")
	encolarUsadoPendiente("codigo-dos")
	if n := UsadosPendientesCuenta(); n != 2 {
		t.Fatalf("pendientes = %d (esperado 2: sin duplicados)", n)
	}

	quitarUsadoPendiente("codigo-uno")
	if n := UsadosPendientesCuenta(); n != 1 {
		t.Fatalf("pendientes = %d (esperado 1)", n)
	}

	// El archivo tiene que ser JSON legible (es lo que hace el reintento tras un
	// cierre de la app).
	crudo, err := os.ReadFile(filepath.Join(dirDatosPremium(), archivoUsadosPendientes))
	if err != nil {
		t.Fatalf("no quedó el archivo de pendientes: %v", err)
	}
	var lista []string
	if err := json.Unmarshal(crudo, &lista); err != nil {
		t.Fatalf("el archivo de pendientes no es JSON: %v", err)
	}
}

// La matriz de estados: lo que se acepta y lo que se bloquea, según el formato.
func TestEstadoAError(t *testing.T) {
	casos := []struct {
		estado   string
		firmado  bool
		esperado string // "" = se acepta
	}{
		{"activo", false, ""},
		{"activo", true, ""},
		{"usado", false, "codigo_usado"},
		{"usado", true, "codigo_usado"},
		{"cancelado", false, "codigo_cancelado"},
		{"libre", false, "codigo_liberado"},
		{"no_encontrado", false, "codigo_no_encontrado"},
		{"no_encontrado", true, ""}, // firmado: la firma ya lo prueba
		{"", false, "registro_no_verificado"},
		{"", true, ""},
		{"raro", false, "estado_desconocido"},
	}
	for _, caso := range casos {
		err := estadoAError(caso.estado, caso.firmado)
		if motivo := MotivoDeError(err); motivo != caso.esperado {
			t.Errorf("estado=%q firmado=%v: motivo %q (esperado %q)", caso.estado, caso.firmado, motivo, caso.esperado)
		}
	}
}

// Sin URL configurada el registro no se consulta (como cuando no había token):
// el comportamiento de siempre, sin errores ni llamadas de red.
func TestSinRegistroConfiguradoNoConsulta(t *testing.T) {
	t.Setenv("BITLY_PREMIUM_REGISTRO_URL", "")
	PremiumRegistroURLInyectada = ""
	t.Cleanup(func() { PremiumRegistroURLInyectada = "" })

	c := NewChecker(nil)
	if err := c.ValidateAppCode(codigoLegacyDePrueba(t, "flox", time.Now().Add(time.Hour))); err != nil {
		t.Fatalf("sin registro tiene que validar igual: %v", err)
	}
	if !c.IsPremium() {
		t.Fatal("no activó premium")
	}
}
