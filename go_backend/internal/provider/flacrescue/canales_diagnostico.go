// ─────────────────────────────────────────────────────────────
// canales_diagnostico.go — Informe del ESTADO de los canales del
// rescate (espejos, Qobuz firmado, arcod, stash-relay, sitios).
//
// Por qué existe: los canales ya saben cuándo están caídos —espejo sin
// cuentas, arcod en backoff, relay ocupado, cuenta Qobuz sin sesión—,
// pero ese aprendizaje vivía solo en el log de la carrera. Sin un
// informe, el usuario no puede distinguir "este canal está apagado a
// propósito" de "este canal se cayó" ni saber si le queda algo sano
// antes de esperar una reproducción entera.
//
// Qué hace: traduce el estado que los canales YA publicaron a un veredicto
// por canal. NO sale a la red: mira las pausas por fallo de pool (relay,
// arcod), las marcas de espejo sin cuentas y de Qobuz sin sesión, y la
// configuración vigente. La única cifra con costo es [Agotado], que reusa
// el mismo cortocircuito que ya corre en la resolución (rescateAgotado).
//
// Se conecta con: extensions_actions_flacrescue.go (acción probarCanales) y
// resolucion.go / client.go / arcod_cuota.go / qobuz_estado.go (las
// funciones de estado que reusa, para que el informe no mienta).
// Parte del flujo: Ajustes → Credenciales → Rescate de audio.
// ─────────────────────────────────────────────────────────────

package flacrescue

import "fmt"

// Estados posibles de un canal. Son estables: la interfaz los usa para
// pintar el resultado (ok / aviso / apagado).
const (
	// EstadoCanalOk: el canal está encendido y sin marcas de fallo vigentes.
	EstadoCanalOk = "ok"
	// EstadoCanalApagado: el canal está apagado por ajuste.
	EstadoCanalApagado = "apagado"
	// EstadoCanalSinConfigurar: no hay nada que probar (p. ej. sin espejos).
	EstadoCanalSinConfigurar = "sin_configurar"
	// EstadoCanalSinCuentas: el canal avisó que su pool quedó sin credenciales.
	EstadoCanalSinCuentas = "sin_cuentas"
	// EstadoCanalPausado: el canal está en backoff/pausa por fallos recientes.
	EstadoCanalPausado = "pausado"
	// EstadoCanalSinSesion: las claves sirven, pero la cuenta Qobuz no tiene
	// suscripción (entrega muestra o MP3).
	EstadoCanalSinSesion = "sin_sesion"
)

// EstadoDeCanal es el veredicto de UN canal del rescate.
type EstadoDeCanal struct {
	Nombre  string `json:"nombre"`
	Estado  string `json:"estado"`
	Detalle string `json:"detalle"`
}

// DiagnosticoCanales es el informe que consume la interfaz. [Agotado] es la
// misma pregunta que se hace la resolución antes de correr la carrera: si es
// true, ningún canal puede entregar audio ahora mismo.
type DiagnosticoCanales struct {
	Canales []EstadoDeCanal `json:"canales"`
	Agotado bool            `json:"agotado"`
	Detalle string          `json:"detalle"`
}

// DiagnosticoCanales recorre el estado de todos los canales SIN tocar la red.
func (c *Client) DiagnosticoCanales() DiagnosticoCanales {
	canales := []EstadoDeCanal{
		c.estadoStashRelay(),
		c.estadoArcod(),
		c.estadoQobuzFirmado(),
		c.estadoEspejos(),
		c.estadoSitios(),
	}

	agotado := c.rescateAgotado()
	detalle := "Todos los canales pueden entregar audio ahora mismo."
	if agotado {
		detalle = "Ningún canal puede entregar audio ahora mismo: revisá los que están en " +
			"apagado/sin_cuentas/pausado (el rescate rápido sigue por la descarga real)."
	}

	return DiagnosticoCanales{Canales: canales, Agotado: agotado, Detalle: detalle}
}

