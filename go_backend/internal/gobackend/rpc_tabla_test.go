// Guard del contrato RPC.
//
// Regla: si Flutter llama a un método que la tabla única no conoce, ESTE
// TEST FALLA. Así es imposible volver a tener la divergencia clásica del
// proyecto (getSearchConfig roto en escritorio, enviarReporte roto en iOS,
// descargarFuente roto en Android): un método nuevo en Dart obliga a
// registrarlo en internal/gobackend/rpc_tabla.go, y desde ahí vale para
// escritorio, web, Android e iOS a la vez.
//
// Se conecta con: lib/core/backend_go/** (rpcCall/invokeMethod del lado
// Dart) y internal/gobackend/rpc_tabla.go (tabla única).
// Parte del flujo: contrato frontend ↔ backend.

package gobackend

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
)

// raizFrontend es la carpeta lib/ del repo, relativa a este paquete
// (go_backend/internal/gobackend → ../../..).
const raizFrontend = "../../.."

// metodosNativos no son RPC: los resuelve el puente nativo de cada
// plataforma (MainActivity.kt / AppDelegate.swift) antes de llegar a Go.
var metodosNativos = map[string]bool{
	"initGoBackend":                    true,
	"getApplicationDocumentsDirectory": true,
}

var (
	rxRpcCall      = regexp.MustCompile(`rpcCall\(\s*'([A-Za-z0-9_]+)'`)
	rxInvokeMethod = regexp.MustCompile(`invokeMethod\(\s*'([A-Za-z0-9_]+)'`)
)

// TestTablaRPCCubreFlutter exige que TODOS los métodos que Flutter invoca
// existan en la tabla única de métodos RPC.
func TestTablaRPCCubreFlutter(t *testing.T) {
	lib := filepath.Join(raizFrontend, "lib")
	if _, err := os.Stat(lib); err != nil {
		t.Fatalf("no encuentro la carpeta frontend en %s: %v", lib, err)
	}

	faltantes := map[string][]string{}

	registrar := func(ruta, metodo string) {
		if metodosNativos[metodo] {
			return
		}
		if _, ok := tablaRPC[metodo]; ok {
			return
		}
		rel, err := filepath.Rel(lib, ruta)
		if err != nil {
			rel = ruta
		}
		faltantes[metodo] = append(faltantes[metodo], filepath.ToSlash(rel))
	}

	err := filepath.Walk(lib, func(ruta string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() || !strings.HasSuffix(ruta, ".dart") {
			return nil
		}
		datos, err := os.ReadFile(ruta)
		if err != nil {
			return err
		}
		// rpcCall es la única puerta al backend: aplica en todo lib/.
		for _, m := range rxRpcCall.FindAllSubmatch(datos, -1) {
			registrar(ruta, string(m[1]))
		}
		// invokeMethod directo solo cuenta sobre el canal del backend
		// (lib/core/backend_go/**): en el resto de lib/ hay otros canales
		// nativos (actualización, share intent, deep link) sin relación
		// con el RPC de Go.
		if strings.Contains(filepath.ToSlash(ruta), "core/backend_go/") {
			for _, m := range rxInvokeMethod.FindAllSubmatch(datos, -1) {
				registrar(ruta, string(m[1]))
			}
		}
		return nil
	})
	if err != nil {
		t.Fatalf("recorriendo el frontend: %v", err)
	}

	if len(faltantes) == 0 {
		return
	}
	metodos := make([]string, 0, len(faltantes))
	for metodo := range faltantes {
		metodos = append(metodos, metodo)
	}
	sort.Strings(metodos)
	var informe strings.Builder
	for _, metodo := range metodos {
		origenes := strings.Join(faltantes[metodo], ", ")
		informe.WriteString("\n  - " + metodo + " ← " + origenes)
	}
	t.Errorf(
		"Flutter llama %d método(s) que no están en internal/gobackend/rpc_tabla.go:%s",
		len(metodos), informe.String(),
	)
}

// TestTablaRPCMetodosCriticos fija por regression los métodos que estuvieron
// rotos en alguna plataforma (ver informe de desconexiones frontend↔backend).
func TestTablaRPCMetodosCriticos(t *testing.T) {
	criticos := []string{
		// existían pero no estaban en ningún dispatcher
		"getSearchConfig",
		"setDownloadProviderPriority",
		// iOS no los tenía en dispatchGomobile
		"enviarReporte",
		"liberarMemoria",
		// Android no tenía el export plano
		"descargarFuente",
		"borrarFuentes",
		// parámetro escalar: si cambia la forma, Flutter se rompe en silencio
		"cancelDownload",
		"resolveISRC",
	}
	for _, metodo := range criticos {
		if _, ok := tablaRPC[metodo]; !ok {
			t.Errorf("método crítico ausente de la tabla RPC: %s", metodo)
		}
	}
}

// TestManejadoresExtraenParametros comprueba la extracción de params que usan
// los manejadores con argumento único: es lo que hacía fallar a Android
// cuando el puente mandaba {"isrc":"…"} en vez del texto suelto.
func TestManejadoresExtraenParametros(t *testing.T) {
	// conTexto saca la clave del objeto params.
	var texto string
	manejador := conTexto("isrc", func(v string) string { texto = v; return "ok" })
	if res, err := manejador(map[string]interface{}{"isrc": "ES123"}); err != "" || res != "ok" || texto != "ES123" {
		t.Fatalf("conTexto: res=%v err=%q texto=%q", res, err, texto)
	}
	// Clave ausente → cadena vacía, no panic.
	texto = "marcador"
	_, _ = manejador(map[string]interface{}{})
	if texto != "" {
		t.Fatalf("conTexto con clave ausente debe dar vacío, dio %q", texto)
	}
	// paramStr convierte no-texto a su forma JSON (bool/número/objeto).
	if s := paramStr(map[string]interface{}{"a": true}, "a"); s != "true" {
		t.Fatalf("paramStr(bool) = %q", s)
	}
	if s := paramStr(map[string]interface{}{"a": 7.0}, "a"); s != "7" {
		t.Fatalf("paramStr(num) = %q", s)
	}
	// conEntero respeta el defecto y convierte string numérico.
	var entero int
	mE := conEntero("limit", 20, func(v int) string { entero = v; return "ok" })
	_, _ = mE(map[string]interface{}{})
	if entero != 20 {
		t.Fatalf("conEntero defecto = %d, esperaba 20", entero)
	}
	_, _ = mE(map[string]interface{}{"limit": "9"})
	if entero != 9 {
		t.Fatalf("conEntero(string) = %d, esperaba 9", entero)
	}
	// conJSON entrega el payload completo serializado.
	var payload string
	mJ := conJSON(func(v string) string { payload = v; return "ok" })
	_, _ = mJ(map[string]interface{}{"q": "hola"})
	if !strings.Contains(payload, `"q":"hola"`) {
		t.Fatalf("conJSON payload = %q", payload)
	}
	// Ruta completa: ping responde y un desconocido devuelve error.
	if res, err := DispatchRPC("ping", nil); err != "" || res != "pong" {
		t.Fatalf("ping = %v (%q)", res, err)
	}
	if _, err := DispatchRPC("metodoQueNoExiste", nil); err == "" {
		t.Fatal("un método desconocido debe devolver error")
	}
	if _, err := DispatchRPC("ping", map[string]interface{}{"x": 1}); err != "" {
		t.Fatalf("ping con params ignorables falló: %q", err)
	}
}
