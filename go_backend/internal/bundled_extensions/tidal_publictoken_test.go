// tidal_publictoken_test.go — Prueba funcional del refresco PEREZOSO del token
// público de Tidal (`x-tidal-token`), con el arnés de Node (sin red).
//
// Por qué existe: antes la extensión consultaba el origen del token en CADA
// arranque (dentro de initialize). Eso metía una petición a un tercero en cada
// arranque y, si el origen estaba caído, la primera llamada de metadata/search
// quedaba esperando hasta el timeout de red. La regla nueva es: el token se pide
// UNA vez (cuando no hay ninguno guardado) y de nuevo solo cuando la API lo
// rechaza con 401/403, con cooldown para no martillar el origen.
//
// Se conecta con: tidal-web/index.js (initialize, getJSON,
// asegurarPublicTokenFresco, cargar/guardarPublicTokenGuardado) y
// arnes_node_test.go (stubs del host). Corre solo si `node` está en PATH.
package bundled_extensions

import (
	"strings"
	"testing"
)

func TestTidalPublicTokenSeRefrescaSoloAlRechazar(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "tidal-web", `
var peticionesOrigen = 0;
var peticionesApi = [];
var __store = {};
globalThis.storage = {
  get: function (k) { return Object.prototype.hasOwnProperty.call(__store, k) ? __store[k] : null; },
  set: function (k, v) { __store[k] = v; return true; },
  delete: function (k) { delete __store[k]; },
};
globalThis.http = {
  get: function (url, headers) {
    if (String(url).indexOf("flacdownloader.com") !== -1) {
      peticionesOrigen++;
      return { statusCode: 200, body: JSON.stringify({ token: "TOKEN-ORIGEN-1", countryCode: "AR" }) };
    }
    var usado = String((headers && headers["x-tidal-token"]) || "");
    peticionesApi.push(usado);
    if (usado === "TOKEN-ORIGEN-1") {
      return { statusCode: 200, body: JSON.stringify({ id: 7 }) };
    }
    return { statusCode: 401, body: "{}" };
  },
  post: function () { return { statusCode: 404, body: "{}" }; },
};

initialize({});
console.log("init0_origen=" + peticionesOrigen);

var r = getJSON("https://tidal.com/v1/tracks/7");
console.log("resultado=" + r.id);
console.log("tras401_origen=" + peticionesOrigen);
console.log("api=" + peticionesApi.join(","));

getJSON("https://tidal.com/v1/tracks/8");
console.log("tras2origen=" + peticionesOrigen);

initialize({});
console.log("init2_origen=" + peticionesOrigen);
console.log("token=" + CONFIG.publicToken);
console.log("country=" + CONFIG.countryCode);
`)

	// initialize NO consulta el origen: el refresco es perezoso.
	if !strings.Contains(salida, "init0_origen=0") {
		t.Errorf("initialize consultó el origen; el refresco tiene que ser perezoso.\n%s", salida)
	}
	// El 401 en metadata dispara exactamente UNA consulta al origen y un reintento.
	if !strings.Contains(salida, "resultado=7") {
		t.Errorf("el reintento con el token refrescado no devolvió datos.\n%s", salida)
	}
	if !strings.Contains(salida, "tras401_origen=1") {
		t.Errorf("se esperaba exactamente 1 consulta al origen tras el 401.\n%s", salida)
	}
	// Dos intentos contra la API: el de fábrica (rechazado) y el refrescado.
	if !strings.Contains(salida, "api=49YxDN9a2aFV6RTG,TOKEN-ORIGEN-1") {
		t.Errorf("los tokens usados contra la API no fueron [fabrica, refrescado].\n%s", salida)
	}
	// Con el token ya bueno no se vuelve a consultar el origen.
	if !strings.Contains(salida, "tras2origen=1") {
		t.Errorf("se consultó el origen sin haber un rechazo.\n%s", salida)
	}
	// Un segundo initialize usa el token guardado y tampoco consulta el origen:
	// esto es lo que evita la petición a un tercero en cada arranque.
	if !strings.Contains(salida, "init2_origen=1") {
		t.Errorf("el segundo arranque volvió a consultar el origen (no se guardó el token).\n%s", salida)
	}
	if !strings.Contains(salida, "token=TOKEN-ORIGEN-1") {
		t.Errorf("no quedó el token refrescado guardado.\n%s", salida)
	}
	if !strings.Contains(salida, "country=AR") {
		t.Errorf("no se aplicó el countryCode que publica el origen.\n%s", salida)
	}
}

func TestTidalPublicTokenNoMartillaElOrigenCaido(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "tidal-web", `
var peticionesOrigen = 0;
var __store = {};
globalThis.storage = {
  get: function (k) { return Object.prototype.hasOwnProperty.call(__store, k) ? __store[k] : null; },
  set: function (k, v) { __store[k] = v; return true; },
  delete: function (k) { delete __store[k]; },
};
globalThis.http = {
  get: function (url) {
    if (String(url).indexOf("flacdownloader.com") !== -1) {
      peticionesOrigen++;
      return { statusCode: 503, body: "" };
    }
    return { statusCode: 401, body: "{}" };
  },
  post: function () { return { statusCode: 404, body: "{}" }; },
};

initialize({});
var errores = 0;
for (var i = 0; i < 5; i++) {
  try { getJSON("https://tidal.com/v1/tracks/" + i); } catch (e) { errores++; }
}
console.log("errores=" + errores);
console.log("peticionesOrigen=" + peticionesOrigen);
`)

	// Cada petición rechazada falla con claridad...
	if !strings.Contains(salida, "errores=5") {
		t.Errorf("los 5 rechazos no se propagaron como error.\n%s", salida)
	}
	// ...pero el origen caído se consulta UNA sola vez (cooldown): sin esto se
	// martillaría un tercero en cada petición rechazada.
	if !strings.Contains(salida, "peticionesOrigen=1") {
		t.Errorf("se consultó el origen caído más de una vez (falta el cooldown).\n%s", salida)
	}
}
