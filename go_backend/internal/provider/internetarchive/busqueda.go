// busqueda.go — Búsqueda en Internet Archive: consulta el índice abierto
// (advancedsearch) y "hidrata" los items para devolver pistas reproducibles.
//
// Por qué hidratar: advancedsearch devuelve ITEMS (un concierto, un álbum
// subido), no pistas. Para que la búsqueda funcione como las demás fuentes hay
// que leer los archivos de cada item y quedarse con el mejor formato de cada
// tema — prefiriendo FLAC sobre su MP3 hermano, que es exactamente para lo que
// existe esta fuente.
//
// La hidratación es acotada (pocos items en paralelo, corte en cuanto hay
// suficientes pistas) para no convertir una búsqueda en decenas de peticiones.
// La metadata del item queda cacheada, así que abrir el resultado no vuelve a
// pedirla.
//
// Se conecta con: client.go (HTTP y cachés) y detalle.go (item → TrackResult).
// Parte del flujo: búsqueda de la fuente Internet Archive.
package internetarchive

import (
	"fmt"
	"net/url"
	"sort"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// maxItemsHidratados acota cuántos items se leen por búsqueda. La lectura es
// SECUENCIAL a propósito: archive.org degrada las peticiones concurrentes
// (medido con 8 items: 2,5 s de uno en uno contra 7,9 s con 4 en paralelo; y la
// búsqueda completa con 5 en paralelo tardaba 8-14 s contra 1,6-4,2 s en serie).
// El tope de items también es un tope de latencia: cada uno cuesta una lectura
// de metadata (0,3-6 s según cuántos archivos publique), así que sin él una
// consulta que encuentre muchos items sueltos se estiraría sin control.
const maxItemsHidratados = 6

// mediatypesAudio es el filtro de tipo de item del índice. NO alcanza con
// "audio": archive.org clasifica los conciertos del Live Music Archive con
// mediatype "etree", no "audio".
//
// Medido contra la API real (2026-09): format:Flac da 1.239.197 items, pero con
// mediatype:audio quedan 954.575 — y `collection:etree AND format:Flac AND
// mediatype:audio` devuelve 4 items contra 265.593 sin el filtro. O sea que el
// filtro viejo dejaba afuera los 265.588 shows lossless de etree, que son justo
// los que traen artista, fecha y recinto reales en su metadata.
const mediatypesAudio = "(audio OR etree)"

// coleccionesNoMusica son colecciones cuyo TÍTULO contiene canciones pero cuyo
// contenido no es la canción: radios, podcasts y programas.
//
// Medido contra la API real (2026-09): sin esto, buscar "Nirvana Smells Like
// Teen Spirit" devolvía un programa de radio y "Miles Davis Kind of Blue"
// devolvía el podcast de Radio Open Source — el item se llama como la canción,
// así que el índice lo encuentra y el rescate ofrece una charla en vez de
// música. Se excluyen en la consulta (no en el cliente) para que el índice no
// gasten las filas que necesitamos en items que ya sabemos que no sirven.
var coleccionesNoMusica = []string{
	"podcasts",
	"podcasts_miscellaneous",
	"radioopensource",
	"radioprograms",
	"radioshowarchive",
	"radiostationarchives",
	"fmradioarchive",
	"radio",
	"oldtimeradio",
	"theoldtimeradio",
	"audio_podcast",
	"generative-art-archive",
}

// titulosSospechosos marcan las pistas que NO son la grabación original:
// karaoke, covers, instrumentales, reimaginaciones con IA.
//
// Medido contra la API real (2026-09): de 16 pistas que devolvió
// `title:"<canción>"`, 6 tenían una de estas marcas en el nombre y solo 1
// coincidía en duración con la canción real de Deezer. Como esta fuente entra
// al rescate cuando las comerciales fallan, un karaoke no es un resultado
// válido: se manda al final de la lista (nunca se descarta, para no perder
// disponibilidad, pero deja de ganarle a la grabación buena).
var titulosSospechosos = []string{
	"karaoke",
	"tribute",
	"instrumental",
	"made famous by",
	"in the style of",
	"backing track",
	"reimagined",
	"not real",
	"type beat",
	"chiptune",
	"8 bit",
	"ringtone",
	"reaction",
	"how to play",
	"sped up",
	"slowed",
	"nightcore",
	"ai generated",
}

// itemResumen es un item del índice, sin sus archivos.
type itemResumen struct {
	identificador string
	titulo        string
	creador       string
	anio          string
	descargas     int
}

// docItem es un documento de advancedsearch tal como llega del servicio.
type docItem struct {
	Identifier string        `json:"identifier"`
	Title      string        `json:"title"`
	Creator    textoFlexible `json:"creator"`
	Year       textoFlexible `json:"year"`
	Date       textoFlexible `json:"date"`
	Downloads  textoFlexible `json:"downloads"`
	Collection textoFlexible `json:"collection"`
	Mediatype  string        `json:"mediatype"`
}

// respuestaBusqueda es el sobre JSON de advancedsearch.
type respuestaBusqueda struct {
	Response struct {
		NumFound int       `json:"numFound"`
		Docs     []docItem `json:"docs"`
	} `json:"response"`
}

// SearchTracks busca items y devuelve sus pistas, con el FLAC de cada tema
// cuando el item lo publica.
func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	limit = limiteValido(limit)
	clave := "trk|" + strings.ToLower(strings.TrimSpace(query)) + "|" + fmt.Sprint(limit)
	if v, ok := c.busquedas.Get(clave); ok {
		return v, nil
	}

	items, err := c.buscarItems(query, limit)
	if err != nil {
		return nil, err
	}
	pistas := c.hidratarTracks(items, limit)
	if len(pistas) == 0 {
		// Sin resultados NO es un error: el buscador agrega las demás fuentes y
		// una fuente sin coincidencias no debe mostrar un fallo al usuario.
		return []provider.TrackResult{}, nil
	}
	c.busquedas.Set(clave, pistas)
	return pistas, nil
}

