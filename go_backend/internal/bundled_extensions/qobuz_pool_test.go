// qobuz_pool_test.go — Prueba funcional del pool de credenciales de Qobuz
// cuando la credencial es un user_auth_token ya emitido (sin contraseña), con
// el arnés de Node (sin red).
//
// Por qué existe: el backend valida y manda DOS formas de credencial
// (sessionpool/qobuz.go): "email:password" y un user_auth_token suelto. Antes
// la extensión solo entendía la primera (descartaba cualquier línea sin ":"),
// así que un pool hecho solo de tokens quedaba vacío y apagaba la descarga
// directa. Estas pruebas cubren: (1) un token suelto da sesión sin login, (2)
// un token muerto rota a la siguiente credencial en vez de apagar todo, y (3)
// si no hay alternativa, se apaga con UNAUTHORIZED (no en silencio).
//
// Se conecta con: qobuz-web/index.js (qobuzEntradaDePool, poolDeCuentasQobuz,
// qobuzAplicarEntrada, qobuzRotarCuenta, qobuzDirectLogin,
// fetchDirectDownloadInfo) y arnes_node_test.go (stubs del host). Corre solo si
// `node` está en PATH.
package bundled_extensions

import (
	"strings"
	"testing"
)

func TestQobuzPoolTokenSueltoSeUsaSinLogin(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", `
initialize({ qobuzPool: "TOKEN-DEL-POOL-1234567890" });
console.log("session=" + hasDirectQobuzSession());
console.log("email=[" + CONFIG.userEmail + "]");
console.log("token=" + qobuzDirectLogin());
`)

	if !strings.Contains(salida, "session=true") {
		t.Errorf("un pool con un token suelto debería dar sesión directa.\n%s", salida)
	}
	if !strings.Contains(salida, "email=[]") {
		t.Errorf("un token suelto no tiene cuenta asociada; el email debía quedar vacío.\n%s", salida)
	}
	if !strings.Contains(salida, "token=TOKEN-DEL-POOL-1234567890") {
		t.Errorf("no se usó el token suelto del pool (o se intentó loguear).\n%s", salida)
	}
}

func TestQobuzPoolTokenMuertoRotaALaSiguiente(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
var logins = 0;
globalThis.http = {
  post: function () { logins++; return { statusCode: 200, body: JSON.stringify({ user_auth_token: "TOKEN-A" }) }; },
  get: function (url, headers) {
    var token = String((headers && headers["X-User-Auth-Token"]) || "");
    if (token === "TOKEN-POOL-MUERTO-123456") {
      return { statusCode: 200, body: JSON.stringify({ restrictions: [{ code: "UserUnauthenticated" }] }) };
    }
    return { statusCode: 200, body: JSON.stringify({ url: "https://cdn.qobuz/flac", bit_depth: 16, sampling_rate: 44100 }) };
  },
};

initialize({ qobuzPool: "TOKEN-POOL-MUERTO-123456\na@qobuz.com:claveA" });
var r = fetchDirectDownloadInfo("123", "6");
console.log("directURL=" + r.directURL);
console.log("logins=" + logins);
`)

	if !strings.Contains(salida, "directURL=https://cdn.qobuz/flac") {
		t.Errorf("con el token muerto debía rotar a la cuenta siguiente y bajar igual.\n%s", salida)
	}
	if !strings.Contains(salida, "logins=1") {
		t.Errorf("se esperaba exactamente un login (el de la cuenta siguiente).\n%s", salida)
	}
}

func TestQobuzPoolTokenSueltoMuertoSinAlternativaSeApaga(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
globalThis.http = {
  post: function () { return { statusCode: 404, body: "{}" }; },
  get: function () {
    return { statusCode: 200, body: JSON.stringify({ restrictions: [{ code: "UserUnauthenticated" }] }) };
  },
};

initialize({ qobuzPool: "TOKEN-MUERTO-1234567890" });
var code = "sin-error";
try { fetchDirectDownloadInfo("1", "6"); } catch (e) { code = e.code; }
console.log("code=" + code);
console.log("session=" + hasDirectQobuzSession());
`)

	if !strings.Contains(salida, "code=UNAUTHORIZED") {
		t.Errorf("con el único token muerto debía fallar con UNAUTHORIZED.\n%s", salida)
	}
	if !strings.Contains(salida, "session=false") {
		t.Errorf("tras apagarse, hasDirectQobuzSession() debía dar false.\n%s", salida)
	}
}
