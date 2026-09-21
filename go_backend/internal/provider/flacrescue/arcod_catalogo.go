// ─────────────────────────────────────────────────────────────
// arcod_catalogo.go — Lectura del catálogo de arcod.xyz: convierte la
// respuesta JSON de /api/get-music en pistas y devuelve la que coincide
// con el ISRC pedido.
//
// Por qué la elección es ESTRICTA (ISRC igual, nada de parecidos): este
// canal entra en el rescate como fuente EXACTA (proveedoresExactos). Las
// llamadas de streaming solo traen el ISRC, así que no hay título ni
// artista con qué confirmar un parecido — y servir la canción de otro
// sería peor que no servir ninguna. La búsqueda del sitio SÍ acepta el
// ISRC (probado: devuelve una sola pista), así que la coincidencia
// exacta es la regla natural.
//
// Datos que no son obvios en su respuesta (capturados en vivo):
//   · el artista de una pista viene en `performer`, no en `artist`;
//   · el ISRC viaja en la pista;
//   · los permisos son streamable/downloadable/displayable;
//   · los ids llegan como número unas veces y como texto otras.
//
// Se conecta con: arcod.go (canal) y arcod_json.go (plomería).
// Parte del flujo: rescate de FLAC por stream y por descarga.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"encoding/json"
	"fmt"
	"strings"
)

// arcodPista es una pista del catálogo del sitio (objeto crudo de Qobuz).
type arcodPista struct {
	ID          json.RawMessage `json:"id"`
	QobuzID     json.RawMessage `json:"qobuz_id"`
	ISRC        string          `json:"isrc"`
	Titulo      string          `json:"title"`
	Nombre      string          `json:"name"`
	Streamable  *bool           `json:"streamable"`
	Descargable *bool           `json:"downloadable"`
	Mostrable   *bool           `json:"displayable"`
	Performer   struct {
		Name string `json:"name"`
	} `json:"performer"`
	Album struct {
		Title string `json:"title"`
		Name  string `json:"name"`
	} `json:"album"`
}

// idArcod es el id usable de la pista (Qobuz numérico o el alternativo).
func (p arcodPista) idArcod() string { return primerID(p.ID, p.QobuzID) }

// tituloArcod es el título usable de la pista.
func (p arcodPista) tituloArcod() string { return primerTexto(p.Titulo, p.Nombre) }

// artistaArcod es el artista de la pista. Vive en `performer`: leer `artist`
// (que existe en los álbumes) lo dejaría siempre vacío.
func (p arcodPista) artistaArcod() string { return strings.TrimSpace(p.Performer.Name) }

// servible reporta si el sitio puede entregar la pista (los tres permisos
// tienen que estar en true; ausentes cuentan como permitidos).
func (p arcodPista) servible() bool {
	return permitido(p.Streamable) && permitido(p.Descargable) && permitido(p.Mostrable)
}

// pistasArcod traduce la respuesta de la búsqueda a pistas. Un catálogo vacío
// NO es un error (es "esa canción no está en el sitio"), pero un sobre con
// success=false sí lo es y trae el motivo del sitio.
func pistasArcod(cuerpo []byte) ([]arcodPista, error) {
	var sobre struct {
		Success bool            `json:"success"`
		Error   string          `json:"error"`
		Data    json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(cuerpo, &sobre); err != nil {
		return nil, fmt.Errorf("respuesta ilegible del canal: %s", detalleSitio(cuerpo))
	}
	if !sobre.Success {
		return nil, errorDeSobre(sobre.Error, cuerpo)
	}
	var catalogo struct {
		Tracks struct {
			Items []arcodPista `json:"items"`
		} `json:"tracks"`
	}
	if err := json.Unmarshal(sobre.Data, &catalogo); err != nil {
		return nil, fmt.Errorf("catálogo ilegible: %s", detalleSitio(sobre.Data))
	}
	return catalogo.Tracks.Items, nil
}

// pistaArcodPorISRC devuelve la pista cuyo ISRC coincide con [isrc]. Sin
// coincidencia exacta devuelve el mismo error que los sitios ("sin
// coincidencia verificable"): preferible no resolver antes que servir otra
// grabación.
func pistaArcodPorISRC(pistas []arcodPista, isrc string) (arcodPista, error) {
	buscado := normalizarISRC(isrc)
	if buscado == "" {
		return arcodPista{}, errSinCoincidencia
	}
	for _, pista := range pistas {
		if !pista.servible() || pista.idArcod() == "" {
			continue
		}
		if normalizarISRC(pista.ISRC) == buscado {
			return pista, nil
		}
	}
	return arcodPista{}, errSinCoincidencia
}

// errorDeSobre explica un fallo del canal. Los tokens de Qobuz son lo que
// sostiene todo su catálogo: sin tokens vivos no hay canción que se resuelva
// por más que se reintente, así que se avisa con un error propio para que el
// canal quede en pausa unos minutos en vez de pagar la espera en cada
// reproducción.
func errorDeSobre(motivo string, cuerpo []byte) error {
	texto := strings.TrimSpace(motivo)
	if texto == "" {
		return fmt.Errorf("el canal no buscó: %s", detalleSitio(cuerpo))
	}
	if strings.Contains(strings.ToLower(texto), "token") {
		return fmt.Errorf("%w: %s", errArcodSinCuentas, texto)
	}
	return fmt.Errorf("el canal no buscó: %s", texto)
}

// permitido lee un flag booleano opcional de la pista: ausente = permitido.
func permitido(flag *bool) bool { return flag == nil || *flag }

// primerID devuelve el primer id usable de la lista.
func primerID(crudos ...json.RawMessage) string {
	for _, crudo := range crudos {
		if texto := textoID(crudo); texto != "" {
			return texto
		}
	}
	return ""
}

// textoID convierte un id JSON (número o texto) en texto usable.
func textoID(crudo json.RawMessage) string {
	if len(crudo) == 0 {
		return ""
	}
	var valor any
	if err := json.Unmarshal(crudo, &valor); err != nil {
		return ""
	}
	switch dato := valor.(type) {
	case string:
		return strings.TrimSpace(dato)
	case float64:
		return fmt.Sprintf("%.0f", dato)
	}
	return ""
}

// primerTexto devuelve el primer texto no vacío (la API manda el mismo dato
// como title o como name según el tipo de objeto).
func primerTexto(opciones ...string) string {
	for _, opcion := range opciones {
		if texto := strings.TrimSpace(opcion); texto != "" {
			return texto
		}
	}
	return ""
}