// SearchPlaylists expone las colecciones de archive.org como playlists: son
// conjuntos curados (Live Music Archive, 78rpm...) y es lo que más se parece a
// una playlist dentro de este catálogo.
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	items, err := c.buscarColecciones(query, limiteValido(limit))
	if err != nil {
		return nil, err
	}
	playlists := make([]provider.PlaylistResult, 0, len(items))
	for _, it := range items {
		playlists = append(playlists, provider.PlaylistResult{
			ID:       it.identificador,
			Title:    it.titulo,
			Creator:  it.creador,
			CoverURL: c.urlItem(it.identificador),
			Provider: name,
		})
	}
	return playlists, nil
}

// buscarItems consulta el índice de audio, ordenado por popularidad y cacheado.
//
// Estrategia de consulta, medida contra el servicio: el texto libre de
// advancedsearch busca en TODOS los campos (incluida la descripción), así que
// "Miles Davis Kind of Blue" devolvía colecciones de 1925 y programas de radio
// en vez del disco. Buscar la frase en el título devuelve la coincidencia
// correcta en el puesto 1 ("Miles Davis' Kind of Blue"). Por eso primero se
// prueba el título y, solo si no hay NADA, se cae al texto libre — que es el
// único modo que funciona con consultas que mezclan título y artista
// ("So What Miles Davis", como arma el rescate).
func (c *Client) buscarItems(query string, filas int) ([]itemResumen, error) {
	items, err := c.buscarPorTitulo(query, filas)
	if err == nil && len(items) > 0 {
		return items, nil
	}
	libres, errLibre := c.buscar(query, mediatypesAudio, filas)
	if errLibre != nil {
		// La reserva también falló: se propaga el error del intento principal
		// si lo hubo, porque describe mejor el problema.
		if err != nil {
			return nil, err
		}
		return nil, errLibre
	}
	return libres, nil
}

// buscarPorTitulo busca la consulta como FRASE dentro del título del item.
// Las comillas dobles del usuario se descartan: se encierran en comillas
// propias, así que dejarlas rompería la sintaxis de la consulta.
func (c *Client) buscarPorTitulo(query string, filas int) ([]itemResumen, error) {
	frase := strings.TrimSpace(strings.ReplaceAll(query, `"`, ""))
	if frase == "" {
		return nil, fmt.Errorf("%s: búsqueda vacía", name)
	}
	return c.buscar(`title:"`+frase+`"`, mediatypesAudio, filas)
}

// buscarColecciones consulta el índice de colecciones.
func (c *Client) buscarColecciones(query string, filas int) ([]itemResumen, error) {
	return c.buscar(query, "collection", filas)
}

