package gobackend

import "strings"

// ─────────────────────────────────────────────────────────────────────────
// ÍNDICE DE DEDUPLICACIÓN DE LA BÚSQUEDA EN VIVO
//
// Qué problema resuelve. anexarSearchStream comparaba cada item nuevo contra
// TODO el buffer ya recibido, y por cada par recalculaba las claves de
// identidad (nombre y artista normalizados, con la limpieza de coletillas del
// título). Con n items eso es O(n²) comparaciones Y O(n²) normalizaciones de
// texto: medido, 120 items costaban 21 veces más que 20 (203 µs contra 9,6 µs)
// y con ocho fuentes respondiendo ese trabajo caía encima del hilo que arma la
// respuesta de búsqueda.
//
// El índice resuelve el duplicado en O(1) para el caso normal:
//
//   - las colecciones (álbum/artista/playlist) van por type+id;
//   - los tracks con ISRC van por ISRC, que es la llave exacta;
//   - el respaldo por identidad (nombre+artista normalizados y duración) mira
//     solo los pocos items que comparten clave canónica, no todos.
//
// Y cuando un item se descarta por ser duplicado, su ISRC no se tira: se le
// pasa al track que ya estaba guardado si le faltaba (ver fusionarISRC).
//
// Lo importante del diseño es CUÁNDO se normaliza un texto, porque normalizar
// es caro (minúsculas, acentos, quitar coletillas, rearmar espacios: ~1 µs por
// nombre). La clave canónica se calcula:
//
//   - una sola vez por item, no una al comparar y otra al registrar;
//   - y solo cuando el respaldo por identidad puede dictaminar algo. Con ISRC
//     en los dos lados manda el ISRC; el respaldo solo decide entre un item y
//     un track del buffer que NO traiga ISRC. Mientras el buffer y lo que entra
//     sean todo con ISRC, no se normaliza absolutamente nada (comparar con
//     materializar siempre la clave era MÁS LENTO que el barrido original en
//     ese caso: 565 µs contra 203 µs, y de ahí que el mapa se arme perezoso).
//
// Se construye por lote en vez de mantenerse entre lotes a propósito: un índice
// persistente tendría que resetearse con cada búsqueda y, sobre todo, podría
// quedar desactualizado cuando propagarISRC() completa el ISRC de un item ya
// guardado. Con una pasada por lote el total es O(k·n) con k = fuentes que
// responden (~8-10), no O(n²), y el índice siempre refleja el buffer tal como
// está.
//
// [esItemBusquedaDuplicado] sigue siendo la versión lineal de referencia; hay
// un test que exige que los dos caminos den exactamente el mismo buffer.
// ─────────────────────────────────────────────────────────────────────────

type indiceBusqueda struct {
	// isrcs guarda el ISRC -> POSICIÓN del primer track del buffer que lo trae
	// (no solo si está: la posición es la que decide a quién se le fusiona el
	// ISRC de un duplicado, y tiene que ser la misma que elegiría el barrido
	// lineal: la primera del buffer).
	isrcs       map[string]int
	colecciones map[string]struct{}

	// porClave guarda las POSICIONES de los tracks en el buffer, en orden de
	// aparición: el barrido interno recorre este grupo en vez de la lista
	// entera, y al ir en orden de posición elige el mismo candidato que el
	// doble barrido original. Es perezoso (ver porClaveDeFacto): nil mientras
	// no haga falta comparar por identidad.
	porClave map[string][]int

	// hayTrack / haySinISRC son la puerta del respaldo por identidad: mientras
	// el buffer sea todo con ISRC, un item con ISRC no puede empatar con nada que
	// ya esté (con ISRC en ambos lados manda el ISRC).
	//
	// haySinISRC es CONSERVADOR: una fusión puede completarle el ISRC al último
	// track que no lo tenía y la bandera queda en true. Solo hace trabajar de
	// más —una normalización y una búsqueda de grupo— nunca da un veredicto
	// equivocado, porque el mapa de claves se mantiene exacto igual.
	hayTrack   bool // el buffer tiene al menos un track
	haySinISRC bool // y (alguna vez) al menos uno de ellos sin ISRC
}

// claveISRC normaliza el ISRC igual que esElMismoTrack (que compara con
// EqualFold sobre el texto recortado), para que el índice y el predicado no
// puedan discrepar. Los ISRC reales ya vienen en mayúsculas, así que el atajo
// ASCII evita reconstruir la cadena en el caso normal.
func claveISRC(isrc string) string {
	recortado := strings.TrimSpace(isrc)
	for i := 0; i < len(recortado); i++ {
		if recortado[i] >= 'a' && recortado[i] <= 'z' {
			return strings.ToUpper(recortado)
		}
	}
	return recortado
}

// nuevoIndiceBusqueda arma el índice del buffer ya acumulado. No normaliza
// ningún nombre: eso queda para el momento en que haga falta.
func nuevoIndiceBusqueda(items []FeedItemGo) *indiceBusqueda {
	ix := &indiceBusqueda{
		isrcs:       make(map[string]int, len(items)),
		colecciones: make(map[string]struct{}, len(items)),
	}
	for i, item := range items {
		if item.Type != "track" {
			ix.colecciones[item.Type+"\x00"+item.ID] = struct{}{}
			continue
		}
		ix.hayTrack = true
		if item.ISRC != "" {
			clave := claveISRC(item.ISRC)
			if _, ya := ix.isrcs[clave]; !ya {
				ix.isrcs[clave] = i
			}
		} else {
			ix.haySinISRC = true
		}
	}
	return ix
}

