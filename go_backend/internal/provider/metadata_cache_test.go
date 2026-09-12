package provider

import (
	"fmt"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// reiniciarEstadoPrecarga limpia el throttle de precarga (activo + marca de
// tiempo por proveedor). Sin esto, correr el paquete con -count>1 deja la
// segunda pasada dentro de precargaMinGap y la precarga legítimamente no corre.
func reiniciarEstadoPrecarga() {
	precargaMu.Lock()
	precargaActiva = map[string]bool{}
	precargaArranque = map[string]time.Time{}
	precargaMu.Unlock()
}

// providerDePrueba monta un ExtensionProvider con una extensión JS mínima que
// cuenta cuántas veces se llamó a cada método, para poder afirmar sobre la
// cantidad de round-trips reales (que es lo que la caché debe evitar).
func providerDePrueba(t *testing.T, name string) *ExtensionProvider {
	t.Helper()
	rt := extensions.NewRuntime()
	cfg := extensions.DefaultConfig()
	cfg.TimeoutMs = 30000
	script := `
var __llamadas = {};
function getTrack(id) {
  __llamadas["getTrack:" + id] = (__llamadas["getTrack:" + id] || 0) + 1;
  return { id: id, title: "Titulo " + id, artists: "Artista", album_name: "Album" };
}
function getAlbum(id) {
  __llamadas["getAlbum:" + id] = (__llamadas["getAlbum:" + id] || 0) + 1;
  return { id: id, name: "Album " + id, artists: "Artista" };
}
function searchTracks(q, limit) {
  __llamadas["searchTracks"] = (__llamadas["searchTracks"] || 0) + 1;
  var out = [];
  for (var i = 0; i < 4; i++) {
    out.push({ id: "t" + i, name: "Tema " + i, artists: "Artista", album_name: "Album" });
  }
  return out;
}
function contar(clave) { return __llamadas[clave] || 0; }
`
	if _, err := rt.RunJS(script, name, name, cfg, "."); err != nil {
		t.Fatalf("RunJS: %v", err)
	}
	return NewExtensionProvider(name, name, rt)
}

func llamadasDe(p *ExtensionProvider, clave string) int {
	res, err := p.runtime.CallMethod(p.extID, "contar", clave)
	if err != nil {
		return -1
	}
	if n, ok := res.(int64); ok {
		return int(n)
	}
	return -1
}

// TestCacheMetadataEvitaLlamadasRepetidas es el objetivo central: la segunda
// lectura de un detalle no debe tocar la extensión.
func TestCacheMetadataEvitaLlamadasRepetidas(t *testing.T) {
	LimpiarCacheMetadata()
	p := providerDePrueba(t, "cache-hit")

	primero, err := p.GetTrack("abc")
	if err != nil || primero == nil {
		t.Fatalf("primer GetTrack: %v", err)
	}
	segundo, err := p.GetTrack("abc")
	if err != nil || segundo == nil {
		t.Fatalf("segundo GetTrack: %v", err)
	}

	if n := llamadasDe(p, "getTrack:abc"); n != 1 {
		t.Fatalf("la extensión se llamó %d veces, se esperaba 1 (la caché no funcionó)", n)
	}
	if primero.Title != segundo.Title || primero.ID != segundo.ID {
		t.Fatalf("el resultado cacheado difiere: %+v vs %+v", primero, segundo)
	}
}

// TestCacheMetadataSeparaPorId comprueba que no se sirve el detalle de un item
// para otro (claves distintas).
func TestCacheMetadataSeparaPorId(t *testing.T) {
	LimpiarCacheMetadata()
	p := providerDePrueba(t, "cache-ids")

	if _, err := p.GetTrack("uno"); err != nil {
		t.Fatalf("GetTrack uno: %v", err)
	}
	otro, err := p.GetTrack("dos")
	if err != nil || otro == nil {
		t.Fatalf("GetTrack dos: %v", err)
	}
	if otro.ID != "dos" {
		t.Fatalf("se sirvió el item equivocado: %q", otro.ID)
	}
	if n := llamadasDe(p, "getTrack:dos"); n != 1 {
		t.Fatalf("getTrack:dos se llamó %d veces, se esperaba 1", n)
	}
}

// TestCacheMetadataNoSeComparteMutable verifica que la caché entrega copias:
// un consumidor que modifique el mapa no debe corromper las respuestas
// siguientes servidas desde caché.
func TestCacheMetadataNoSeComparteMutable(t *testing.T) {
	LimpiarCacheMetadata()
	p := providerDePrueba(t, "cache-mutable")

	key := claveCacheMetadata(p.extID, "getTrack", []interface{}{"mut"})
	if _, err := p.callOp("", "getTrack", "mut"); err != nil {
		t.Fatalf("callOp: %v", err)
	}
	copia, ok := leerCacheMetadata("detalle", key)
	if !ok {
		t.Fatal("no se guardó en caché")
	}
	if m, ok := copia.(map[string]interface{}); ok {
		m["title"] = "CORROMPIDO"
	}

	otra, ok := leerCacheMetadata("detalle", key)
	if !ok {
		t.Fatal("no se pudo releer la caché")
	}
	if m, ok := otra.(map[string]interface{}); ok {
		if m["title"] == "CORROMPIDO" {
			t.Fatal("la caché compartió la estructura mutable: el valor quedó corrompido")
		}
	}
}

// TestClasificacionDeMetodos comprueba que solo se cachea metadata de lectura y
// que las descargas/streams quedan fuera (no deben servirse de caché).
func TestClasificacionDeMetodos(t *testing.T) {
	cacheables := []string{"getTrack", "getAlbum", "getArtist", "getPlaylist", "searchTracks", "customSearch", "getHomeFeed"}
	for _, m := range cacheables {
		if _, ok := bucketCacheMetadata(m); !ok {
			t.Errorf("se esperaba que %q fuera cacheable", m)
		}
	}
	noCacheables := []string{"getDownloadUrl", "download", "getStreamUrl", "checkAvailability", "getLyrics"}
	for _, m := range noCacheables {
		if _, ok := bucketCacheMetadata(m); ok {
			t.Errorf("%q NO debe cachearse (resultado dependiente del momento)", m)
		}
	}
}

// TestClaveCacheMetadataEstable comprueba que el mismo pedido produce la misma
// clave aunque el mapa de opciones venga en distinto orden.
func TestClaveCacheMetadataEstable(t *testing.T) {
	a := map[string]interface{}{"limit": 10, "filter": "song"}
	b := map[string]interface{}{"filter": "song", "limit": 10}
	ka := claveCacheMetadata("qobuz-web", "customSearch", []interface{}{"queen", a})
	kb := claveCacheMetadata("qobuz-web", "customSearch", []interface{}{"queen", b})
	if ka != kb {
		t.Fatalf("la clave no es estable:\n %s\n %s", ka, kb)
	}
	kc := claveCacheMetadata("deezer", "customSearch", []interface{}{"queen", a})
	if ka == kc {
		t.Fatal("proveedores distintos no deben compartir clave")
	}
}

// TestPrecargaCalientaLaCache verifica que adelantar el detalle deja el item en
// caché sin que el usuario lo haya abierto, y que el listado de ids se recorta.
func TestPrecargaCalientaLaCache(t *testing.T) {
	LimpiarCacheMetadata()
	reiniciarEstadoPrecarga()
	defer reiniciarEstadoPrecarga()
	p := providerDePrueba(t, "precache")

	reg := NewRegistry()
	reg.Register(p)

	encolados := reg.PrecargarDetalle("precache", "getTrack", []string{"p1", "p2", "p3", "p4"})
	if encolados != 4 {
		t.Fatalf("se esperaban 4 ids encolados, hubo %d", encolados)
	}

	// Se cuentan las llamadas DE ESTE proveedor (no el tamaño de la caché
	// global, que es compartida por todo el proceso y puede traer entradas de
	// otras pruebas o de goroutines anteriores todavía en vuelo).
	ids := []string{"p1", "p2", "p3", "p4"}
	calentados := 0
	deadline := time.Now().Add(4 * time.Second)
	for time.Now().Before(deadline) {
		calentados = 0
		for _, id := range ids {
			if llamadasDe(p, "getTrack:"+id) > 0 {
				calentados++
			}
		}
		if calentados >= maxPrecargaPorBusqueda {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if calentados < 1 {
		t.Fatalf("la precarga no calentó ningún detalle")
	}
	if calentados > maxPrecargaPorBusqueda {
		t.Fatalf("se calentaron %d items, el tope es %d", calentados, maxPrecargaPorBusqueda)
	}
	// Y lo calentado debe haber quedado servible desde caché.
	if _, ok := leerCacheMetadata("detalle", claveCacheMetadata(p.extID, "getTrack", []interface{}{"p1"})); !ok {
		t.Errorf("el detalle precargado no quedó en la caché")
	}
}

// TestPrecargaIgnoraMetodosNoCacheables evita que un id de descarga entre a la
// caché de metadata por la puerta de la precarga.
func TestPrecargaIgnoraMetodosNoCacheables(t *testing.T) {
	LimpiarCacheMetadata()
	reiniciarEstadoPrecarga()
	defer reiniciarEstadoPrecarga()
	p := providerDePrueba(t, "precache-guard")
	reg := NewRegistry()
	reg.Register(p)

	if n := reg.PrecargarDetalle("precache-guard", "getDownloadUrl", []string{"x"}); n != 0 {
		t.Fatalf("PrecargarDetalle debió rechazar un método no cacheable, devolvió %d", n)
	}
	time.Sleep(600 * time.Millisecond)
	if n := EstadisticasCacheMetadata()["detalle"]; n != 0 {
		t.Fatalf("se cacheó algo con un método no cacheable: %d entradas", n)
	}
}

// TestBusquedaPrecalientaResultados comprueba el camino automático: al buscar,
// el detalle de los primeros resultados queda adelantado.
func TestBusquedaPrecalientaResultados(t *testing.T) {
	LimpiarCacheMetadata()
	reiniciarEstadoPrecarga()
	defer reiniciarEstadoPrecarga()
	p := providerDePrueba(t, "precache-search")

	tracks, err := p.SearchTracks("lo que sea", 4)
	if err != nil || len(tracks) == 0 {
		t.Fatalf("SearchTracks: %v (len=%d)", err, len(tracks))
	}
	if n := llamadasDe(p, "searchTracks"); n != 1 {
		t.Fatalf("searchTracks se llamó %d veces, se esperaba 1", n)
	}

	// Los resultados de la búsqueda son t0..t3; se comprueba que este proveedor
	// recibió el getTrack de alguno por la precarga automática.
	deadline := time.Now().Add(4 * time.Second)
	for time.Now().Before(deadline) {
		for i := 0; i < 4; i++ {
			if llamadasDe(p, fmt.Sprintf("getTrack:t%d", i)) > 0 {
				return
			}
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("la búsqueda no precalentó ningún detalle")
}

// TestCacheBusquedaSeReutiliza comprueba que repetir la misma búsqueda no
// vuelve a la extensión.
func TestCacheBusquedaSeReutiliza(t *testing.T) {
	LimpiarCacheMetadata()
	p := providerDePrueba(t, "cache-search")

	if _, err := p.SearchTracks("repetida", 4); err != nil {
		t.Fatalf("primera búsqueda: %v", err)
	}
	if _, err := p.SearchTracks("repetida", 4); err != nil {
		t.Fatalf("segunda búsqueda: %v", err)
	}
	if n := llamadasDe(p, "searchTracks"); n != 1 {
		t.Fatalf("searchTracks se llamó %d veces, se esperaba 1 (caché de búsqueda)", n)
	}
}

// TestEstadisticasYLimpiar prueba la superficie de diagnóstico/ajustes.
func TestEstadisticasYLimpiar(t *testing.T) {
	LimpiarCacheMetadata()
	p := providerDePrueba(t, "stats")
	if _, err := p.GetAlbum("alb1"); err != nil {
		t.Fatalf("GetAlbum: %v", err)
	}
	if got := EstadisticasCacheMetadata()["detalle"]; got == 0 {
		t.Fatalf("no se registró ninguna entrada de detalle")
	}
	LimpiarCacheMetadata()
	for bucket, n := range EstadisticasCacheMetadata() {
		if n != 0 {
			t.Errorf("bucket %s quedó con %d entradas tras limpiar", bucket, n)
		}
	}
}

// TestCacheMetadataNoGuardaNil evita enmascarar la recuperación de un
// proveedor en cooldown (cuyo callOp devuelve nil).
func TestCacheMetadataNoGuardaNil(t *testing.T) {
	LimpiarCacheMetadata()
	guardarCacheMetadata("detalle", "alguna-clave", nil)
	if _, ok := leerCacheMetadata("detalle", "alguna-clave"); ok {
		t.Fatal("se guardó un nil en la caché de metadata")
	}
	_ = fmt.Sprint()
}