// buscar ejecuta advancedsearch restringido a [mediatype]. [mediatype] acepta
// una expresión (p. ej. "(audio OR etree)"), no solo un valor suelto.
func (c *Client) buscar(query string, mediatype string, filas int) ([]itemResumen, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("%s: búsqueda vacía", name)
	}
	clave := mediatype + "|" + strings.ToLower(query) + "|" + fmt.Sprint(filas)
	if v, ok := c.busquedasItems.Get(clave); ok {
		return v, nil
	}

	// Se encierra la consulta del usuario en paréntesis para que un "OR" escrito
	// por él no se escape del filtro de mediatype.
	consulta := "(" + query + ") AND mediatype:" + mediatype
	// Fuera radios y podcasts: su título contiene la canción pero no lo es.
	for _, coleccion := range coleccionesNoMusica {
		consulta += " AND -collection:" + coleccion
	}
	// Fuera los items de solo-streaming: listan sus archivos pero /download/
	// responde 401, así que son resultados que no se pueden reproducir.
	// (access-restricted-item es un campo indexado: se filtra en la consulta.)
	consulta += " AND -access-restricted-item:true AND -collection:stream_only"

	valores := url.Values{}
	valores.Set("q", consulta)
	valores.Set("rows", fmt.Sprint(filas))
	valores.Set("page", "1")
	valores.Set("output", "json")
	valores.Set("sort[]", "downloads desc")
	for _, campo := range []string{"identifier", "title", "creator", "year", "date", "downloads", "collection"} {
		valores.Add("fl[]", campo)
	}

	var respuesta respuestaBusqueda
	if err := c.doJSON(c.base+"/advancedsearch.php?"+valores.Encode(), &respuesta); err != nil {
		return nil, err
	}

	items := make([]itemResumen, 0, len(respuesta.Response.Docs))
	for _, doc := range respuesta.Response.Docs {
		id := strings.TrimSpace(doc.Identifier)
		if id == "" {
			continue
		}
		items = append(items, itemResumen{
			identificador: id,
			titulo:        primerNoVacio(doc.Title, id),
			creador:       strings.TrimSpace(string(doc.Creator)),
			anio:          primerNoVacio(string(doc.Year), string(doc.Date)),
			descargas:     atoiSeguro(string(doc.Downloads)),
		})
	}
	c.busquedasItems.Set(clave, items)
	return items, nil
}

// hidratarTracks lee los items (uno por uno, acotado) y devuelve sus pistas,
// sin repetir el mismo tema en sus dos formatos.
//
// Secuencial gana a paralelo con este servicio: archive.org limita por IP y
// castiga las ráfagas (ver maxItemsHidratados). El corte temprano ayuda todavía
// más: en cuanto hay [limit] pistas se deja de pedir metadata, así que un
// buscador que necesita 25 temas suele leer 1-3 items en vez de los 5 de antes.
func (c *Client) hidratarTracks(items []itemResumen, limit int) []provider.TrackResult {
	if len(items) == 0 || limit <= 0 {
		return nil
	}

	var (
		total   int
		conFlac []provider.TrackResult
		sinFlac []provider.TrackResult
		// Las que parecen otra versión (karaoke, cover, IA) van al final: solo
		// se usan si no hay ninguna grabación que parezca la original.
		sospechosas []provider.TrackResult
	)
	leidos := 0

	for _, resumen := range items {
		if total >= limit || leidos >= maxItemsHidratados {
			break
		}
		leidos++

		item, err := c.obtenerItem(resumen.identificador)
		if err != nil {
			continue // un item roto no debe tumbar la búsqueda entera
		}
		if item.restringido() {
			// Un item de solo-streaming pasó el filtro de la consulta (índice
			// desactualizado): mejor no ofrecerlo que dar una pista que no suena.
			continue
		}
		identifier := item.identificador(resumen.identificador)
		for _, p := range pistasDelItem(item, identifier, c) {
			// El MISMO tema puede venir en FLAC y en MP3 dentro del item: se
			// emite una sola vez y se reserva para el grupo "con FLAC".
			if p.sospechosa {
				sospechosas = append(sospechosas, p.resultado)
				continue
			}
			total++
			if p.esLossless {
				conFlac = append(conFlac, p.resultado)
			} else {
				sinFlac = append(sinFlac, p.resultado)
			}
		}
	}

	// Los items con FLAC van primero: la fuente existe para dar lossless, así
	// que si hay un item que lo publica no debe quedar tapado por uno en MP3.
	// Las sospechosas cierran la lista.
	ordenadas := append(append(append([]provider.TrackResult{}, conFlac...), sinFlac...), sospechosas...)
	if len(ordenadas) > limit {
		ordenadas = ordenadas[:limit]
	}
	return ordenadas
}

