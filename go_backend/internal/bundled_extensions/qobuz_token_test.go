// qobuz_token_test.go — Prueba funcional de la persistencia del user_auth_token
// de Qobuz, con el arnés de Node (sin red).
//
// Por qué existe: el login de Qobuz cuesta una petición y su token se perdía al
// cerrar la app, así que la PRIMERA descarga de cada arranque pagaba ese login.
// Ahora el token se guarda (atado a la cuenta y con su vencimiento de 6 h) y se
// reusa mientras siga vigente. Estas pruebas cubren las cuatro reglas que hacen
// que la persistencia sea segura: se lee al arrancar, se guarda al loguear, un
// token vencido o de OTRA cuenta se ignora, y un token muerto se descarta con un
// relogin (en vez de apagar la descarga directa por un token viejo).
//
// Se conecta con: qobuz-web/index.js (initialize, qobuzDirectLogin,
// cargar/guardar/invalidarTokenGuardado, fetchDirectDownloadInfo) y
// arnes_node_test.go (stubs del host). Corre solo si `node` está en PATH.
package bundled_extensions

import (
	"strings"
	"testing"
)

// stubsQobuzToken arma el prólogo JS común: un storage en memoria con get/set/
// delete. Los tests le cargan el token que quieran antes de inicializar.
const stubsQobuzToken = `
var __store = {};
globalThis.storage = {
  get: function (k) { return Object.prototype.hasOwnProperty.call(__store, k) ? __store[k] : null; },
  set: function (k, v) { __store[k] = String(v); return true; },
  delete: function (k) { delete __store[k]; },
};
`

func TestQobuzTokenPersistidoEvitaLoginAlArrancar(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
var logins = 0;
globalThis.http = {
  post: function () { logins++; return { statusCode: 200, body: JSON.stringify({ user_auth_token: "TOKEN-LOGIN" }) }; },
  get: function () { return { statusCode: 404, body: "{}" }; },
};

var futuro = Date.now() + 6 * 60 * 60 * 1000;
storage.set("qobuz_auth_token", JSON.stringify({ email: "cuenta@qobuz.com", token: "TOKEN-GUARDADO", expiraEn: futuro }));

initialize({ email: "cuenta@qobuz.com", password: "clave" });
console.log("logins=" + logins);
console.log("token=" + CONFIG.userAuthToken);
console.log("deStorage=" + userAuthTokenDeStorage);
`)

	if !strings.Contains(salida, "logins=0") {
		t.Errorf("initialize() volvió a loguear teniendo un token guardado vigente.\n%s", salida)
	}
	if !strings.Contains(salida, "token=TOKEN-GUARDADO") {
		t.Errorf("no se cargó el token persistido al arrancar.\n%s", salida)
	}
	if !strings.Contains(salida, "deStorage=true") {
		t.Errorf("el token cargado no quedó marcado como proveniente del storage.\n%s", salida)
	}
}

func TestQobuzLoginPersisteElToken(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
var logins = 0;
globalThis.http = {
  post: function () { logins++; return { statusCode: 200, body: JSON.stringify({ user_auth_token: "TOKEN-LOGIN" }) }; },
  get: function () { return { statusCode: 404, body: "{}" }; },
};

initialize({ email: "cuenta@qobuz.com", password: "clave" });
var token = qobuzDirectLogin();
console.log("logins=" + logins);
console.log("token=" + token);
console.log("deStorage=" + userAuthTokenDeStorage);
var guardado = JSON.parse(storage.get("qobuz_auth_token"));
console.log("guardado_email=" + guardado.email);
console.log("guardado_token=" + guardado.token);
console.log("guardado_futuro=" + (Number(guardado.expiraEn) > Date.now()));
`)

	if !strings.Contains(salida, "logins=1") {
		t.Errorf("se esperaba exactamente un login.\n%s", salida)
	}
	if !strings.Contains(salida, "token=TOKEN-LOGIN") {
		t.Errorf("el login no devolvió el token esperado.\n%s", salida)
	}
	if !strings.Contains(salida, "guardado_email=cuenta@qobuz.com") {
		t.Errorf("el token no se guardó atado a la cuenta.\n%s", salida)
	}
	if !strings.Contains(salida, "guardado_token=TOKEN-LOGIN") {
		t.Errorf("el token obtenido no se persistió.\n%s", salida)
	}
	if !strings.Contains(salida, "guardado_futuro=true") {
		t.Errorf("el vencimiento guardado no quedó en el futuro.\n%s", salida)
	}
}

