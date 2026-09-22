package gobackend

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// proveedorFalso es un doble mínimo de un proveedor NATIVO (el camino que no
// pasa por una extensión), para poder decidir qué contesta la búsqueda: error o
// una respuesta válida (posiblemente vacía). El resto de los métodos existe
// solo para cumplir la interfaz.
type proveedorFalso struct {
	nombre string
	err    error
	tracks []provider.TrackResult
}

func (p *proveedorFalso) Name() string { return p.nombre }

func (p *proveedorFalso) SearchTracks(string, int) ([]provider.TrackResult, error) {
	return p.tracks, p.err
}

func (p *proveedorFalso) SearchAlbums(string, int) ([]provider.AlbumResult, error) {
	return nil, p.err
}

func (p *proveedorFalso) SearchArtists(string, int) ([]provider.ArtistResult, error) {
	return nil, p.err
}

func (p *proveedorFalso) SearchPlaylists(string, int) ([]provider.PlaylistResult, error) {
	return nil, p.err
}

func (p *proveedorFalso) GetTrack(string) (*provider.TrackResult, error) { return nil, nil }
func (p *proveedorFalso) GetTrackByISRC(string) (*provider.TrackResult, error) {
	return nil, nil
}
func (p *proveedorFalso) GetAlbum(string) (*provider.AlbumResult, error)   { return nil, nil }
func (p *proveedorFalso) GetArtist(string) (*provider.ArtistResult, error) { return nil, nil }
func (p *proveedorFalso) GetStreamURL(string, string) (string, error)      { return "", nil }

// ── La distinción que se agrega ────────────────────────────────────────────

// TestSearchProviderItems_FuenteCaidaEsFallo: si la fuente no contesta, la
// búsqueda tiene que poder decirlo. Antes esto devolvía solo la lista vacía,
// indistinguible de "no encontré nada", y la UI remataba en "sin resultados".
func TestSearchProviderItems_FuenteCaidaEsFallo(t *testing.T) {
	p := &proveedorFalso{nombre: "test-caido-provider", err: errors.New("connection refused")}

	items, fallo := searchProviderItems(p, "canserbero", 20, "tracks")

	if !fallo {
		t.Fatal("una fuente que devuelve error debe reportarse como fallida")
	}
	if len(items) != 0 {
		t.Fatalf("no debía haber items, hay %d", len(items))
	}
}

// TestSearchProviderItems_VacioLegitimoNoEsFallo: la fuente contestó "no tengo
// nada". Eso SÍ es "sin resultados" y no puede marcarse como fallo (si no, el
// usuario vería un error y un reintento por una búsqueda que funcionó bien).
func TestSearchProviderItems_VacioLegitimoNoEsFallo(t *testing.T) {
	p := &proveedorFalso{nombre: "test-vacio-provider"}

	items, fallo := searchProviderItems(p, "consulta sin resultados", 20, "tracks")

	if fallo {
		t.Fatal("una respuesta válida sin coincidencias NO es un fallo")
	}
	if len(items) != 0 {
		t.Fatalf("no debía haber items, hay %d", len(items))
	}
}

// TestSearchProviderItems_HayResultadosNoEsFallo: con resultados, obviamente
// tampoco hay fallo (la lista no está vacía, así que la UI muestra canciones).
func TestSearchProviderItems_HayResultadosEsRespuesta(t *testing.T) {
	p := &proveedorFalso{
		nombre: "test-ok-provider",
		tracks: []provider.TrackResult{{ID: "1", Title: "Canserbero", Artist: "Canserbero"}},
	}

	items, fallo := searchProviderItems(p, "canserbero", 20, "tracks")

	if fallo {
		t.Fatal("una búsqueda con resultados no es un fallo")
	}
	if len(items) != 1 {
		t.Fatalf("esperaba 1 item, hay %d", len(items))
	}
}

// TestSearchProviderItems_FuenteEnfriadaEsFallo: al saltarse la consulta por
// cooldown no se le preguntó a la fuente, así que no se puede afirmar que no
// tenga resultados. Nótese que el proveedor está SANO (no devuelve error): lo
// único que cambia es la marca de cooldown.
func TestSearchProviderItems_FuenteEnfriadaEsFallo(t *testing.T) {
	// "429" es uno de los marcadores que activan el cooldown (ver
	// cooldown_status.go); sin un texto así, MarkOpError no enfría nada.
	const nombre = "test-enfriado-provider"
	cooldown.MarkOpError(nombre, "search", "429 too many requests")
	// No se deja el cooldown puesto: es estado global del paquete.
	defer cooldown.MarkOpOk(nombre, "search")
	if !cooldown.IsCooledOp(nombre, "search") {
		t.Fatal("el cooldown debía activarse: \"429\" enfría la op search")
	}

	p := &proveedorFalso{nombre: nombre} // sano, pero no se llega a consultar
	if _, fallo := searchProviderItems(p, "cualquiera", 20, "tracks"); !fallo {
		t.Fatal("una fuente salteada por cooldown debe contar como no respondida")
	}
}

