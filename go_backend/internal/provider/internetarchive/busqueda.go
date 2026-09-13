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
	"sync"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// maxHidratacion es cuántos items se leen en paralelo al buscar. Más paralelo
// acelera, pero archive.org limita por IP; cinco mantiene la búsqueda bajo ~2s.
const maxHidratacion = 5

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
func (c *Client) buscarItems(query string, filas int) ([]itemResumen, error) {
	return c.buscar(query, "audio", filas)
}

// buscarColecciones consulta el índice de colecciones.
func (c *Client) buscarColecciones(query string, filas int) ([]itemResumen, error) {
	return c.buscar(query, "collection", filas)
}

// buscar ejecuta advancedsearch restringido a [mediatype].
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

// hidratarTracks lee los items (en paralelo y acotado) y devuelve sus pistas,
// sin repetir el mismo tema en sus dos formatos.
func (c *Client) hidratarTracks(items []itemResumen, limit int) []provider.TrackResult {
	if len(items) == 0 || limit <= 0 {
		return nil
	}

	var (
		mu      sync.Mutex
		total   int
		conFlac []provider.TrackResult
		sinFlac []provider.TrackResult
	)
	permiso := make(chan struct{}, maxHidratacion)
	var wg sync.WaitGroup

	for _, resumen := range items {
		// Si ya hay suficientes pistas, no se pagan más peticiones.
		mu.Lock()
		suficiente := total >= limit
		mu.Unlock()
		if suficiente {
			break
		}

		wg.Add(1)
		permiso <- struct{}{}
		go func(resumen itemResumen) {
			defer wg.Done()
			defer func() { <-permiso }()

			item, err := c.obtenerItem(resumen.identificador)
			if err != nil {
				return // un item roto no debe tumbar la búsqueda entera
			}
			identifier := item.identificador(resumen.identificador)
			encontradas := pistasDelItem(item, identifier, c)

			mu.Lock()
			defer mu.Unlock()
			for _, p := range encontradas {
				// El MISMO tema puede venir en FLAC y en MP3 dentro del item:
				// se emite una sola vez y se reserva para el grupo "con FLAC".
				total++
				if p.esLossless {
					conFlac = append(conFlac, p.resultado)
				} else {
					sinFlac = append(sinFlac, p.resultado)
				}
			}
		}(resumen)
	}
	wg.Wait()

	// Los items con FLAC van primero: la fuente existe para dar lossless, así
	// que si hay un item que lo publica no debe quedar tapado por uno en MP3.
	ordenadas := append(append([]provider.TrackResult{}, conFlac...), sinFlac...)
	if len(ordenadas) > limit {
		ordenadas = ordenadas[:limit]
	}
	return ordenadas
}

// pistaElegida es una pista con su calidad, para ordenar por lossless.
type pistaElegida struct {
	resultado  provider.TrackResult
	esLossless bool
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
		salida = append(salida, pistaElegida{
			resultado:  c.pistaDesdeArchivo(identifier, item, *elegido),
			esLossless: lossless,
		})
	}
	return salida
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
