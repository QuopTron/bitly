// Regression del almacén persistente de las extensiones.
//
// El bug: un sandbox podía nacer con dataDir "." (así se registran las
// extensiones empaquetadas) y el host confirmar el directorio escribible
// después. Se actualizaba Sandbox.DataDir pero NO el Store, así que el almacén
// seguía escribiendo en el directorio de trabajo del proceso — en Android "/",
// no escribible — y os.WriteFile fallaba en silencio. La extensión logueaba
// "guardado" y el arranque siguiente leía vacío.
//
// Medido en el aparato con el libro de salud de clientes de ytmusic: sesión A
// "6 guardados", sesión B "nada guardado todavía".
//
// Lo que fijan estos tests:
//
//  1. SetDataDir mueve DataDir Y el Store.
//  2. Lo que una extensión guarda se lee desde otro sandbox (otro "arranque").
//  3. Sin repuntar, el Store no toca el directorio real (por esto existe).
package extensions

import (
	"os"
	"path/filepath"
	"testing"
)

// fuenteAlmacen usa la API real que ve una extensión, no el Store de Go: así el
// test cubre también que registerStorage exponga `storage`.
const fuenteAlmacen = `
function guardar(k, v) { storage.set(k, v); return true; }
function leer(k) { return storage.get(k) || null; }
`

func TestSetDataDirMueveElAlmacen(t *testing.T) {
	rt := NewRuntime()
	sb := rt.RegisterDeferred(fuenteAlmacen, "demo", "Demo", DefaultConfig(), ".")
	if sb == nil {
		t.Fatal("RegisterDeferred devolvió nil")
	}
	if sb.Store == nil {
		t.Fatal("el sandbox debería tener Store desde el registro")
	}
	antes := sb.Store.filePath

	dir := t.TempDir()
	sb.SetDataDir(dir)

	if sb.DataDir != dir {
		t.Errorf("DataDir = %q, se esperaba %q", sb.DataDir, dir)
	}
	if sb.Store.filePath == antes {
		t.Error("el Store siguió en el dataDir provisional: todo lo persistido se pierde")
	}
	if got := filepath.Dir(sb.Store.filePath); got != dir {
		t.Errorf("el Store quedó en %q, se esperaba %q", got, dir)
	}
}

// El bug de punta a punta: guardar y leer desde otro sandbox (el "arranque
// siguiente") sobre la misma carpeta tiene que devolver el valor.
func TestAlmacenPersisteEntreSandboxTrasRepuntar(t *testing.T) {
	dir := t.TempDir()
	cfg := DefaultConfig()

	rt1 := NewRuntime()
	sb1 := rt1.RegisterDeferred(fuenteAlmacen, "demo", "Demo", cfg, ".")
	sb1.SetDataDir(dir)
	if _, err := rt1.CallMethod("demo", "guardar", "persist:clientHealth", `{"visionos":123}`); err != nil {
		t.Fatalf("guardar: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "demo_store.json")); err != nil {
		t.Fatalf("no se escribió el almacén en %s: %v", dir, err)
	}

	rt2 := NewRuntime()
	sb2 := rt2.RegisterDeferred(fuenteAlmacen, "demo", "Demo", cfg, ".")
	sb2.SetDataDir(dir)
	res, err := rt2.CallMethod("demo", "leer", "persist:clientHealth")
	if err != nil {
		t.Fatalf("leer: %v", err)
	}
	if res != `{"visionos":123}` {
		t.Errorf("leer devolvió %#v, se esperaba el valor guardado", res)
	}
}

// El caso que era el bug, fijado para que quede claro por qué existe SetDataDir:
// sin repuntar, el Store escribe fuera del directorio real.
func TestAlmacenSinRepuntarNoLlegaAlDirectorioReal(t *testing.T) {
	dir := t.TempDir()

	rt := NewRuntime()
	sb := rt.RegisterDeferred(fuenteAlmacen, "sinrep", "SinRep", DefaultConfig(), ".")
	if got := sb.Store.filePath; got == filepath.Join(dir, "sinrep_store.json") {
		t.Fatalf("sin repuntar el Store no debería estar en %q", dir)
	}

	if _, err := rt.CallMethod("sinrep", "guardar", "k", "v"); err != nil {
		t.Fatalf("guardar: %v", err)
	}
	// El archivo cae en el CWD del proceso de test (que es "."): se limpia para
	// no dejar basura en el paquete.
	t.Cleanup(func() { os.Remove("sinrep_store.json") })

	if _, err := os.Stat(filepath.Join(dir, "sinrep_store.json")); err == nil {
		t.Error("sin repuntar no debería escribirse en el directorio real")
	}
}

// Un repuntado no puede perder lo que ya estuviera en memoria (el sandbox pudo
// escribir antes de que el host confirmara el directorio).
func TestRepointConservaLoQueYaEstabaEnMemoria(t *testing.T) {
	dir := t.TempDir()

	// Lo que ya estaba en disco (de un arranque anterior).
	previo := NewStorage(dir, "demo")
	previo.mu.Lock()
	previo.data["delDisco"] = "otro"
	previo.mu.Unlock()
	if err := previo.save(); err != nil {
		t.Fatalf("save: %v", err)
	}

	// El sandbox nace con "." y ya escribió algo antes de que el host confirme
	// el directorio real.
	s := NewStorage(".", "demo")
	s.mu.Lock()
	s.data["antes"] = "valor"
	s.mu.Unlock()

	s.Repoint(dir, "demo")

	s.mu.Lock()
	defer s.mu.Unlock()
	if s.data["antes"] != "valor" {
		t.Error("Repoint perdió el valor que estaba en memoria")
	}
	if s.data["delDisco"] != "otro" {
		t.Error("Repoint no trajo lo que ya había en disco")
	}
}
