// detalle.go — Modelos de archive.org, parseo de ids y detalle de pista,
// álbum y artista. El id de una pista es "ia:<identificador>/<archivo>", así
// que un mismo item se puede volver a resolver sin buscarlo otra vez.
//
// Se conecta con: client.go (HTTP y cachés), audio.go (elección de formato) y
// busqueda.go (hidratación de resultados).
// Parte del flujo: detalle de la fuente Internet Archive.
package internetarchive

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// textoFlexible acepta string, número o array de ambos y se queda con el
// primero. La API de archive.org cambia el tipo del MISMO campo según el item
// (creator suele ser array, track a veces número, length a veces número), y un
// error de tipo ahí tiraría toda la pista.
type textoFlexible string

// UnmarshalJSON implementa json.Unmarshaler tolerando los tres casos.
func (t *textoFlexible) UnmarshalJSON(datos []byte) error {
	*t = textoFlexible(extraerTexto(datos))
	return nil
}

// extraerTexto saca el primer valor textual de un JSON de tipo desconocido.
func extraerTexto(datos []byte) string {
	texto := strings.TrimSpace(string(datos))
	if texto == "" || texto == "null" {
		return ""
	}
	if strings.HasPrefix(texto, "[") {
		var lista []json.RawMessage
		if err := json.Unmarshal(datos, &lista); err != nil {
			return ""
		}
		for _, item := range lista {
			if v := extraerTexto(item); v != "" {
				return v
			}
		}
		return ""
	}
	var s string
	if err := json.Unmarshal(datos, &s); err == nil {
		return strings.TrimSpace(s)
	}
	var n json.Number
	if err := json.Unmarshal(datos, &n); err == nil {
		return n.String()
	}
	return strings.Trim(texto, `"`)
}

// Archivo es un archivo dentro de un item de archive.org.
type Archivo struct {
	Name     string        `json:"name"`
	Format   string        `json:"format"`
	Title    string        `json:"title"`
	Track    textoFlexible `json:"track"`
	Length   textoFlexible `json:"length"`
	Size     textoFlexible `json:"size"`
	Album    string        `json:"album"`
	Artist   string        `json:"artist"`
	Creator  textoFlexible `json:"creator"`
	Original string        `json:"original"`
}

// Item es la respuesta de /metadata/<identifier>: la metadata del item más la
// lista completa de archivos.
type Item struct {
	Metadata struct {
		Identifier textoFlexible `json:"identifier"`
		Title      string        `json:"title"`
		Creator    textoFlexible `json:"creator"`
		Date       textoFlexible `json:"date"`
		Year       textoFlexible `json:"year"`
		Album      string        `json:"album"`
		Mediatype  string        `json:"mediatype"`
	} `json:"metadata"`
	Files []Archivo `json:"files"`
}

// identificador devuelve el id del item tal como lo publica la API.
func (it *Item) identificador(alternativa string) string {
	if it == nil {
		return alternativa
	}
	if v := strings.TrimSpace(string(it.Metadata.Identifier)); v != "" {
		return v
	}
	return alternativa
}

// titulo devuelve el título del item (cae al identificador si falta).
func (it *Item) titulo(alternativa string) string {
	if it == nil {
		return alternativa
	}
	return primerNoVacio(it.Metadata.Title, string(it.Metadata.Album), alternativa)
}

// creador devuelve el autor del item.
func (it *Item) creador() string {
	if it == nil {
		return ""
	}
	return strings.TrimSpace(string(it.Metadata.Creator))
}

// anio devuelve el año/ fecha del item.
func (it *Item) anio() string {
	if it == nil {
		return ""
	}
	return primerNoVacio(string(it.Metadata.Year), string(it.Metadata.Date))
}

// pistasDeAudio cuenta los archivos de audio del item (sin contar carátulas ni
// espectrogramas que archive.org agrega a todos los items).
func (it *Item) pistasDeAudio() int {
	if it == nil {
		return 0
	}
	total := 0
	for _, f := range it.Files {
		if esAudio(f.Format) {
			total++
		}
	}
	return total
}

// partirID separa "ia:<identificador>/<archivo>" en sus dos partes.
func partirID(id string) (string, string, error) {
	texto := strings.TrimSpace(id)
	for _, prefijo := range []string{prefijoID, name + ":", "internetarchive/"} {
		if strings.HasPrefix(texto, prefijo) {
			texto = strings.TrimPrefix(texto, prefijo)
			break
		}
	}
	corte := strings.Index(texto, "/")
	if corte <= 0 || corte == len(texto)-1 {
		return "", "", fmt.Errorf("%s: id inválido %q (se espera \"ia:<item>/<archivo>\")", name, id)
	}
	return texto[:corte], texto[corte+1:], nil
}

// idPista arma el id estable de una pista.
func idPista(identifier, archivo string) string {
	return prefijoID + identifier + "/" + archivo
}

