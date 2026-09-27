// amazon_busqueda_caida_test.go — guardas de la búsqueda anónima caída.
//
// Medido en vivo (2026-09): showSearch de Amazon contesta 200 en los 6
// storefronts con un DialogTemplate "Error de servicio" (~1.2 KB) para cualquier
// keyword y cualquier combinación de userHash/IsLibrary. No es geo-bloqueo ni
// sesión: Amazon dejó de servir la búsqueda anónima (el feed no se afecta).
//
// Sin el corte, cada búsqueda del host pagaba 6 storefronts × 5 reintentos de
// fetchWithRetry × 2 peticiones (config.json + showSearch) ≈ 60 peticiones y un
// log en bucle, para un resultado que ya se sabía inexistente. Estos tests fijan
// que (a) el diálogo de servicio se reconoce, (b) se marca la caída y (c) la
// búsqueda siguiente falla al instante sin tocar la red.
package bundled_extensions

import (
	"strings"
	"testing"
)

// TestAmazonConservaLaBusquedaQueFallaRapido es la guarda de FORMA: si alguien
// reescribe la extensión y borra el corte, este test lo avisa sin depender de la
// red ni de Node.
func TestAmazonConservaLaBusquedaQueFallaRapido(t *testing.T) {
	fuente := leerExtension(t, "amazon")

	marcadores := []string{
		// El detector del diálogo concreto (no basta esDialogoDeError, que
		// acepta cualquier respuesta sin resultados).
		"function esDialogoDeServicio(",
		"DialogTemplateInterface.DialogTemplate",
		"Error de servicio",
		// El estado de pausa y su duración configurable.
		"var _searchServiceDownUntil = 0;",
		"searchServiceCooldownMs:",
		// El error terminal: retryable=false es lo que hace que fetchWithRetry
		// corte de una en vez de repetir el recorrido completo.
		"function errorBusquedaAmazon(",
		"e.retryable = false;",
		"AMAZON_SEARCH_UNAVAILABLE",
	}
	for _, m := range marcadores {
		if !strings.Contains(fuente, m) {
			t.Errorf("amazon/index.js perdió %q: sin eso la búsqueda vuelve a reintentar en bucle", m)
		}
	}

	// El corte temprano tiene que ir ANTES de initSession(ctx): initSession ya
	// es una petición a config.json, así que chequear después no ahorra nada.
	iCorte := strings.Index(fuente, "_searchServiceDownUntil) {")
	iInit := strings.Index(fuente, "\n  initSession(ctx);\n  L(\"info\", \"[Amazon] callShowSearch:")
	if iCorte < 0 || iInit < 0 {
		t.Fatalf("no se encontraron los anclajes del corte (corte=%d initSession=%d)", iCorte, iInit)
	}
	if iCorte > iInit {
		t.Error("el corte por servicio caído quedó DESPUÉS de initSession(ctx): gasta igual la petición a config.json")
	}

	// Y el corte tiene que lanzarse también cuando el diálogo aparece dentro del
	// recorrido, no sólo en la entrada.
	if !strings.Contains(fuente, "_searchServiceDownUntil = Date.now() + CONFIG.searchServiceCooldownMs;") {
		t.Error("falta marcar la caída cuando el recorrido de storefronts ya encontró el diálogo")
	}
}

// TestAmazonFallaRapidoConElDialogoDeServicio ejecuta la lógica real en Node,
// sin red: confirma que el diálogo se reconoce, que una búsqueda con diálogos
// termina en error terminal y que la búsqueda siguiente NO vuelve a salir.
func TestAmazonFallaRapidoConElDialogoDeServicio(t *testing.T) {
	// El guion reemplaza `fetch` por un doble que contesta diálogo en showSearch
	// y un config.json válido en el resto (initSession lo pide por storefront).
	// Cuenta cuántas veces se pidió showSearch para probar el ahorro.
	guion := `
var DIALOGO = {methods:[{interface:"TemplateListInterface.v1_0.CreateAndBindTemplateMethod",template:{interface:"Web.TemplatesInterface.v1_0.Touch.DialogTemplateInterface.DialogTemplate",header:"Error de servicio",body:{interface:"Web.TemplatesInterface.v1_0.Touch.DialogTemplateInterface.DialogBodyElement"}}}]};
var RESULTADOS = {methods:[{interface:"TemplateListInterface.v1_0.CreateAndBindTemplateMethod",template:{interface:"Web.TemplatesInterface.v1_0.Touch.SearchTemplateInterface.ShovelerWidgetElement",items:[]}}]};

console.log("reconoce-dialogo=" + esDialogoDeServicio(DIALOGO));
console.log("reconoce-resultados=" + esDialogoDeServicio(RESULTADOS));

var showSearch = 0;
globalThis.fetch = function (url) {
  if (String(url).indexOf("/showSearch") >= 0) {
    showSearch++;
    return { ok: true, status: 200, json: function () { return DIALOGO; } };
  }
  return { ok: true, status: 200, json: function () { return { deviceId: "d", sessionId: "s", version: "1.0.0", csrf: { token: "t", ts: "1", rnd: "2" } }; } };
};

var e1 = null;
try { callShowSearch("BbY WoW", createAmazonContext("https://music.amazon.com")); } catch (e) { e1 = e; }
var primeraVuelta = showSearch;

var e2 = null;
try { callShowSearch("BbY WoW", createAmazonContext("https://music.amazon.com")); } catch (e) { e2 = e; }

console.log("err1-code=" + (e1 && e1.code));
console.log("err1-retryable=" + (e1 && e1.retryable));
console.log("err1-es-terminal=" + (e1 && e1.retryable === false));
console.log("err2-code=" + (e2 && e2.code));
console.log("storefronts=" + CONFIG.storefronts.length);
console.log("showSearch-primera=" + primeraVuelta);
console.log("showSearch-segunda=" + (showSearch - primeraVuelta));
`

	salida := ejecutarLogicaExtension(t, "amazon", guion)

	if !strings.Contains(salida, "reconoce-dialogo=true") {
		t.Errorf("no reconoció el diálogo de servicio:\n%s", salida)
	}
	if !strings.Contains(salida, "reconoce-resultados=false") {
		t.Errorf("marcó como diálogo una respuesta con resultados:\n%s", salida)
	}
	if !strings.Contains(salida, "err1-code=AMAZON_SEARCH_UNAVAILABLE") {
		t.Errorf("la búsqueda con diálogo no terminó en el error terminal:\n%s", salida)
	}
	if !strings.Contains(salida, "err1-es-terminal=true") {
		t.Errorf("el error no quedó marcado como no reintentable (fetchWithRetry volvería a repetir):\n%s", salida)
	}
	if !strings.Contains(salida, "err2-code=AMAZON_SEARCH_UNAVAILABLE") {
		t.Errorf("la segunda búsqueda no cortó por la pausa:\n%s", salida)
	}
	if !strings.Contains(salida, "showSearch-segunda=0") {
		t.Errorf("la segunda búsqueda volvió a salir a la red pese a la pausa:\n%s", salida)
	}
	// La primera sí recorre los storefronts (uno por cada uno), pero una sola vez:
	// sin el corte, fetchWithRetry repetiría el recorrido 5 veces.
	if !strings.Contains(salida, "showSearch-primera=6") {
		t.Errorf("la primera búsqueda no recorrió exactamente una vez los 6 storefronts:\n%s", salida)
	}
}
