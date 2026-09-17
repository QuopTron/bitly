// ─────────────────────────────────────────────────────────────
// consultas.go — Consultas de alto nivel del cliente de Last.fm.
//
// Cada consulta es UN "bloque": una página del sitio que se cachea 12 h y
// que se resuelve en UN solo vuelo. Con eso, un álbum completo cuesta UNA
// petición (no una por pista) y repetir la consulta no toca la red.
// ─────────────────────────────────────────────────────────────

package lastfm

import (
	"net/url"
	"strings"
)

// toleranciaDuracionMs es lo que se admite de diferencia para dar por buena una
// coincidencia por duración (cada catálogo redondea distinto).
const toleranciaDuracionMs = 3000

// PistasDeAlbum devuelve el tracklist COMPLETO y en orden de un álbum.
func (c *Client) PistasDeAlbum(artista, album string) ([]Pista, error) {
	if artista == "" || album == "" {
		return nil, nil
	}
	cuerpo, err := c.cargar(rutaAlbum(artista, album))
	if err != nil {
		return nil, err
	}
	return pistasDeTabla(cuerpo), nil
}

// PistasDeArtista devuelve hasta 50 pistas del artista (la primera página de su
// lista más escuchada).
func (c *Client) PistasDeArtista(artista string) ([]Pista, error) {
	if artista == "" {
		return nil, nil
	}
	cuerpo, err := c.cargar(rutaArtista(artista) + "/+tracks")
	if err != nil {
		return nil, err
	}
	return pistasDeTabla(cuerpo), nil
}

// GenerosDeArtista devuelve las etiquetas del artista (su "género").
func (c *Client) GenerosDeArtista(artista string) ([]string, error) {
	if artista == "" {
		return nil, nil
	}
	cuerpo, err := c.cargar(rutaArtista(artista))
	if err != nil {
		return nil, err
	}
	return generosDe(cuerpo), nil
}

// Buscar resuelve una consulta libre contra la búsqueda del sitio. Es la vía
// que además corrige el nombre cuando el usuario lo escribió distinto.
func (c *Client) Buscar(consulta string) ([]Pista, error) {
	consulta = strings.TrimSpace(consulta)
	if consulta == "" {
		return nil, nil
	}
	cuerpo, err := c.cargar("/search?q=" + url.QueryEscape(consulta))
	if err != nil {
		return nil, err
	}
	return pistasDeTabla(cuerpo), nil
}

// MejorCoincidencia busca una pista concreta por bloques, del más barato al
// más caro: primero el ÁLBUM (si se conoce; trae el tracklist en orden con sus
// duraciones), después la lista del artista y por último la búsqueda.
//
// Devuelve la pista solo si el nombre coincide (normalizado) y, cuando hay
// duración de referencia, si además entra en la tolerancia. Sin esa
// verificación, el video que devuelve el sitio podría ser de otra canción.
func (c *Client) MejorCoincidencia(artista, album, titulo string, duracionMs int) (*Pista, error) {
	if titulo == "" {
		return nil, nil
	}
	bloques := []func() ([]Pista, error){
		func() ([]Pista, error) { return c.PistasDeAlbum(artista, album) },
		func() ([]Pista, error) { return c.PistasDeArtista(artista) },
		func() ([]Pista, error) { return c.Buscar(strings.TrimSpace(artista + " " + titulo)) },
	}
	for _, bloque := range bloques {
		pistas, err := bloque()
		if err != nil {
			return nil, err
		}
		if pista := elegirPista(pistas, titulo, duracionMs); pista != nil {
			return pista, nil
		}
	}
	return nil, nil
}

// elegirPista se queda con la pista que de verdad es la pedida.
func elegirPista(pistas []Pista, titulo string, duracionMs int) *Pista {
	objetivo := claveComparacion(titulo)
	if objetivo == "" {
		return nil
	}
	var candidata *Pista
	for i := range pistas {
		p := pistas[i]
		if p.YouTubeID == "" {
			continue
		}
		if claveComparacion(p.Nombre) != objetivo {
			continue
		}
		if duracionMs > 0 && p.DuracionMs > 0 &&
			abs(p.DuracionMs-duracionMs) > toleranciaDuracionMs {
			continue
		}
		if candidata == nil {
			candidata = &p
		}
	}
	return candidata
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

// rutaArtista arma la ruta de un artista (espacios con +, como el sitio).
func rutaArtista(artista string) string {
	return "/music/" + escaparRuta(artista)
}

// rutaAlbum arma la ruta de un álbum dentro de su artista.
func rutaAlbum(artista, album string) string {
	return rutaArtista(artista) + "/" + escaparRuta(album)
}

func escaparRuta(s string) string {
	escapado := url.PathEscape(strings.TrimSpace(s))
	return strings.ReplaceAll(escapado, "%20", "+")
}

// Compartido devuelve el cliente compartido del proceso (uno solo por app):
// así la caché y las pausas son las mismas para todas las partes que lo usan.
func Compartido() *Client {
	compartidoOnce.Do(func() { compartido = NewClient(nil) })
	return compartido
}

// TiempoDeEspera es el mínimo entre peticiones reales al sitio (para los
// llamadores que quieran documentarlo o medirlo).
const TiempoDeEspera = pausaEntrePeticiones

// VencimientoDeCache es cuánto dura en memoria una página ya bajada.
const VencimientoDeCache = vencPagina
