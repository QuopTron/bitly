package gobackend

import (
	"fmt"
	"math/rand"
	"reflect"
	"strings"
	"testing"
)

// ═══════════════════════════════════════════════════════════════════════════
// El índice de deduplicación contra el barrido lineal
//
// El índice (search_stream_indice.go) es la versión rápida; esItemBusquedaDuplicado
// es la versión obvia y lineal. Acá se exige que den EXACTAMENTE el mismo
// buffer: si el índice se saltara un duplicado, "Todas" volvería a mostrar el
// mismo tema repetido; si marcara de más, se perdería un resultado.
//
// Se compara sobre items al azar con pocos nombres distintos a propósito: eso
// fuerza a que varios tracks compartan clave canónica (el caso que ejercita el
// grupo del índice y la tolerancia de duración) y a que los ISRC se repitan
// entre fuentes.
// ═══════════════════════════════════════════════════════════════════════════

// caminoIndiceAnexa corre el camino real de producción (anexarSearchStream).
func caminoIndiceAnexa(gen int64, lotes [][]FeedItemGo) []FeedItemGo {
	for _, lote := range lotes {
		anexarSearchStream(gen, lote)
	}
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	out := make([]FeedItemGo, len(currentSearchStream.items))
	copy(out, currentSearchStream.items)
	return out
}

// caminoLinealAnexa corre la versión de referencia: el barrido lineal item por
// item más la propagación de ISRC, exactamente como estaba antes del índice.
// Comparte con el camino rápido la REGLA de fusión (fusionarISRC) a propósito:
// lo que se compara acá es la decisión de "es duplicado", que es donde el índice
// puede equivocarse.
func caminoLinealAnexa(lotes [][]FeedItemGo) []FeedItemGo {
	buffer := []FeedItemGo{}
	for _, lote := range lotes {
		for _, item := range lote {
			if pos := posicionDuplicadoLineal(buffer, item); pos >= 0 {
				fusionarISRC(buffer, pos, item)
				continue
			}
			buffer = append(buffer, item)
		}
		propagarISRC(buffer)
	}
	return buffer
}

func TestIndiceDedup_CoincideConElBarridoLineal(t *testing.T) {
	for semilla := int64(1); semilla <= 25; semilla++ {
		rng := rand.New(rand.NewSource(semilla))
		lotes := lotesAzar(rng, 70)

		esperado := caminoLinealAnexa(lotes)

		gen := nuevaGeneracionDePrueba()
		obtenido := caminoIndiceAnexa(gen, lotes)

		if !reflect.DeepEqual(obtenido, esperado) {
			t.Fatalf("semilla %d: el índice y el barrido lineal no coinciden\n%s",
				semilla, describirDiferencia(esperado, obtenido))
		}
	}
}

// TestIndiceDedup_DeduplicaEntreLotes fija el comportamiento del índice a
// través del camino REAL (anexarSearchStream, lote por lote): el mismo tema
// llegando desde tres fuentes escritas distinto tiene que colapsar en uno, y
// una versión distinta (radio edit) tiene que sobrevivir aparte.
//
// Va por acá y no por esItemBusquedaDuplicado porque el índice se arma con el
// buffer ya acumulado: este es el único camino que prueba que un duplicado de
// un lote ANTERIOR se sigue reconociendo.
func TestIndiceDedup_DeduplicaEntreLotes(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	anexarSearchStream(gen, []FeedItemGo{
		{ID: "d1", Type: "track", Source: "deezer", Name: "One More Time",
			Artists: "Daft Punk", DurationMs: 320000, ISRC: "GBDUW0000059"},
	})
	anexarSearchStream(gen, []FeedItemGo{
		{ID: "y1", Type: "track", Source: "ytmusic-spotiflac", Name: "One More Time (Remastered)",
			Artists: "Daft Punk, Pharrell Williams", DurationMs: 320100},
	})
	anexarSearchStream(gen, []FeedItemGo{
		{ID: "t1", Type: "track", Source: "tidal-web", Name: "one more time",
			Artists: "Daft Punk", DurationMs: 320000, ISRC: "gbduw0000059"},
	})
	// Una versión corta de verdad: NO es el mismo track y se conserva.
	anexarSearchStream(gen, []FeedItemGo{
		{ID: "s1", Type: "track", Source: "soundcloud", Name: "One More Time (Radio Edit)",
			Artists: "Daft Punk", DurationMs: 200000},
	})

	items := caminoIndiceAnexa(gen, nil)
	if len(items) != 2 {
		t.Fatalf("esperaba 2 tracks (el tema + su radio edit), hay %d: %+v", len(items), items)
	}
	if items[0].ISRC != "GBDUW0000059" {
		t.Fatalf("el track conservado debe ser el que trae el ISRC: %q", items[0].ISRC)
	}
}