// estadoStashRelay informa el canal del relay sin pérdida.
func (c *Client) estadoStashRelay() EstadoDeCanal {
	caso := EstadoDeCanal{Nombre: nombreStashRelay}
	switch {
	case !c.stashEncendido():
		caso.Estado = EstadoCanalApagado
		caso.Detalle = "Apagado por ajuste (stash_relay=off)."
	case c.relayPausado():
		caso.Estado = EstadoCanalPausado
		caso.Detalle = "El relay avisó que está ocupado o sin cupo (503/429); se reintenta solo."
	default:
		caso.Estado = EstadoCanalOk
		caso.Detalle = "Encendido: entrega FLAC de Qobuz sin cuenta propia."
	}
	return caso
}

// estadoArcod informa el canal arcod (catálogo + stream de Qobuz).
func (c *Client) estadoArcod() EstadoDeCanal {
	caso := EstadoDeCanal{Nombre: nombreArcod}
	switch {
	case !c.arcodEncendido():
		caso.Estado = EstadoCanalApagado
		caso.Detalle = "Apagado por ajuste (arcod=off)."
	case c.enPausaArcod():
		caso.Estado = EstadoCanalPausado
		caso.Detalle = "En backoff por pool vacío. Si es una instancia PROPIA, " +
			"cargá QOBUZ_AUTH_TOKENS y volvé a pegarla en Ajustes para levantarlo."
	default:
		caso.Estado = EstadoCanalOk
		caso.Detalle = fmt.Sprintf("Encendido en %s.", c.baseArcodActiva())
	}
	return caso
}

// estadoQobuzFirmado informa el canal firmado con las credenciales del usuario.
func (c *Client) estadoQobuzFirmado() EstadoDeCanal {
	_, token, _, keysURL, appID, secreto := c.qobuzConfig()
	canales := len(defaultKeysURLs)
	hayManual := appID != "" && secreto != ""
	hayOrigen := keysURL != ""

	caso := EstadoDeCanal{Nombre: nombreQobuzFirmado}
	switch {
	case !hayManual && !hayOrigen && canales == 0:
		caso.Estado = EstadoCanalApagado
		caso.Detalle = "Sin app_id/app_secret ni origen de claves: el canal no se usa."
	case c.qobuzSinSesion():
		caso.Estado = EstadoCanalSinSesion
		if token != "" {
			caso.Detalle = "El token no sirve o la cuenta no tiene suscripción: Qobuz " +
				"entrega muestra/MP3. Pegá un user_auth_token nuevo (o cargalo en el Worker)."
		} else {
			caso.Detalle = "Sin user_auth_token: Qobuz entrega una muestra de 30 s. " +
				"Pegá qobuz_user_token (suscripción) o ponelo como QOBUZ_USER_TOKEN del Worker."
		}
	default:
		caso.Estado = EstadoCanalOk
		if token == "" {
			caso.Detalle = "Con claves, pero sin user_auth_token: Qobuz puede degradar a " +
				"muestra/MP3. Con suscripción, pegá qobuz_user_token."
		} else {
			caso.Detalle = "Con claves y token de usuario."
		}
	}
	return caso
}

// estadoEspejos informa el canal de espejos por ISRC (contrato monochrome).
func (c *Client) estadoEspejos() EstadoDeCanal {
	espejos := c.Mirrors()
	caso := EstadoDeCanal{Nombre: nombreEspejos}
	switch {
	case len(espejos) == 0:
		caso.Estado = EstadoCanalSinConfigurar
		caso.Detalle = "Sin espejos configurados (mirrors=off o vacío). Es lo esperable " +
			"mientras los públicos estén sin ARLs de Deezer vivos."
	case len(c.espejosVivos()) == 0:
		caso.Estado = EstadoCanalSinCuentas
		caso.Detalle = "Los espejos configurados avisaron que su pool quedó sin cuentas vivas."
	default:
		caso.Estado = EstadoCanalOk
		caso.Detalle = fmt.Sprintf("%d espejo(s) configurado(s).", len(espejos))
	}
	return caso
}

// estadoSitios informa el canal de sitios raspables de FLAC (superflac y otras
// instancias del mismo software).
func (c *Client) estadoSitios() EstadoDeCanal {
	n := len(c.listaSitios())
	caso := EstadoDeCanal{Nombre: "sitios"}
	if n == 0 {
		caso.Estado = EstadoCanalApagado
		caso.Detalle = "Apagados por ajuste (sitios=off)."
		return caso
	}
	caso.Estado = EstadoCanalOk
	caso.Detalle = fmt.Sprintf("%d sitio(s) raspable(s) habilitado(s).", n)
	return caso
}
