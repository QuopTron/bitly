package gobackend

import (
	"encoding/json"
	"testing"
)

type payloadStream struct {
	Items      []FeedItemGo `json:"items"`
	Done       bool         `json:"done"`
	Generation int64        `json:"generation"`
}

// nuevaGeneracionDePrueba deja el buffer del stream en una generación limpia y
// devuelve su número. Usa el mismo camino que SearchStream (que no se puede
// llamar aquí porque requiere el registro de proveedores).
func nuevaGeneracionDePrueba() int64 {
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	currentSearchStream.generation++
	currentSearchStream.items = nil
	currentSearchStream.done = false
	currentSearchStream.fallidas = nil
	currentSearchStream.fuentesOk = 0
	currentSearchStream.jsonCache = ""
	return currentSearchStream.generation
}

func leerPayload(t *testing.T, raw string) payloadStream {
	t.Helper()
	var p payloadStream
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		t.Fatalf("respuesta no deserializable: %v (%q)", err, raw)
	}
	return p
}

// TestStreamResults_ReutilizaJSONSinCambios cubre el arreglo del sondeo:
// Flutter consulta cada 80 ms y el camino viejo copiaba y serializaba la lista
// completa en cada consulta aunque no hubiera llegado nada. Ahora se reutiliza
// la cadena, y lo que se verifica acá es lo que puede romper esa reutilización:
// que un cambio real SÍ se vea.
func TestStreamResults_ReutilizaJSONSinCambios(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	anexarSearchStream(gen, []FeedItemGo{
		{ID: "1", Type: "track", Name: "Uno", Artists: "A"},
	})

	primera := GetSearchStreamResults()
	segunda := GetSearchStreamResults()
	if primera != segunda {
		t.Fatalf("dos sondeos sin cambios deben devolver lo mismo\n1: %s\n2: %s", primera, segunda)
	}
	p := leerPayload(t, primera)
	if len(p.Items) != 1 || p.Items[0].ID != "1" {
		t.Fatalf("payload inesperado: %+v", p)
	}
	if p.Done {
		t.Fatal("no debía estar done todavía")
	}
}

// TestStreamResults_InvalidaAlLlegarItems: un lote nuevo tiene que aparecer en
// el sondeo siguiente (si el caché no se invalidara, la UI nunca vería el
// resto de los resultados).
func TestStreamResults_InvalidaAlLlegarItems(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	anexarSearchStream(gen, []FeedItemGo{{ID: "1", Type: "track", Name: "Uno"}})
	antes := leerPayload(t, GetSearchStreamResults())

	anexarSearchStream(gen, []FeedItemGo{{ID: "2", Type: "track", Name: "Dos"}})
	despues := leerPayload(t, GetSearchStreamResults())

	if len(despues.Items) != 2 {
		t.Fatalf("el lote nuevo no apareció: %d items", len(despues.Items))
	}
	if len(antes.Items) != 1 {
		t.Fatalf("el primer sondeo debía traer 1 item, trajo %d", len(antes.Items))
	}
}

// TestStreamResults_InvalidaAlTerminar: `done` viaja dentro de la respuesta, así
// que al marcar el fin de la búsqueda el caché tiene que caer — si no, Flutter
// seguiría sondeando para siempre.
func TestStreamResults_InvalidaAlTerminar(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	anexarSearchStream(gen, []FeedItemGo{{ID: "1", Type: "track", Name: "Uno"}})
	if leerPayload(t, GetSearchStreamResults()).Done {
		t.Fatal("no debía estar done")
	}

	currentSearchStream.mu.Lock()
	currentSearchStream.done = true
	currentSearchStream.jsonCache = ""
	currentSearchStream.mu.Unlock()

	if !leerPayload(t, GetSearchStreamResults()).Done {
		t.Fatal("done no llegó al sondeo: el caché no se invalidó")
	}
}

// TestStreamResults_NoDuplicaItems: el dedup por identidad sigue mandando
// (el caché no debe esconder ni duplicar nada).
func TestStreamResults_NoDuplicaItems(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	item := FeedItemGo{ID: "1", Type: "track", Name: "Uno", Artists: "A", DurationMs: 200000}
	anexarSearchStream(gen, []FeedItemGo{item})
	anexarSearchStream(gen, []FeedItemGo{item})

	if p := leerPayload(t, GetSearchStreamResults()); len(p.Items) != 1 {
		t.Fatalf("esperaba 1 item, hay %d", len(p.Items))
	}
}

// TestPropagarISRC_ReportaCambios: el retorno booleano es lo que decide si se
// tira la respuesta serializada, así que no puede mentir.
func TestPropagarISRC_ReportaCambios(t *testing.T) {
	sinISRC := FeedItemGo{ID: "1", Type: "track", Name: "Uno", Artists: "A", DurationMs: 200000}
	conISRC := FeedItemGo{ID: "2", Type: "track", Name: "Uno", Artists: "A", DurationMs: 200000, ISRC: "USABC1234567"}

	items := []FeedItemGo{sinISRC, conISRC}
	if !propagarISRC(items) {
		t.Fatal("debía reportar que completó un ISRC")
	}
	if items[0].ISRC != conISRC.ISRC {
		t.Fatalf("ISRC no propagado: %q", items[0].ISRC)
	}
	// Segunda pasada: ya no hay nada que completar.
	if propagarISRC(items) {
		t.Fatal("la segunda pasada no debía reportar cambios")
	}
}