// TestDedupFusionaElISRCEnElTrackGuardado cubre el agujero que dejaba la
// identidad fuera de la UI: la fuente que NO publica ISRC (YouTube, SoundCloud)
// suele llegar primero, así que cuando después llega la que SÍ lo trae, el dedup
// la descarta como duplicado — y el ISRC se iba con ella. Ahora se queda en el
// track guardado, que es de donde lo lee (y lo persiste) la app.
func TestDedupFusionaElISRCEnElTrackGuardado(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	// 1) La versión sin ISRC primero: es la que se guarda.
	anexarSearchStream(gen, []FeedItemGo{
		{ID: "y", Type: "track", Source: "ytmusic-spotiflac", Name: "One More Time",
			Artists: "Daft Punk", DurationMs: 320000},
	})

	// 2) El mismo tema desde Deezer, con ISRC: se descarta, pero le deja el ISRC.
	anexarSearchStream(gen, []FeedItemGo{
		{ID: "d", Type: "track", Source: "deezer", Name: "One More Time (Remastered)",
			Artists: "Daft Punk, Pharrell Williams", DurationMs: 320100, ISRC: "GBDUW0000059"},
	})

	items := caminoIndiceAnexa(gen, nil)
	if len(items) != 1 {
		t.Fatalf("esperaba 1 item, hay %d: %+v", len(items), items)
	}
	if items[0].ID != "y" {
		t.Fatalf("debe quedar el que llegó primero: %q", items[0].ID)
	}
	if items[0].ISRC != "GBDUW0000059" {
		t.Fatalf("el ISRC del descartado no llegó al guardado: %q", items[0].ISRC)
	}
	// Y llega a la UI: el sondeo que lee Flutter (cada 80 ms) lleva el ISRC ya
	// fusionado. Sin esto el arreglo no serviría de nada.
	if p := leerPayload(t, GetSearchStreamResults()); len(p.Items) != 1 || p.Items[0].ISRC != "GBDUW0000059" {
		t.Fatalf("el ISRC fusionado no viaja en la respuesta: %+v", p.Items)
	}

	// 3) Como el buffer ya representa ese ISRC, un item posterior que lo traiga
	//    se reconoce por ISRC aunque escriba el título y la duración distinto
	//    (con ISRC en los dos lados manda el ISRC, ver esElMismoTrack).
	anexarSearchStream(gen, []FeedItemGo{
		{ID: "t", Type: "track", Source: "tidal-web", Name: "One More Time (Live at Coachella)",
			Artists: "Daft Punk", DurationMs: 400000, ISRC: "gbduw0000059"},
	})
	if got := caminoIndiceAnexa(gen, nil); len(got) != 1 {
		t.Fatalf("el mismo ISRC tiene que ser duplicado, hay %d items: %+v", len(got), got)
	}
}

// TestFusionarISRC_NoPisaUnISRCExistente: la fusión solo completa lo que falta.
// Si el guardado ya tiene ISRC, el que llegó no toca nada (y si el par fuera
// "el mismo track", esElMismoTrack ya resolvió por ISRC que no lo era).
func TestFusionarISRC_NoPisaUnISRCExistente(t *testing.T) {
	buffer := []FeedItemGo{{ID: "a", Type: "track", ISRC: "VIEJO1111111"}}

	if fusionarISRC(buffer, 0, FeedItemGo{ISRC: "NUEVO2222222"}) {
		t.Fatal("no debía pisar un ISRC existente")
	}
	if buffer[0].ISRC != "VIEJO1111111" {
		t.Fatalf("el ISRC quedó %q", buffer[0].ISRC)
	}

	// Sin ISRC en el que llega no hay nada que fusionar, y una posición fuera
	// de rango se ignora en vez de romper.
	if fusionarISRC(buffer, 0, FeedItemGo{ID: "b"}) {
		t.Fatal("un item sin ISRC no puede fusionar nada")
	}
	if fusionarISRC(buffer, 7, FeedItemGo{ISRC: "OTRO33333333"}) {
		t.Fatal("una posición fuera de rango no debe fusionar")
	}
}