func TestQobuzTokenVencidoOAjenoNoSeUsa(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
globalThis.http = {
  post: function () { return { statusCode: 200, body: JSON.stringify({ user_auth_token: "TOKEN-LOGIN" }) }; },
  get: function () { return { statusCode: 404, body: "{}" }; },
};

// Token VENCIDO de la cuenta correcta: no se debe usar.
var pasado = Date.now() - 1000;
storage.set("qobuz_auth_token", JSON.stringify({ email: "cuenta@qobuz.com", token: "TOKEN-VENCIDO", expiraEn: pasado }));
initialize({ email: "cuenta@qobuz.com", password: "clave" });
console.log("vencido=[" + CONFIG.userAuthToken + "]");

// Token vigente de OTRA cuenta: no se debe usar con esta.
storage.set("qobuz_auth_token", JSON.stringify({ email: "otra@qobuz.com", token: "TOKEN-AJENO", expiraEn: Date.now() + 6 * 60 * 60 * 1000 }));
initialize({ email: "cuenta@qobuz.com", password: "clave" });
console.log("ajeno=[" + CONFIG.userAuthToken + "]");
`)

	if !strings.Contains(salida, "vencido=[]") {
		t.Errorf("se usó (o se conservó) un token vencido; debía quedar vacío.\n%s", salida)
	}
	if !strings.Contains(salida, "ajeno=[]") {
		t.Errorf("se usó un token de otra cuenta; debía quedar vacío.\n%s", salida)
	}
}

func TestQobuzTokenGuardadoSeBorraAlBorrarCredenciales(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
globalThis.http = {
  post: function () { return { statusCode: 404, body: "{}" }; },
  get: function () { return { statusCode: 404, body: "{}" }; },
};

var futuro = Date.now() + 6 * 60 * 60 * 1000;
storage.set("qobuz_auth_token", JSON.stringify({ email: "cuenta@qobuz.com", token: "TOKEN-GUARDADO", expiraEn: futuro }));

// Arranque normal: el token guardado de la MISMA cuenta se carga.
initialize({ email: "cuenta@qobuz.com", password: "clave" });
console.log("antes=[" + CONFIG.userAuthToken + "]");

// El usuario borra sus credenciales: el token persistido debe desaparecer.
initialize({ email: "", password: "" });
console.log("despues=[" + CONFIG.userAuthToken + "]");
console.log("storage=[" + String(storage.get("qobuz_auth_token")) + "]");
console.log("deStorage=" + userAuthTokenDeStorage);

// Volver a poner la misma cuenta NO debe resucitar el token viejo.
initialize({ email: "cuenta@qobuz.com", password: "clave" });
console.log("reusado=[" + CONFIG.userAuthToken + "]");
`)

	if !strings.Contains(salida, "antes=[TOKEN-GUARDADO]") {
		t.Errorf("el arranque normal debía cargar el token guardado de la misma cuenta.\n%s", salida)
	}
	if !strings.Contains(salida, "despues=[]") {
		t.Errorf("al borrar las credenciales el token en memoria debía quedar vacío.\n%s", salida)
	}
	if !strings.Contains(salida, "storage=[null]") {
		t.Errorf("al borrar las credenciales el token persistido debía borrarse del storage.\n%s", salida)
	}
	if !strings.Contains(salida, "deStorage=false") {
		t.Errorf("el flag de token-de-storage debía quedar en false.\n%s", salida)
	}
	if !strings.Contains(salida, "reusado=[]") {
		t.Errorf("volver a la misma cuenta reusó un token viejo que ya se había borrado.\n%s", salida)
	}
}

func TestQobuzCambioDeCuentaBorraTokenAnterior(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
globalThis.http = {
  post: function () { return { statusCode: 404, body: "{}" }; },
  get: function () { return { statusCode: 404, body: "{}" }; },
};

var futuro = Date.now() + 6 * 60 * 60 * 1000;
storage.set("qobuz_auth_token", JSON.stringify({ email: "cuenta@qobuz.com", token: "TOKEN-A", expiraEn: futuro }));

initialize({ email: "cuenta@qobuz.com", password: "clave" });
console.log("antes=[" + CONFIG.userAuthToken + "]");

// Cambio de cuenta: el token de la cuenta anterior no debe sobrevivir.
initialize({ email: "otra@qobuz.com", password: "clave" });
console.log("despues=[" + CONFIG.userAuthToken + "]");
console.log("storage=[" + String(storage.get("qobuz_auth_token")) + "]");
`)

	if !strings.Contains(salida, "antes=[TOKEN-A]") {
		t.Errorf("el arranque normal debía cargar el token de la cuenta.\n%s", salida)
	}
	if !strings.Contains(salida, "despues=[]") {
		t.Errorf("al cambiar de cuenta el token en memoria debía quedar vacío.\n%s", salida)
	}
	if !strings.Contains(salida, "storage=[null]") {
		t.Errorf("al cambiar de cuenta el token persistido anterior debía borrarse.\n%s", salida)
	}
}

// TestQobuzTokenDeOtraCuentaDelPoolNoSeAplicaALaPrimera deja por escrito la
// propiedad que hace SEGURA la clave ÚNICA de storage frente al pool: el token
// persistido de una cuenta rotada (no la primera) NUNCA se aplica a la primera
// cuenta. Si el token guardado es de la cuenta B y el pool empieza por A, el
// arranque deja el token vacío (sin usar el de B) y tocará loguear. Por eso no
// hace falta aislar el storage por cuenta: cargarTokenGuardado exige el MISMO
// email, y qobuzRotarCuenta no relee el storage tras rotar.
func TestQobuzTokenDeOtraCuentaDelPoolNoSeAplicaALaPrimera(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
var futuro = Date.now() + 6 * 60 * 60 * 1000;
// El pool (ya validado por el backend) tiene la cuenta propia A y una fuente B.
// El storage quedó con el token de B: la última que logueó en una sesión previa.
storage.set("qobuz_auth_token", JSON.stringify({ email: "b@qobuz.com", token: "TOKEN-B", expiraEn: futuro }));

initialize({ qobuzPool: "a@qobuz.com:claveA\nb@qobuz.com:claveB" });
console.log("email0=" + CONFIG.userEmail);
console.log("token0=[" + CONFIG.userAuthToken + "]");
console.log("deStorage=" + userAuthTokenDeStorage);
`)

	if !strings.Contains(salida, "email0=a@qobuz.com") {
		t.Errorf("la primera cuenta del pool debía ser la propia (A).\n%s", salida)
	}
	if !strings.Contains(salida, "token0=[]") {
		t.Errorf("se aplicó a la cuenta A un token guardado de la cuenta B.\n%s", salida)
	}
	if !strings.Contains(salida, "deStorage=false") {
		t.Errorf("el token de otra cuenta no debería contarse como token-de-storage.\n%s", salida)
	}
}

