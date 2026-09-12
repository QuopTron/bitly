// plataformas_test.go — Pruebas de los validadores de Tidal y Qobuz.
//
// Los contratos están verificados en vivo, pero el comportamiento ante
// credencial muerta / fuente caída / respuesta rara solo se puede
// asegurar con servidores de prueba. Eso es lo que cubre este archivo.
//
// Se conecta con: tidal.go y qobuz.go.
// Parte del flujo: red de seguridad del pool de sesiones.
package sessionpool

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

const jwtFalso = "eyJhbGciOiJIUzI1NiJ9.eyJ1aWQiOjF9.firmafirmafirma"

// ── Tidal ──────────────────────────────────────────────────────────────

func TestExtraerTokensTidal(t *testing.T) {
	casos := map[string]string{
		"jwt suelto":  jwtFalso,
		"markdown":    "| cuenta | `" + jwtFalso + "` |",
		"json":        `{"access_token":"` + jwtFalso + `"}`,
		"clave=valor": "tidal_token=" + jwtFalso,
	}
	for nombre, cuerpo := range casos {
		got := ExtraerTokensTidal(cuerpo)
		encontrado := false
		for _, v := range got {
			if v == jwtFalso {
				encontrado = true
			}
		}
		if !encontrado {
			t.Errorf("%s: no extrajo el token: %v", nombre, got)
		}
	}
}

func TestValidarTokenTidal(t *testing.T) {
	bueno := "tokenbueno" + jwtFalso
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+bueno {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"status":401,"subStatus":11002,"userMessage":"Token has invalid payload"}`))
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"status": 200, "userId": 42})
	}))
	defer srv.Close()

	if !validarTokenTidalEn(nil, srv.URL, bueno) {
		t.Error("el token bueno debía validar")
	}
	if validarTokenTidalEn(nil, srv.URL, "otroTokenDistintoXX") {
		t.Error("el token malo no debía validar")
	}
	if validarTokenTidalEn(nil, srv.URL, "corto") {
		t.Error("un token demasiado corto no debía validar")
	}
}

func TestTidal200ConErrorEmbebidoSeRechaza(t *testing.T) {
	// Tidal también contesta 200 con el error adentro: no se puede mirar
	// solo el código de estado.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{"status": 401, "userMessage": "Token has invalid payload"})
	}))
	defer srv.Close()
	if validarTokenTidalEn(nil, srv.URL, "tokenlargoquenovalida") {
		t.Error("un 200 con status 401 embebido debía rechazarse")
	}
}

func TestPoolTidalDescartaTokensMuertos(t *testing.T) {
	bueno := "bueno" + jwtFalso
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") == "Bearer "+bueno {
			_ = json.NewEncoder(w).Encode(map[string]any{"status": 200})
			return
		}
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer srv.Close()

	fuente := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("token=" + bueno + "\notro=" + "muerto" + jwtFalso))
	}))
	defer fuente.Close()

	res := ConstruirPoolTidal(nil, nil, []string{fuente.URL}, srv.URL)
	if len(res.Usables) != 1 || res.Usables[0] != bueno {
		t.Fatalf("el pool debía quedarse solo con el token vivo: %+v", res)
	}
}

// ── Qobuz ──────────────────────────────────────────────────────────────

func TestExtraerCredencialesQobuz(t *testing.T) {
	// Cuenta + token suelto en el mismo texto.
	texto := "cuenta1@correo.com:clave123\ntoken=" + jwtFalso
	got := ExtraerCredencialesQobuz(texto)
	if len(got) < 2 {
		t.Fatalf("esperaba cuenta y token, obtuve %v", got)
	}
	if got[0] != "cuenta1@correo.com:clave123" {
		t.Errorf("la cuenta debía ir primero: %v", got)
	}
	// Basura sin arroba ni pinta de token no debe entrar.
	if len(ExtraerCredencialesQobuz("linea sin nada")) != 0 {
		t.Error("no debía extraer nada de texto suelto")
	}
}

func TestValidarCredencialQobuzCuenta(t *testing.T) {
	const correo, clave = "cuenta@correo.com", "claveBuena123"
	login := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var cuerpo map[string]string
		_ = json.NewDecoder(r.Body).Decode(&cuerpo)
		if cuerpo["email"] != correo || cuerpo["password"] != clave {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"status":"error","code":401,"message":"Invalid username/email and password combination"}`))
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"user_auth_token": "TOKEN123"})
	}))
	defer login.Close()

	if !validarCredencialQobuzEn(nil, login.URL, login.URL, correo+":"+clave) {
		t.Error("la cuenta buena debía validar")
	}
	if validarCredencialQobuzEn(nil, login.URL, login.URL, correo+":claveMala") {
		t.Error("la cuenta mala no debía validar")
	}
}

func TestValidarCredencialQobuzTokenSuelto(t *testing.T) {
	favoritos := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("user_auth_token") != "TOKEN_VIVO" {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte(`{"status":"error","code":401,"message":"User authentication is required."}`))
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"tracks": map[string]any{"total": 1}})
	}))
	defer favoritos.Close()

	login := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer login.Close()

	// Validar contra favoritos directamente (token suelto).
	if !validarCredencialQobuzEn(nil, login.URL, favoritos.URL, "TOKEN_VIVO") {
		t.Error("el token vivo debía validar")
	}
	if validarCredencialQobuzEn(nil, login.URL, favoritos.URL, "TOKEN_MUERTO") {
		t.Error("el token muerto no debía validar")
	}
	if validarCredencialQobuzEn(nil, login.URL, favoritos.URL, "corto") {
		t.Error("un valor demasiado corto no debía validar")
	}
}

func TestPoolQobuzFuenteCaidaNoTumba(t *testing.T) {
	login := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{"user_auth_token": "T"})
	}))
	defer login.Close()

	caida := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer caida.Close()

	res := ConstruirPoolQobuz(nil, []string{"mia@correo.com:clave123"}, []string{caida.URL}, login.URL, login.URL)
	if len(res.FuentesCaidas) != 1 {
		t.Errorf("debía reportar la fuente caída: %+v", res)
	}
	if len(res.Usables) == 0 || res.Usables[0] != "mia@correo.com:clave123" {
		t.Errorf("mi cuenta debía sobrevivir a la fuente caída: %+v", res)
	}
}