// ── Estado por sesión que viaja en el sondeo ──────────────────────────────

type payloadConFuentes struct {
	Items     []FeedItemGo `json:"items"`
	Done      bool         `json:"done"`
	Fallidas  []string     `json:"fallidas"`
	FuentesOk int          `json:"fuentes_ok"`
}

func leerPayloadFuentes(t *testing.T, raw string) payloadConFuentes {
	t.Helper()
	var p payloadConFuentes
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		t.Fatalf("respuesta no deserializable: %v (%q)", err, raw)
	}
	return p
}

// TestStreamFuentes_CuentaYNoRepite: el sondeo tiene que traer qué fuentes
// respondieron y cuáles no, sin contar dos veces a la misma.
func TestStreamFuentes_CuentaYNoRepite(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	registrarProveedorStream(gen, "deezer", false)
	registrarProveedorStream(gen, "apple-music", false)
	registrarProveedorStream(gen, "tidal-web", true)
	registrarProveedorStream(gen, "tidal-web", true) // repetida: no cuenta doble

	p := leerPayloadFuentes(t, GetSearchStreamResults())
	if p.FuentesOk != 2 {
		t.Fatalf("fuentes_ok = %d, esperaba 2", p.FuentesOk)
	}
	if len(p.Fallidas) != 1 || p.Fallidas[0] != "tidal-web" {
		t.Fatalf("fallidas = %v, esperaba [tidal-web]", p.Fallidas)
	}
}

// TestStreamFuentes_ListaVaciaNoEsNull: el contrato promete una lista, y un
// `null` en vez de `[]` ya rompió contratos antes.
func TestStreamFuentes_ListaVaciaNoEsNull(t *testing.T) {
	nuevaGeneracionDePrueba()

	if raw := GetSearchStreamResults(); !strings.Contains(raw, `"fallidas":[]`) {
		t.Fatalf("esperaba \"fallidas\":[] en la respuesta, salió: %s", raw)
	}
}

// TestStreamFuentes_IgnoraGeneracionVieja: si el usuario ya buscó otra cosa, la
// anotación de la búsqueda abandonada no puede ensuciar la nueva (si no, una
// query reciente podría quedarse con la lista de fallidas de la anterior).
func TestStreamFuentes_IgnoraGeneracionVieja(t *testing.T) {
	vieja := nuevaGeneracionDePrueba()
	nueva := nuevaGeneracionDePrueba()

	registrarProveedorStream(vieja, "qobuz-web", true)
	registrarProveedorStream(nueva, "deezer", false)

	p := leerPayloadFuentes(t, GetSearchStreamResults())
	if len(p.Fallidas) != 0 {
		t.Fatalf("la anotación vieja se filtró: %v", p.Fallidas)
	}
	if p.FuentesOk != 1 {
		t.Fatalf("fuentes_ok = %d, esperaba 1", p.FuentesOk)
	}
}

// TestStreamFuentes_AlLlegarItemsNoSePierdeElEstadoPorFuente: el caché de
// serialización del sondeo se invalida al anotar una fuente; este test fija que
// no se invalide de MÁS (que el estado siga visible cuando llegan items).
func TestStreamFuentes_EstadoVisibleJuntoConItems(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	registrarProveedorStream(gen, "deezer", false)
	anexarSearchStream(gen, []FeedItemGo{{ID: "1", Type: "track", Name: "Uno"}})
	registrarProveedorStream(gen, "amazon", true)

	p := leerPayloadFuentes(t, GetSearchStreamResults())
	if len(p.Items) != 1 {
		t.Fatalf("esperaba 1 item, hay %d", len(p.Items))
	}
	if p.FuentesOk != 1 || len(p.Fallidas) != 1 {
		t.Fatalf("estado por fuente perdido: ok=%d fallidas=%v", p.FuentesOk, p.Fallidas)
	}
}
