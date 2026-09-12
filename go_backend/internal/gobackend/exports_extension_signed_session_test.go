package gobackend

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestNingunaExtensionEmbutidaDeclaraSesionFirmada es el guard que impide que
// vuelva el modal de Cloudflare al arrancar.
//
// El arranque de la app pedía provisionar la sesión firmada del gateway zarz
// para cada sandbox que declare `signedSession` en su manifest. Ese bootstrap
// contra api.zarz.moe devolvía VERIFY_REQUIRED y el challenge terminaba en el
// modal de Turnstile. Tras migrar Deezer (ARL), Tidal (token propio) y Qobuz
// (cuenta propia) al CDN directo y dejar Amazon como solo-metadata, ninguna
// fuente necesita el gateway: la lista de objetivos debe quedar VACÍA.
//
// Si alguien vuelve a declarar `signedSession` en una extensión embebida, este
// test falla y avisa que el modal regresaría.
func TestNingunaExtensionEmbutidaDeclaraSesionFirmada(t *testing.T) {
	extRegistry = nil
	reiniciarAjustesExtensiones()
	InitGlobalState()

	ids := signedSessionMaintenanceTargets("")
	if len(ids) != 0 {
		t.Fatalf("el arranque provisionaría sesiones del gateway para: %v", ids)
	}
}

// TestSinSesionFirmadaEnArranqueAndroid simula el orden de arranque de Android
// (InitGlobalState → InitExtensionSystem → LoadExtensionsFromDir) y verifica
// que en ningún paso aparece una sesión firmada, ni con un directorio en disco
// viejo: sin sesión no hay bootstrap, y sin bootstrap no hay modal.
func TestSinSesionFirmadaEnArranqueAndroid(t *testing.T) {
	extRegistry = nil
	reiniciarAjustesExtensiones()

	// 1. InitGlobalState: las extensiones embebidas son la fuente de verdad.
	state := InitGlobalState()
	if strings.Contains(state, `"error"`) {
		t.Fatalf("InitGlobalState failed: %s", state)
	}
	if !strings.Contains(state, "qobuz-web") {
		t.Fatalf("qobuz-web not registered: %s", state)
	}
	sb := signedSessionSandbox("qobuz-web")
	if sb == nil {
		t.Fatal("qobuz-web sandbox missing after InitGlobalState")
	}
	if sb.SignedSession != nil {
		t.Fatal("qobuz-web todavía trae signedSession embebido (volvería el modal de Cloudflare)")
	}

	// 2. Un directorio en disco viejo (manifest sin signedSession) no debe
	//    reintroducir la sesión ni clobbear el registro embebido.
	staleDir := t.TempDir()
	extSub := filepath.Join(staleDir, "qobuz-web")
	if err := os.MkdirAll(extSub, 0755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(extSub, "manifest.json"), []byte(`{"name":"qobuz-web"}`), 0644)
	os.WriteFile(filepath.Join(extSub, "index.js"), []byte(`function searchTracks(q,l){return[];}`), 0644)
	escaped := strings.ReplaceAll(staleDir, `\`, `\\`)

	r1 := InitExtensionSystem(`{"extensions_dir":"` + escaped + `","data_dir":"` + escaped + `"}`)
	if strings.Contains(r1, `"error"`) {
		t.Fatalf("InitExtensionSystem failed: %s", r1)
	}
	if sb := signedSessionSandbox("qobuz-web"); sb == nil {
		t.Fatal("qobuz-web sandbox missing after InitExtensionSystem")
	} else if sb.SignedSession != nil {
		t.Fatal("signedSession reintroducida tras InitExtensionSystem")
	}

	// 3. loadExtensionsFromDir: mismo criterio.
	r2 := LoadExtensionsFromDir(`{"dir_path":"` + escaped + `"}`)
	if strings.Contains(r2, `"error"`) {
		t.Fatalf("LoadExtensionsFromDir failed: %s", r2)
	}
	if sb := signedSessionSandbox("qobuz-web"); sb == nil {
		t.Fatal("qobuz-web sandbox missing after LoadExtensionsFromDir")
	} else if sb.SignedSession != nil {
		t.Fatal("signedSession reintroducida tras LoadExtensionsFromDir")
	}

	// 4. Y el bridge no produce ningún challenge real (ni toca la red): sin
	//    session configurada, la respuesta es un error limpio sin auth_url.
	res := GetPendingVerificationUrl(`{"extension_id":"qobuz-web"}`)
	if strings.Contains(res, `"auth_url":"http`) || strings.Contains(res, `"needsVerification":true`) {
		t.Fatalf("GetPendingVerificationUrl produjo un challenge real: %s", res)
	}
}

// TestLoadDirExtensionsIntoSkipsExisting verifies the loader never replaces a
// sandbox that already exists (the embedded copy stays the source of truth).
func TestLoadDirExtensionsIntoSkipsExisting(t *testing.T) {
	staleDir := t.TempDir()
	extSub := filepath.Join(staleDir, "deezer")
	os.MkdirAll(extSub, 0755)
	os.WriteFile(filepath.Join(extSub, "manifest.json"), []byte(`{"name":"deezer"}`), 0644)
	os.WriteFile(filepath.Join(extSub, "index.js"), []byte(`function searchTracks(q,l){return[];}`), 0644)

	extRegistry = nil
	reiniciarAjustesExtensiones()
	InitGlobalState()

	if sb := signedSessionSandbox("deezer"); sb == nil {
		t.Fatal("deezer sandbox missing after InitGlobalState")
	}
	_ = LoadExtensionsFromDir(`{"dir_path":"` + strings.ReplaceAll(staleDir, `\`, `\\`) + `"}`)
	if sb := signedSessionSandbox("deezer"); sb == nil {
		t.Fatal("deezer sandbox lost after LoadExtensionsFromDir with stale dir")
	}
}
