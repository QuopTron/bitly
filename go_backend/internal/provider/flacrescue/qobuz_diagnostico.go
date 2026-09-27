// ─────────────────────────────────────────────────────────────
// qobuz_diagnostico.go — Informe del canal "Qobuz firmado".
//
// Por qué existe: el canal se apaga solo cuando no hay credenciales, y
// con claves públicas Qobuz entrega MP3 (no FLAC) si falta el token de
// suscriptor. Sin un informe, el usuario no puede saber si lo que pegó
// sirve, si el secreto rotó o si está oyendo MP3 creyendo que es FLAC.
//
// Qué hace: recorre el MISMO camino que una reproducción real (resolver
// credenciales → búsqueda firmada → pedir FLAC) y traduce el resultado a
// un estado y un texto en castellano. Es SOLO LECTURA: no toca los
// ajustes, ni la caché de resoluciones, ni el pool de claves.
//
// Con un token configurado, además SEPARA dos causas que el audio no
// distingue por sí solo: "token inválido" (vencido/revocado) de "cuenta sin
// suscripción activa". /track/getFileUrl contesta 200 con MP3 320 en AMBOS
// casos (medido 2026-09-26: en los dos llega restrictions=[UserUnauthenticated]),
// así que para diferenciarlas se consulta un endpoint que exige sesión
// (favorite/getUserFavorites): 200 = el token vive, 401 = no sirve.
//
// Se conecta con: extensions_actions_flacrescue.go (se lo devuelve a la
// interfaz de Ajustes) y qobuz_firmado.go / qobuz_archivo.go (las mismas
// funciones que usa la resolución, para que el informe no mienta).
// Parte del flujo: Ajustes → Credenciales → Rescate de audio.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Estados posibles del informe. Son estables: la interfaz los usa para
// pintar el resultado (ok / aviso / apagado).
const (
	// EstadoSinClaves: el canal está apagado (ni claves ni origen).
	EstadoSinClaves = "sin_claves"
	// EstadoFirmaRechazada: Qobuz contestó 400/401 (secreto rotado).
	EstadoFirmaRechazada = "firma_rechazada"
	// EstadoSinConexion: no se pudo completar la consulta.
	EstadoSinConexion = "sin_conexion"
	// EstadoMp3: las claves sirven, pero Qobuz degrada a MP3.
	EstadoMp3 = "mp3_320"
	// EstadoFlac: el canal devuelve sin pérdida de verdad.
	EstadoFlac = "flac"
	// EstadoTokenInvalido: hay token de usuario pero Qobuz no lo acepta
	// (vencido o revocado); el canal degrada a MP3 320. El arreglo es pegar
	// un token nuevo.
	EstadoTokenInvalido = "token_invalido"
	// EstadoSinSuscripcion: el token es una sesión válida, pero la cuenta no
	// tiene suscripción activa; Qobuz degrada a MP3 320. El arreglo es la
	// suscripción, no el token.
	EstadoSinSuscripcion = "sin_suscripcion"
)

// DiagnosticoCanalQobuz es el informe que consume la interfaz.
type DiagnosticoCanalQobuz struct {
	Estado  string `json:"estado"`
	Fuente  string `json:"fuente"`  // manual | origen | ninguna
	Formato string `json:"formato"` // FLAC | MP3_320 | ""
	Ms      int64  `json:"ms"`
	Detalle string `json:"detalle"`
}