// TestQobuzCambioDeCuentaConservaElTokenDeOtraCuentaDelPool cubre la limpieza
// PRECISA: al cambiar la cuenta propia, solo se borra el token guardado si es
// de ESA cuenta. El de otra cuenta del pool se conserva (podría ser el que logueó
// último y el que se reusará si le toca el turno).
func TestQobuzCambioDeCuentaConservaElTokenDeOtraCuentaDelPool(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
var futuro = Date.now() + 6 * 60 * 60 * 1000;
// El storage quedó con el token de B (otra cuenta del pool).
storage.set("qobuz_auth_token", JSON.stringify({ email: "b@qobuz.com", token: "TOKEN-B", expiraEn: futuro }));

// Primera cuenta propia: A (no había previa, no se toca el token guardado).
initialize({ email: "a@qobuz.com", password: "claveA", qobuzPool: "a@qobuz.com:claveA\nb@qobuz.com:claveB" });

// Cambio de la cuenta propia A -> A2: el token guardado es de B, NO debe borrarse.
initialize({ email: "a2@qobuz.com", password: "claveA2", qobuzPool: "a2@qobuz.com:claveA2\nb@qobuz.com:claveB" });
var crudo = storage.get("qobuz_auth_token");
var guardado = crudo ? JSON.parse(crudo) : null;
console.log("sigue=" + (guardado ? guardado.token : "null"));
`)

	if !strings.Contains(salida, "sigue=TOKEN-B") {
		t.Errorf("cambiar la cuenta propia borró el token de OTRA cuenta del pool.\n%s", salida)
	}
}

func TestQobuzTokenMuertoSeDescartaYRelogin(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "qobuz-web", stubsQobuzToken+`
var logins = 0;
var fileUrls = [];
globalThis.http = {
  post: function () { logins++; return { statusCode: 200, body: JSON.stringify({ user_auth_token: "TOKEN-NUEVO" }) }; },
  get: function (url, headers) {
    var token = String((headers && headers["X-User-Auth-Token"]) || "");
    fileUrls.push(token);
    if (token === "TOKEN-VIEJO") {
      return { statusCode: 200, body: JSON.stringify({ restrictions: [{ code: "UserUnauthenticated" }] }) };
    }
    return { statusCode: 200, body: JSON.stringify({ url: "https://cdn.qobuz/flac", bit_depth: 16, sampling_rate: 44100 }) };
  },
};

storage.set("qobuz_auth_token", JSON.stringify({ email: "cuenta@qobuz.com", token: "TOKEN-VIEJO", expiraEn: Date.now() + 6 * 60 * 60 * 1000 }));
initialize({ email: "cuenta@qobuz.com", password: "clave" });

var r = fetchDirectDownloadInfo("123", "6");
console.log("directURL=" + r.directURL);
console.log("logins=" + logins);
console.log("fileUrls=" + fileUrls.join(","));
var guardado = JSON.parse(storage.get("qobuz_auth_token"));
console.log("guardado_token=" + guardado.token);
`)

	if !strings.Contains(salida, "directURL=https://cdn.qobuz/flac") {
		t.Errorf("el reintento con login fresco no consiguió la URL.\n%s", salida)
	}
	if !strings.Contains(salida, "logins=1") {
		t.Errorf("se esperaba exactamente un relogin.\n%s", salida)
	}
	if !strings.Contains(salida, "fileUrls=TOKEN-VIEJO,TOKEN-NUEVO") {
		t.Errorf("el primer intento debía usar el token guardado y el segundo el fresco.\n%s", salida)
	}
	if !strings.Contains(salida, "guardado_token=TOKEN-NUEVO") {
		t.Errorf("no se reemplazó el token muerto por el fresco en el storage.\n%s", salida)
	}
}