// agregar anexa a `buffer` los items de `nuevos` que todavía no estaban y
// devuelve el buffer resultante.
func (ix *indiceBusqueda) agregar(buffer []FeedItemGo, nuevos []FeedItemGo) []FeedItemGo {
	for _, item := range nuevos {
		if item.Type != "track" {
			clave := item.Type + "\x00" + item.ID
			if _, dup := ix.colecciones[clave]; dup {
				continue
			}
			ix.colecciones[clave] = struct{}{}
			buffer = append(buffer, item)
			continue
		}
		buffer = ix.agregarTrack(buffer, item)
	}
	return buffer
}

// agregarTrack resuelve un track: duplicado (y fusión de la identidad que traía)
// o nuevo.
func (ix *indiceBusqueda) agregarTrack(buffer []FeedItemGo, item FeedItemGo) []FeedItemGo {
	// El match por ISRC es la llave exacta y sale de un mapa, así que se consulta
	// siempre. El respaldo por identidad normaliza el nombre —caro— y solo se
	// paga cuando puede dictaminar algo: con ISRC en los dos lados manda el ISRC,
	// así que únicamente puede empatar contra un track del buffer que NO lo traiga
	// (y al revés). Una vez armado el mapa hay que anotar cada track en él.
	posISRC := -1
	if item.ISRC != "" {
		if pos, ok := ix.isrcs[claveISRC(item.ISRC)]; ok {
			posISRC = pos
		}
	}
	posClave := -1
	var (
		clave  string
		grupos map[string][]int
	)
	if ix.porClave != nil ||
		(item.ISRC == "" && ix.hayTrack) ||
		(item.ISRC != "" && ix.haySinISRC) {
		clave = claveNombre(item.Name, item.Artists)
		grupos = ix.porClaveDeFacto(buffer)
		posClave = ix.posicionQueEmpata(grupos[clave], buffer, item)
	}

	// El duplicado es el PRIMERO del buffer que empata por cualquiera de los dos
	// caminos —el mismo que elegiría el barrido lineal posición por posición— y
	// es esa posición la que recibe el ISRC del item descartado.
	duplicado := posISRC
	if posClave >= 0 && (duplicado < 0 || posClave < duplicado) {
		duplicado = posClave
	}
	if duplicado >= 0 {
		if fusionarISRC(buffer, duplicado, item) {
			// El buffer pasa a representar ese ISRC desde esa posición: un item
			// posterior que lo traiga —aunque escriba el título distinto— tiene
			// que reconocerse como duplicado.
			isrc := claveISRC(item.ISRC)
			if previo, ok := ix.isrcs[isrc]; !ok || duplicado < previo {
				ix.isrcs[isrc] = duplicado
			}
		}
		return buffer
	}

	// Se agrega. Si trae ISRC no puede estar ya en el mapa (habría sido
	// duplicado y se habría vuelto arriba), así que esta posición es la primera.
	if item.ISRC != "" {
		ix.isrcs[claveISRC(item.ISRC)] = len(buffer)
	} else {
		ix.haySinISRC = true
	}
	ix.hayTrack = true
	if grupos != nil {
		grupos[clave] = append(grupos[clave], len(buffer))
	}
	return append(buffer, item)
}

// porClaveDeFacto devuelve el mapa de claves canónicas, construyéndolo la
// primera vez que se pide a partir del buffer completo. Se arma así (una
// pasada, cuando aparece el primer item sin ISRC) en vez de incrementarlo item
// por item: los tracks que entraron antes de que hiciera falta —todos con
// ISRC— no tenían por qué pagar la normalización, y el buffer completo los
// incluye igual.
func (ix *indiceBusqueda) porClaveDeFacto(buffer []FeedItemGo) map[string][]int {
	if ix.porClave == nil {
		ix.porClave = make(map[string][]int, len(buffer))
		for i := range buffer {
			if buffer[i].Type != "track" {
				continue
			}
			clave := claveNombre(buffer[i].Name, buffer[i].Artists)
			ix.porClave[clave] = append(ix.porClave[clave], i)
		}
	}
	return ix.porClave
}

// posicionQueEmpata devuelve la posición del track del buffer que ya es el
// mismo tema que `item` (o -1), comparándolo uno por uno con los que comparten
// su clave canónica. Es el mismo predicado que usa el barrido lineal
// (esElMismoTrack), solo que sobre un grupo y no sobre todo, y devuelve la
// posición —no un bool— porque el llamador necesita saber a QUIÉN fusionarle el
// ISRC del item descartado.
func (ix *indiceBusqueda) posicionQueEmpata(posiciones []int, buffer []FeedItemGo, item FeedItemGo) int {
	for _, pos := range posiciones {
		if esElMismoTrack(buffer[pos], item) {
			return pos
		}
	}
	return -1
}