// pistaElegida es una pista con su calidad, para ordenar por lossless y para
// separar las que parecen otra versión (karaoke, cover, IA).
type pistaElegida struct {
	resultado  provider.TrackResult
	esLossless bool
	sospechosa bool
}

// pistasDelItem convierte los archivos de un item en pistas, un solo resultado
// por tema y en el mejor formato disponible para ese tema.
func pistasDelItem(item *Item, identifier string, c *Client) []pistaElegida {
	grupos := map[string][]Archivo{}
	var orden []string
	for _, f := range item.Files {
		if !esAudio(f.Format) {
			continue
		}
		clave := strings.TrimSpace(string(f.Track))
		if clave == "" {
			clave = sinExtension(f.Name)
		}
		if _, visto := grupos[clave]; !visto {
			orden = append(orden, clave)
		}
		grupos[clave] = append(grupos[clave], f)
	}

	// Orden estable por número de pista cuando el item lo trae (los conciertos
	// numeran "01", "02"...); si no, se respeta el orden del item.
	sort.SliceStable(orden, func(i, j int) bool {
		a, b := orden[i], orden[j]
		na, nb := atoiSeguro(a), atoiSeguro(b)
		if na > 0 && nb > 0 {
			return na < nb
		}
		return false
	})

	salida := make([]pistaElegida, 0, len(orden))
	for _, clave := range orden {
		archivos := grupos[clave]
		elegido, lossless := mejorDelGrupo(archivos)
		if elegido == nil {
			continue
		}
		pista := c.pistaDesdeArchivo(identifier, item, *elegido)
		salida = append(salida, pistaElegida{
			resultado:  pista,
			esLossless: lossless,
			sospechosa: esTituloSospechoso(pista.Title) ||
				esTituloSospechoso(pista.Artist),
		})
	}
	return salida
}

// esTituloSospechoso reporta si un título (o un artista) trae una marca de
// versión que no es la original: karaoke, cover, instrumental, IA...
//
// La comparación es por PALABRA completa: "discover" no debe contar como
// "cover", ni "backing" como "back". Para eso se normaliza la puntuación a
// espacios y se busca el marcador rodeado de espacios.
func esTituloSospechoso(texto string) bool {
	normal := normalizarPalabras(texto)
	if normal == "" {
		return false
	}
	relleno := " " + normal + " "
	for _, marca := range titulosSospechosos {
		if strings.Contains(relleno, " "+marca+" ") {
			return true
		}
	}
	return false
}

// normalizarPalabras deja solo letras, números y espacios simples. Se usan los
// caracteres no ASCII tal cual (acentos, ñ) para no inventar palabras.
func normalizarPalabras(texto string) string {
	var b strings.Builder
	espacio := true
	for _, r := range strings.ToLower(texto) {
		esLetra := (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r > 127
		if esLetra {
			b.WriteRune(r)
			espacio = false
			continue
		}
		if !espacio {
			b.WriteRune(' ')
			espacio = true
		}
	}
	return strings.TrimSpace(b.String())
}

// mejorDelGrupo elige el archivo del grupo y reporta si es lossless. Prefiere
// siempre FLAC: si el grupo trae FLAC y MP3 del mismo tema, se queda con FLAC.
func mejorDelGrupo(archivos []Archivo) (*Archivo, bool) {
	var lossless, lossy []Archivo
	for _, f := range archivos {
		if clasificarArchivo(f.Format) == Lossless {
			lossless = append(lossless, f)
			continue
		}
		lossy = append(lossy, f)
	}
	if len(lossless) > 0 {
		mejor := mejorDe(lossless, Lossless)
		return &mejor, true
	}
	if len(lossy) > 0 {
		mejor := mejorDe(lossy, Lossy)
		return &mejor, false
	}
	return nil, false
}