// DiagnosticoQobuz recorre el canal y devuelve su estado real.
func (c *Client) DiagnosticoQobuz() DiagnosticoCanalQobuz {
	inicio := time.Now()
	base, token, _, keysURL, appIDFijo, secretoFijo := c.qobuzConfig()

	fuente := "por_defecto"
	switch {
	case appIDFijo != "" && secretoFijo != "":
		fuente = "manual"
	case keysURL != "":
		fuente = "origen"
	}

	if _, _, ok := c.credencialesEfectivas(); !ok {
		return DiagnosticoCanalQobuz{
			Estado: EstadoSinClaves,
			Fuente: fuente,
			Ms:     time.Since(inicio).Milliseconds(),
			Detalle: "No se consiguió un app_id/app_secret utilizable para firmar. Si pegaste " +
				"claves, revisá que estén completas; si usás el origen de fábrica, puede estar " +
				"caído en este momento. El rescate por espejos y Soulseek sigue igual.",
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), presupuestoQobuz)
	defer cancel()

	// Paso 1: ¿Qobuz acepta la firma? Es la misma búsqueda con la que se
	// validan las claves del origen.
	var busqueda struct {
		Tracks struct {
			Items []pistaQobuz `json:"items"`
		} `json:"tracks"`
	}
	err := c.pedirQobuz(ctx, base, "/catalog/search",
		map[string]string{"query": "flac", "limit": "1", "offset": "0"}, &busqueda)
	if err != nil {
		return informeDeError(err, fuente, time.Since(inicio))
	}
	pista := ""
	if len(busqueda.Tracks.Items) > 0 {
		pista = idATexto(busqueda.Tracks.Items[0].ID)
	}
	if pista == "" {
		return DiagnosticoCanalQobuz{
			Estado:  EstadoSinConexion,
			Fuente:  fuente,
			Ms:      time.Since(inicio).Milliseconds(),
			Detalle: "La firma la acepta Qobuz, pero la búsqueda no devolvió ninguna pista con id.",
		}
	}

	// Paso 2: el formato. Se PIDE FLAC y se mira qué contesta: es la única
	// forma de no prometer sin pérdida cuando lo que llega es MP3.
	var archivo respuestaFileURL
	err = c.pedirQobuz(ctx, base, "/track/getFileUrl",
		map[string]string{"format_id": "6", "intent": "stream", "track_id": pista}, &archivo)
	if err != nil {
		return informeDeError(err, fuente, time.Since(inicio))
	}

	ms := time.Since(inicio).Milliseconds()
	if archivo.esSinPerdida() {
		return DiagnosticoCanalQobuz{
			Estado: EstadoFlac, Fuente: fuente, Formato: "FLAC", Ms: ms,
			Detalle: "Listo: se pidió FLAC y Qobuz devolvió FLAC. El canal sirve audio " +
				"sin pérdida con estas credenciales.",
		}
	}

	// Sin pérdida no llegó. Si HAY token, la causa puede ser el token
	// (vencido/revocado) o la cuenta (sin suscripción): son dos arreglos
	// distintos y el audio no los distingue. Se pregunta a Qobuz si el token
	// sirve como sesión para no mandar al usuario a arreglar lo que no falta.
	if token != "" {
		ctxSesion, cancelar := context.WithTimeout(context.Background(), timeoutControlSesion)
		vivo, err := c.tokenQobuzAutentica(ctxSesion, base, token)
		cancelar()
		if err == nil {
			if !vivo {
				return DiagnosticoCanalQobuz{
					Estado: EstadoTokenInvalido, Fuente: fuente, Formato: "MP3_320", Ms: ms,
					Detalle: "El token de usuario no lo acepta Qobuz (vencido o revocado): por eso el " +
						"canal entrega MP3 320. Copiá un user_auth_token nuevo de tu cuenta y pegalo en " +
						"qobuz_user_token.",
				}
			}
			return DiagnosticoCanalQobuz{
				Estado: EstadoSinSuscripcion, Fuente: fuente, Formato: "MP3_320", Ms: ms,
				Detalle: "El token es válido (Qobuz lo acepta como sesión), pero la cuenta no tiene " +
					"una suscripción activa: Qobuz entrega MP3 320. Con un plan Studio o Sublime el " +
					"canal sirve FLAC sin pérdida.",
			}
		}
		// No se pudo confirmar (red o respuesta rara): se informa el caso MP3
		// con el aviso de siempre en vez de inventar un veredicto.
	}
	detalle := "Las claves son válidas, pero Qobuz entrega MP3 320 en vez de FLAC: sin " +
		"token de suscriptor Qobuz degrada el stream. Pegá qobuz_user_token (tu cuenta) " +
		"o dejá el FLAC en manos de los espejos o de Soulseek."
	if token != "" {
		detalle = "Las claves son válidas y hay token, pero Qobuz entregó MP3 320 y no se pudo " +
			"confirmar el estado del token (el control de sesión no respondió). Revisá que tu " +
			"cuenta tenga suscripción activa."
	}
	return DiagnosticoCanalQobuz{
		Estado: EstadoMp3, Fuente: fuente, Formato: "MP3_320", Ms: ms, Detalle: detalle,
	}
}

// informeDeError traduce un fallo del canal a estado y texto para el usuario.
func informeDeError(err error, fuente string, transcurrido time.Duration) DiagnosticoCanalQobuz {
	ms := transcurrido.Milliseconds()
	if esFirmaRechazada(err) {
		return DiagnosticoCanalQobuz{
			Estado: EstadoFirmaRechazada, Fuente: fuente, Ms: ms,
			Detalle: "Qobuz rechazó la firma (400/401): el app_secret rotó o ya no sirve. " +
				"Con un origen de claves, la app lo refresca sola en el próximo intento.",
		}
	}
	return DiagnosticoCanalQobuz{
		Estado: EstadoSinConexion, Fuente: fuente, Ms: ms,
		Detalle: "No se pudo completar la consulta a Qobuz: " + acortarMotivo(err.Error()) + ".",
	}
}

// qobuzAppIDPublico es el app_id del widget con el que se consulta el endpoint
// que exige sesión (favorite/getUserFavorites). Es el mismo que usa el pool de
// sesiones para validar un token suelto: los métodos de usuario no se firman,
// así que no importa con qué app_id se firmó el canal.
const qobuzAppIDPublico = "735532640"

// timeoutControlSesion acota el chequeo del token: es un extra del informe y no
// puede retrasarlo si Qobuz no responde.
const timeoutControlSesion = 4 * time.Second

// tokenQobuzAutentica pregunta a Qobuz si [token] sirve como sesión. 200 = vive;
// 401/403 = vencido o revocado; cualquier otra cosa (red, 5xx) devuelve error
// para no acusar al token de un problema que no es suyo.
//
// Por qué existe: /track/getFileUrl contesta 200 con MP3 320 tanto con un token
// vencido como con una cuenta sin suscripción. Sin este control el informe no
// puede decirle al usuario CUÁL de las dos cosas arreglar.
func (c *Client) tokenQobuzAutentica(ctx context.Context, base, token string) (bool, error) {
	destino := strings.TrimRight(base, "/") + "/favorite/getUserFavorites?app_id=" +
		url.QueryEscape(qobuzAppIDPublico) + "&user_auth_token=" + url.QueryEscape(token) +
		"&type=tracks&limit=1"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, destino, nil)
	if err != nil {
		return false, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("X-App-Id", qobuzAppIDPublico)

	resp, err := c.http.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	switch resp.StatusCode {
	case http.StatusOK:
		return true, nil
	case http.StatusUnauthorized, http.StatusForbidden:
		return false, nil
	default:
		return false, fmt.Errorf("control de sesión: HTTP %d", resp.StatusCode)
	}
}

// acortarMotivo deja el motivo legible sin volcar la cadena entera.
func acortarMotivo(motivo string) string {
	motivo = strings.TrimSpace(strings.ReplaceAll(motivo, "\n", " "))
	if len(motivo) > 120 {
		return motivo[:120] + "…"
	}
	return motivo
}
