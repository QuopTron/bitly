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
// Se conecta con: extensions_actions_flacrescue.go (se lo devuelve a la
// interfaz de Ajustes) y qobuz_firmado.go / qobuz_archivo.go (las mismas
// funciones que usa la resolución, para que el informe no mienta).
// Parte del flujo: Ajustes → Credenciales → Rescate de audio.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
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

	detalle := "Las claves son válidas, pero Qobuz entrega MP3 320 en vez de FLAC: sin " +
		"token de suscriptor Qobuz degrada el stream. Pegá qobuz_user_token (tu cuenta) " +
		"o dejá el FLAC en manos de los espejos o de Soulseek."
	if token != "" {
		detalle = "Las claves son válidas y hay token, pero Qobuz igual entregó MP3 320: " +
			"revisá que el token sea de una cuenta con suscripción activa."
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

// acortarMotivo deja el motivo legible sin volcar la cadena entera.
func acortarMotivo(motivo string) string {
	motivo = strings.TrimSpace(strings.ReplaceAll(motivo, "\n", " "))
	if len(motivo) > 120 {
		return motivo[:120] + "…"
	}
	return motivo
}