// obtenerItem devuelve la metadata del item, cacheada. Es la llamada que más se
// repite (búsqueda, detalle y cada reproducción), así que se cachea por 10 min.
func (c *Client) obtenerItem(identifier string) (*Item, error) {
	identifier = strings.TrimSpace(identifier)
	if identifier == "" {
		return nil, fmt.Errorf("%s: identificador vacío", name)
	}
	if v, ok := c.items.Get(identifier); ok && v != nil {
		return v, nil
	}
	var item Item
	if err := c.doJSON(c.base+"/metadata/"+identifier, &item); err != nil {
		return nil, err
	}
	if len(item.Files) == 0 && strings.TrimSpace(string(item.Metadata.Identifier)) == "" {
		return nil, fmt.Errorf("%s: el item %q no existe o no tiene archivos", name, identifier)
	}
	c.items.Set(identifier, &item)
	return &item, nil
}

// pistaDesdeArchivo convierte un archivo del item en un TrackResult.
func (c *Client) pistaDesdeArchivo(identifier string, item *Item, archivo Archivo) provider.TrackResult {
	titulo := primerNoVacio(archivo.Title, tituloDesdeArchivo(archivo.Name))
	artista := primerNoVacio(archivo.Artist, string(archivo.Creator), item.creador())
	return provider.TrackResult{
		ID:       idPista(identifier, archivo.Name),
		Title:    titulo,
		Artist:   artista,
		Album:    item.titulo(identifier),
		AlbumID:  identifier,
		Duration: duracionMS(string(archivo.Length)),
		CoverURL: c.urlItem(identifier),
		Provider: name,
	}
}

// GetTrack devuelve el detalle de una pista por su id.
func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	if v, ok := c.pistas.Get(id); ok && v != nil {
		return v, nil
	}
	identifier, archivo, err := partirID(id)
	if err != nil {
		return nil, err
	}
	item, err := c.obtenerItem(identifier)
	if err != nil {
		return nil, err
	}
	encontrado := coincidirArchivo(item, archivo)
	if encontrado == nil {
		return nil, fmt.Errorf("%s: %q no está en %s", name, archivo, identifier)
	}
	pista := c.pistaDesdeArchivo(item.identificador(identifier), item, *encontrado)
	c.pistas.Set(id, &pista)
	return &pista, nil
}

// GetTrackByISRC: Internet Archive no publica ISRC en su metadata, así que no
// puede confirmar una grabación exacta. Se devuelve el error explícito para que
// el rescate siga con otra fuente en vez de aceptar una coincidencia por nombre.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("%s: no publica ISRC (solo identifica por nombre)", name)
}

// GetAlbum devuelve el detalle de un item (álbum/set) por su identificador.
func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	identifier := strings.TrimPrefix(strings.TrimSpace(id), prefijoID)
	item, err := c.obtenerItem(identifier)
	if err != nil {
		return nil, err
	}
	return &provider.AlbumResult{
		ID:          item.identificador(identifier),
		Title:       item.titulo(identifier),
		Artist:      item.creador(),
		CoverURL:    c.urlItem(identifier),
		ReleaseDate: item.anio(),
		TrackCount:  item.pistasDeAudio(),
		Provider:    name,
	}, nil
}

// GetArtist: en archive.org el "artista" es el campo creator, que no tiene
// identidad propia. Se devuelve el nombre tal cual para que la ficha no falle.
func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	nombre := strings.TrimSpace(id)
	if nombre == "" {
		return nil, fmt.Errorf("%s: artista vacío", name)
	}
	return &provider.ArtistResult{ID: nombre, Name: nombre, Provider: name}, nil
}

// SearchAlbums busca items de audio y los presenta como álbumes/sets.
func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	items, err := c.buscarItems(query, limiteValido(limit))
	if err != nil {
		return nil, err
	}
	albumes := make([]provider.AlbumResult, 0, len(items))
	for _, it := range items {
		albumes = append(albumes, provider.AlbumResult{
			ID:          it.identificador,
			Title:       it.titulo,
			Artist:      it.creador,
			CoverURL:    c.urlItem(it.identificador),
			ReleaseDate: it.anio,
			Provider:    name,
		})
	}
	return albumes, nil
}

// SearchArtists busca por creator y deduplica los nombres.
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	items, err := c.buscarItems(query, limiteValido(limit))
	if err != nil {
		return nil, err
	}
	vistos := map[string]bool{}
	artistas := make([]provider.ArtistResult, 0, len(items))
	for _, it := range items {
		nombre := strings.TrimSpace(it.creador)
		if nombre == "" || vistos[strings.ToLower(nombre)] {
			continue
		}
		vistos[strings.ToLower(nombre)] = true
		artistas = append(artistas, provider.ArtistResult{
			ID:         nombre,
			Name:       nombre,
			PictureURL: c.urlItem(it.identificador),
			Provider:   name,
		})
	}
	return artistas, nil
}
