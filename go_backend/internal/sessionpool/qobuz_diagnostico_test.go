package sessionpool

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// servidorPoolQobuz levanta un Qobuz de mentira para el informe del pool: la
// ruta /pool publica [cuerpo] y getUserFavorites valida los tokens de [vivos].
func servidorPoolQobuz(t *testing.T, cuerpo string, vivos map[string]bool) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.HasSuffix(r.URL.Path, "/pool"):
			_, _ = w.Write([]byte(cuerpo))
		case strings.Contains(r.URL.Path, "getUserFavorites"):
			if vivos[r.URL.Query().Get("user_auth_token")] {
				_, _ = w.Write([]byte(`{}`))
				return
			}
			w.WriteHeader(http.StatusUnauthorized)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

// TestDiagnosticoPoolSinFuentes: sin URLs no hay pool que armar, y el informe
// tiene que decirlo en vez de quedarse mudo.
func TestDiagnosticoPoolSinFuentes(t *testing.T) {
	diag := DiagnosticoPoolQobuz(nil, nil, nil, "", "")
	if diag.Estado != EstadoPoolSinFuentes {
		t.Fatalf("estado = %q, se esperaba %q", diag.Estado, EstadoPoolSinFuentes)
	}
}

// TestDiagnosticoPoolFuenteCaida: el endpoint no responde. Es el caso que el
// usuario veía como "no baja y no dice nada"; ahora se distingue de "sin tokens".
func TestDiagnosticoPoolFuenteCaida(t *testing.T) {
	caida := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	t.Cleanup(caida.Close)

	diag := DiagnosticoPoolQobuz(nil, nil, []string{caida.URL + "/pool"}, caida.URL, caida.URL+"/favorite/getUserFavorites")
	if diag.Estado != EstadoPoolFuenteCaida {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, EstadoPoolFuenteCaida, diag.Detalle)
	}
	if diag.Fuentes != 1 || len(diag.FuentesCaidas) != 1 {
		t.Errorf("fuentes = %d, caídas = %v", diag.Fuentes, diag.FuentesCaidas)
	}
}

// TestDiagnosticoPoolSinTokens: el endpoint responde, pero su lista no tiene
// ninguna credencial viva. El arreglo es el contenido, no la URL.
func TestDiagnosticoPoolSinTokens(t *testing.T) {
	srv := servidorPoolQobuz(t, "user_auth_token=TOKEN_MUERTO_123456\n", map[string]bool{})
	diag := DiagnosticoPoolQobuz(nil, nil, []string{srv.URL + "/pool"}, srv.URL, srv.URL+"/favorite/getUserFavorites")
	if diag.Estado != EstadoPoolSinTokens {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, EstadoPoolSinTokens, diag.Detalle)
	}
	if diag.FuentesCaidas != nil {
		t.Errorf("no debía haber fuentes caídas: %v", diag.FuentesCaidas)
	}
	if diag.Descartadas != 1 {
		t.Errorf("descartadas = %d, se esperaba 1", diag.Descartadas)
	}
}

// TestDiagnosticoPoolOk: el camino bueno, de punta a punta (publicar → extraer
// → validar) sin salir a la red.
func TestDiagnosticoPoolOk(t *testing.T) {
	srv := servidorPoolQobuz(t,
		"user_auth_token=TOKEN_VIVO_1234567890\nuser_auth_token=TOKEN_MUERTO_1234567890\n",
		map[string]bool{"TOKEN_VIVO_1234567890": true})
	diag := DiagnosticoPoolQobuz(nil, nil, []string{srv.URL + "/pool"}, srv.URL, srv.URL+"/favorite/getUserFavorites")
	if diag.Estado != EstadoPoolOk {
		t.Fatalf("estado = %q, se esperaba %q (detalle: %s)", diag.Estado, EstadoPoolOk, diag.Detalle)
	}
	if diag.Usables != 1 || diag.Descartadas != 1 {
		t.Errorf("usables/descartadas = %d/%d, se esperaba 1/1", diag.Usables, diag.Descartadas)
	}
}
