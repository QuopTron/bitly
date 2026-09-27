// tidal_publictoken_forma_test.go — Guarda de FORMA del refresco perezoso del
// token público de Tidal.
//
// Por qué existe: la prueba funcional (tidal_publictoken_test.go) comprueba el
// comportamiento de HOY, pero nada impide que mañana alguien vuelva a meter la
// consulta al origen dentro de initialize() "para que el token esté fresco".
// Esa regresión es silenciosa: la extensión seguiría funcionando, solo que cada
// arranque volvería a pegarle a un tercero y, si ese origen está caído, la
// primera llamada quedaría esperando el timeout de red. Por eso la guarda mira
// el CUERPO de initialize, no el archivo entero: un fetchPublicToken legítimo en
// otra función no debe hacerla fallar.
//
// Se conecta con: tidal-web/index.js. Si alguna de estas piezas se renombra a
// propósito, actualizá también esta guarda: el valor está en que el borrado sea
// una decisión, no un descuido.
package bundled_extensions

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestTidalNoRefrescaElTokenPublicoEnInitialize(t *testing.T) {
	crudo, err := os.ReadFile(filepath.Join(".", "tidal-web", "index.js"))
	if err != nil {
		t.Fatalf("no se pudo leer la extensión de Tidal: %v", err)
	}
	codigo := string(crudo)

	// 1) initialize NO puede consultar el origen ni refrescar el token: el
	//    refresco es perezoso y vive en asegurarPublicTokenFresco().
	cuerpoInitialize := cuerpoDeFuncion(t, codigo, "initialize")
	prohibidas := []struct {
		marca  string
		porQue string
	}{
		{
			marca:  "fetchPublicToken",
			porQue: "initialize volvió a pedir el token al origen: es la petición a un tercero en cada arranque que se sacó a propósito",
		},
		{
			marca:  "asegurarPublicTokenFresco",
			porQue: "el refresco de initialize dejó de ser perezoso: ahora también se dispara en el arranque",
		},
	}
	for _, p := range prohibidas {
		if strings.Contains(cuerpoInitialize, p.marca) {
			t.Errorf("initialize() no debe llamar a %q: %s", p.marca, p.porQue)
		}
	}

	// Sí tiene que usar el token guardado: sin esto la única salida sería volver
	// a consultar el origen.
	if !strings.Contains(cuerpoInitialize, "cargarPublicTokenGuardado") {
		t.Error("initialize() dejó de usar cargarPublicTokenGuardado(): sin el último token bueno vuelve la consulta al origen en cada arranque")
	}

	// 2) Las piezas del refresco perezoso tienen que seguir existiendo.
	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{
			nombre: "refresco ante rechazo",
			marca:  "asegurarPublicTokenFresco",
			porQue: "es el único camino que refresca el token: sin él, un 401 deja la fuente muerta",
		},
		{
			nombre: "cooldown",
			marca:  "PUBLIC_TOKEN_REINTENTO_MIN_MS",
			porQue: "sin cooldown un origen caído se consultaría en cada petición rechazada",
		},
		{
			nombre: "persistencia del token",
			marca:  "guardarPublicTokenGuardado",
			porQue: "sin guardarlo, el próximo arranque vuelve a consultar el origen",
		},
		{
			nombre: "lectura del token guardado",
			marca:  "CLAVE_TOKEN_PUBLICO",
			porQue: "es la clave de storage que evita la consulta en cada arranque",
		},
		{
			nombre: "respeto por el token del usuario",
			marca:  "publicTokenEsDelUsuario",
			porQue: "un token puesto a mano no se debe pisar ni consultar el origen",
		},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}

	// 3) Metadata/search (getJSON) es donde el 401 tiene que disparar el refresco
	//    con reintento; si se saca, el token ya no se renueva por esa vía.
	cuerpoGetJSON := cuerpoDeFuncion(t, codigo, "getJSON")
	if !strings.Contains(cuerpoGetJSON, "asegurarPublicTokenFresco") {
		t.Error("getJSON() dejó de refrescar el token público ante 401/403: metadata/search quedaría muerto hasta pegar un token a mano")
	}
	if !strings.Contains(cuerpoGetJSON, "401") || !strings.Contains(cuerpoGetJSON, "403") {
		t.Error("getJSON() dejó de contemplar los códigos 401/403 como rechazo del token público")
	}
}

// cuerpoDeFuncion devuelve el texto desde `function <nombre>(` hasta su llave de
// cierre, contando llaves. Basta para este archivo (los cuerpos no tienen llaves
// dentro de strings ni comentarios). Falla el test si no encuentra la función.
func cuerpoDeFuncion(t *testing.T, codigo, nombre string) string {
	t.Helper()
	inicio := strings.Index(codigo, "function "+nombre+"(")
	if inicio < 0 {
		t.Fatalf("no se encontró la función %s en la extensión", nombre)
	}
	llave := strings.Index(codigo[inicio:], "{")
	if llave < 0 {
		t.Fatalf("la función %s no tiene cuerpo", nombre)
	}
	llave += inicio

	profundidad := 0
	for i := llave; i < len(codigo); i++ {
		switch codigo[i] {
		case '{':
			profundidad++
		case '}':
			profundidad--
			if profundidad == 0 {
				return codigo[llave : i+1]
			}
		}
	}
	t.Fatalf("no se pudo cerrar el cuerpo de %s", nombre)
	return ""
}