// TestIndiceDedup_AnotaLosTracksQueEntranDespuesDelMapa fija un estado
// intermedio fácil de romper: el mapa de claves se arma la primera vez que hace
// falta comparar por identidad, y desde ese momento TODO track que entre tiene
// que quedar anotado en él, aunque traiga ISRC. Si no, el próximo item sin ISRC
// del mismo lote no lo encuentra y el mismo tema se cuela dos veces.
//
// La secuencia que llega a ese estado (todo dentro de un mismo lote, que es
// como llega cada fuente) es:
//
//	a) un track con ISRC;
//	b) el mismo tema sin ISRC -> duplicado: al comparar por identidad deja el
//	   mapa armado, y como se descarta, el buffer queda sin ningún track sin
//	   ISRC (o sea que la condición "hay tracks sin ISRC" sigue siendo falsa);
//	c) otro track, con ISRC propio y un tema distinto -> tiene que anotarse;
//	d) otra vez el tema de (c) sin ISRC -> duplicado de (c) por identidad.
func TestIndiceDedup_AnotaLosTracksQueEntranDespuesDelMapa(t *testing.T) {
	gen := nuevaGeneracionDePrueba()

	anexarSearchStream(gen, []FeedItemGo{
		{ID: "a", Type: "track", Name: "Uno", Artists: "A", DurationMs: 200000, ISRC: "AAAA11111111"},
		{ID: "b", Type: "track", Name: "Uno", Artists: "A", DurationMs: 200000},
		{ID: "c", Type: "track", Name: "Dos", Artists: "B", DurationMs: 300000, ISRC: "BBBB22222222"},
		{ID: "d", Type: "track", Name: "Dos", Artists: "B", DurationMs: 300000},
	})

	items := caminoIndiceAnexa(gen, nil)
	if len(items) != 2 {
		t.Fatalf("esperaba 2 tracks (uno por tema), hay %d: %+v", len(items), items)
	}
	if items[0].ID != "a" || items[1].ID != "c" {
		t.Fatalf("deben quedar los que traen el ISRC, quedaron %q y %q", items[0].ID, items[1].ID)
	}
}

// describirDiferencia señala el PRIMER item donde se separan los dos buffers
// (y si uno tiene items de más). Volcar los dos completos no se lee.
func describirDiferencia(esperado, obtenido []FeedItemGo) string {
	var b strings.Builder
	fmt.Fprintf(&b, "lineal: %d items, índice: %d items", len(esperado), len(obtenido))
	tope := len(esperado)
	if len(obtenido) < tope {
		tope = len(obtenido)
	}
	for i := 0; i < tope; i++ {
		if reflect.DeepEqual(esperado[i], obtenido[i]) {
			continue
		}
		fmt.Fprintf(&b, "\nprimer item distinto en [%d]\n  lineal:  %+v\n  índice:  %+v",
			i, esperado[i], obtenido[i])
		return b.String()
	}
	if len(esperado) > tope {
		fmt.Fprintf(&b, "\nsobra en el lineal: %+v", esperado[tope])
	} else if len(obtenido) > tope {
		fmt.Fprintf(&b, "\nsobra en el índice: %+v", obtenido[tope])
	}
	return b.String()
}

// lotesAzar arma lotes de items verosímiles: nombres, artistas, duraciones, ISRC
// y colecciones de un conjunto chico, para que las colisiones de identidad sean
// frecuentes y no un accidente raro.
func lotesAzar(rng *rand.Rand, cuantos int) [][]FeedItemGo {
	nombres := []string{
		"One More Time", "One More Time (Remastered)", "one more time",
		"Get Lucky", "Get Lucky (Radio Edit)", "Around the World",
	}
	artistas := []string{"Daft Punk", "Daft Punk, Pharrell Williams", "daft punk & Nile Rodgers", ""}
	duraciones := []int{0, 320000, 320100, 200000, 320000, 180500}
	isrcs := []string{"", "", "GBDUW0000059", "USUM71104766", ""}

	lotes := [][]FeedItemGo{}
	restantes := cuantos
	for restantes > 0 {
		tam := 1 + rng.Intn(8)
		if tam > restantes {
			tam = restantes
		}
		lote := make([]FeedItemGo, tam)
		for k := range lote {
			tipo := "track"
			switch rng.Intn(8) {
			case 0:
				tipo = "album"
			case 1:
				tipo = "artist"
			case 2:
				tipo = "playlist"
			}
			lote[k] = FeedItemGo{
				ID:         fmt.Sprintf("id-%d", rng.Intn(20)), // ids repetidos a propósito
				Type:       tipo,
				Name:       nombres[rng.Intn(len(nombres))],
				Artists:    artistas[rng.Intn(len(artistas))],
				DurationMs: duraciones[rng.Intn(len(duraciones))],
				ISRC:       isrcs[rng.Intn(len(isrcs))],
				Source:     fmt.Sprintf("fuente-%d", rng.Intn(4)),
			}
		}
		lotes = append(lotes, lote)
		restantes -= tam
	}
	return lotes
}
