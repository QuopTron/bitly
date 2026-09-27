// qobuz_pool_forma_test.go — Guarda de FORMA del soporte de tokens sueltos en el
// pool de Qobuz.
//
// Por qué existe: la prueba funcional (qobuz_pool_test.go) comprueba el
// comportamiento de HOY, pero nada impide que mañana alguien vuelva a filtrar
// las credenciales del pool por ":" —como estaba antes— "porque las cuentas se
// escriben email:password". Ese retroceso es silencioso: la extensión seguiría
// funcionando con cuentas, solo que un pool hecho solo de user_auth_token
// (forma que el backend también valida y manda) volvería a quedar vacío y
// apagaría la descarga directa sin avisar. Por eso la guarda mira el CUERPO de
// las funciones, no el archivo entero: un ":" legítimo en otra función no la
// hace fallar.
//
// Se conecta con: qobuz-web/index.js. Si alguna de estas piezas se renombra a
// propósito, actualizá también esta guarda: el valor está en que el borrado sea
// una decisión, no un descuido.
package bundled_extensions

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestQobuzPoolNoDescartaTokensSueltos(t *testing.T) {
	crudo, err := os.ReadFile(filepath.Join(".", "qobuz-web", "index.js"))
	if err != nil {
		t.Fatalf("no se pudo leer la extensión de Qobuz: %v", err)
	}
	codigo := string(crudo)

	// 1) El armado del pool DELEGA en el parser de entradas y no filtra por ":".
	cuerpoPool := cuerpoDeFuncion(t, codigo, "poolDeCuentasQobuz")
	if !strings.Contains(cuerpoPool, "qobuzEntradaDePool") {
		t.Error("poolDeCuentasQobuz() dejó de interpretar cada línea con qobuzEntradaDePool(): es el único lugar que acepta tokens sueltos, sin él un pool de tokens queda vacío")
	}
	if strings.Contains(cuerpoPool, `indexOf(":")`) {
		t.Error("poolDeCuentasQobuz() volvió a filtrar por ':': eso descarta los user_auth_token sueltos que el backend manda")
	}

	// 2) El parser acepta las DOS formas: cuenta (email:password) y token suelto.
	cuerpoEntrada := cuerpoDeFuncion(t, codigo, "qobuzEntradaDePool")
	if !strings.Contains(cuerpoEntrada, "QOBUZ_CORREO_RE") {
		t.Error("qobuzEntradaDePool() dejó de reconocer cuentas email:password")
	}
	if !strings.Contains(cuerpoEntrada, ".length >= 16") || !strings.Contains(cuerpoEntrada, "token:") {
		t.Error("qobuzEntradaDePool() dejó de reconocer un token suelto (user_auth_token): el pool solo aceptaría cuentas")
	}

	// 3) El login devuelve el token de una entrada suelta sin exigir contraseña.
	cuerpoLogin := cuerpoDeFuncion(t, codigo, "qobuzDirectLogin")
	if !strings.Contains(cuerpoLogin, "QOBUZ_TOKEN_SESION_MS") ||
		!strings.Contains(cuerpoLogin, "CONFIG.userAuthToken") {
		t.Error("qobuzDirectLogin() dejó de devolver el token de una entrada suelta sin intentar loguear")
	}

	// 4) Las piezas clave del soporte tienen que seguir existiendo.
	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{"parser de entradas", "qobuzEntradaDePool", "es lo que separa cuentas de tokens sueltos"},
		{"aplicar entrada a CONFIG", "qobuzAplicarEntrada", "deja el token del pool en CONFIG para usarlo sin login"},
		{"regex de email", "QOBUZ_CORREO_RE", "distingue una cuenta de un token suelto"},
		{"sesión de token", "QOBUZ_TOKEN_SESION_MS", "cuánto vale un token del pool antes de rotar"},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}
}
