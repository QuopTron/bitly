// client.go — cliente de Soulseek para el backend de Go.
//
// QUÉ APORTA AL PIPELINE
// Soulseek es la única red de catálogo comercial a la que se entra SIN
// invitación, SIN pago y SIN dar datos personales: el alta es del lado del
// cliente (nombre + contraseña que elegís), no hay mail ni captcha.
//
// SU LÍMITE, DICHO CLARO
// El protocolo NO transporta ISRC. El "match" es texto sobre el nombre del
// archivo, así que la identidad se confirma por DURACIÓN (atributo 1 de cada
// resultado) contra la duración que ya conocemos del catálogo (Deezer/Qobuz/
// Tidal devuelven el ISRC y la duración GRATIS y sin cuenta). Ese cruce es el
// "ISRC perfecto": el ISRC identifica, la duración verifica.
//
// REGLA DE LA RED (por qué el alta NO se automatiza ni se esconde)
// El spec oficial dice textual: "It is unacceptable to use randomly generated
// usernames, as such automated scripting is disallowed by the official server
// rules." Por eso acá el usuario escribe SU nombre y la app solo genera la
// contraseña (que además debe poder verse: Soulseek no tiene recuperación).
// La cuenta se crea al conectar por primera vez con ese nombre — es el propio
// servidor el que la da de alta —, así que "Siguiente" la crea sin trámites.
//
// Se conecta con: exports_init_providers.go (registro) y
// extensions_settings.go (SetSettings vía setExtensionSettings) →
// Ajustes → Credenciales → Soulseek.
package soulseek

import (
	"bufio"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"net"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

const (
	// Servidor oficial de la red.
	servidorPorDefecto = "server.slsknet.org:2242"

	// Puerto donde escuchamos las conexiones F que abre el par que nos sube el
	// archivo (2234 es el clásico de la red).
	puertoPorDefecto = 2234

	// Cuánto se espera respuestas de pares tras lanzar una búsqueda. En
	// Soulseek las respuestas llegan por el servidor durante varios
	// segundos; cortar antes devuelve resultados incompletos.
	esperaBusquedaPorDefecto = 7 * time.Second

	// Tope de archivos acumulados por búsqueda (la red devuelve muchos
	// duplicados del mismo tema entre distintos pares).
	maxResultadosBusqueda = 400
)

// Client es el cliente de Soulseek. Es seguro para uso concurrente: las
// operaciones de red se serializan porque el protocolo admite UNA sola
// conexión al servidor por usuario.
type Client struct {
	mu       sync.RWMutex
	usuario  string
	password string
	conn     net.Conn
	lector   *bufio.Reader
	token    uint32
	// ultimos es el índice de los archivos vistos en la última búsqueda,
	// para que GetTrack(id) pueda describir un resultado concreto.
	ultimos map[string]ArchivoEncontrado
	// puertoAnunciado es el puerto donde escuchamos las conexiones F que ABRE
	// el par (ver transfer_protocol.go: el que sube inicia la conexión de
	// datos). 0 = el que se configure o 2234.
	puertoAnunciado uint16
	listener        net.Listener
	bombaIniciada   bool
	// servidor permite apuntar a otro host:puerto (diagnóstico y tests).
	servidor string

	// muRed protege SOLO el estado de despacho de mensajes. Es un mutex
	// distinto de [mu] a propósito: la bomba de lectura lo toma mientras
	// Buscar/Descargar mantienen [mu] esperando respuestas, así que compartir
	// un solo mutex daría un abrazo mortal.
	// muEscritura serializa TODA escritura al socket del servidor: si dos
	// operaciones escriben a la vez, los mensajes se entrelazan y el framing se
	// corrompe. Guarda su propia referencia al socket para que escribir no
	// necesite [mu]: varias operaciones mantienen [mu] mientras esperan una
	// respuesta, y pedirlo para escribir sería un abrazo mortal.
	muEscritura   sync.Mutex
	connEscritura net.Conn

	muRed       sync.Mutex
	busquedas   map[uint32]chan []ArchivoEncontrado
	direcciones map[string]chan direccionPeer
	esperandoF  map[uint32]chan net.Conn
	muerto      chan struct{}
	caido       bool
	// generacion identifica la conexión actual. Cada bomba de lectura lleva la
	// suya, y solo puede marcar caída si sigue siendo la vigente: si no, la
	// bomba de una conexión vieja que muere tarde mataría la sesión nueva y el
	// cliente quedaría reconectando en bucle. Se protege con muRed, igual que
	// caido/muerto (la bomba no puede tomar [mu]).
	generacion uint64
}

// NewClient crea el cliente. Sin credenciales queda inerte: no abre ninguna
// conexión hasta que haya usuario y contraseña (igual que redacted), así el
// arranque de la app nunca depende de la red de Soulseek.
func NewClient(usuario, password string) *Client {
	return &Client{
		usuario:     usuario,
		password:    password,
		ultimos:     map[string]ArchivoEncontrado{},
		busquedas:   map[uint32]chan []ArchivoEncontrado{},
		direcciones: map[string]chan direccionPeer{},
		esperandoF:  map[uint32]chan net.Conn{},
		muerto:      make(chan struct{}),
	}
}

func (c *Client) Name() string { return "soulseek" }

// SetSettings aplica lo que llega de Flutter (setExtensionSettings con
// extension_id "soulseek"):
//
//	usuario  → nombre de usuario de Soulseek (lo elige el usuario)
//	password → contraseña generada por la app
//	servidor → host:puerto alternativo (opcional, para diagnóstico)
//
// Best-effort: un valor inválido se ignora. Si cambian las credenciales se
// cierra la conexión actual para forzar un login nuevo.
func (c *Client) SetSettings(settings map[string]string) {
	if len(settings) == 0 {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	cambió := false
	if v, hay := settings["usuario"]; hay {
		v = strings.TrimSpace(v)
		if v != c.usuario {
			c.usuario = v
			cambió = true
		}
	}
	if v, hay := settings["password"]; hay && v != "" && v != c.password {
		c.password = v
		cambió = true
	}
	if v := strings.TrimSpace(settings["servidor"]); v != "" && v != c.servidor {
		c.servidor = v
		cambió = true
	}
	if v := strings.TrimSpace(settings["puerto"]); v != "" {
		if p, err := strconv.Atoi(v); err == nil && p > 0 && p <= 65535 {
			c.puertoAnunciado = uint16(p)
		}
	}
	if cambió {
		c.cerrarBloqueado()
	}
}

// Credenciales devuelve lo configurado (para estado/diagnóstico). Nunca se
// loguea la contraseña.
func (c *Client) Credenciales() (string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.usuario, c.password != ""
}

// ── Conexión ─────────────────────────────────────────────────────────────

// Conectar abre la conexión al servidor y hace login. Si el nombre no existe
// todavía en la red, el servidor crea la cuenta en este mismo paso: conectar
// y registrarse son la misma operación en Soulseek.
func (c *Client) Conectar(timeout time.Duration) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.conexionVivaBloqueado(timeout)
}

// conexionVivaBloqueado garantiza una conexión UTILIZABLE, no solo una
// existente. Si la anterior murió (el servidor la cerró, o se cambiaron las
// credenciales) la descarta y reconecta.
//
// Sin esto, una sola caída dejaría a Soulseek devolviendo "se perdió la
// conexión" para siempre: el socket seguía en [c.conn], así que nadie volvía a
// conectar. Desde afuera eso se ve igual que "esa canción no está en la red",
// que es el peor síntoma posible — indistinguible de un problema de la red.
func (c *Client) conexionVivaBloqueado(timeout time.Duration) error {
	if c.conn != nil {
		c.muRed.Lock()
		caido := c.caido
		c.muRed.Unlock()
		if !caido {
			return nil
		}
		c.cerrarBloqueado()
	}
	return c.conectarBloqueado(timeout)
}

func (c *Client) conectarBloqueado(timeout time.Duration) error {
	if c.conn != nil {
		return nil
	}
	if strings.TrimSpace(c.usuario) == "" || c.password == "" {
		return fmt.Errorf("soulseek: falta el usuario o la contraseña (Ajustes → Credenciales → Soulseek)")
	}
	if timeout <= 0 {
		timeout = 15 * time.Second
	}
	destino := c.servidor
	if destino == "" {
		destino = servidorPorDefecto
	}
	conn, err := net.DialTimeout("tcp", destino, timeout)
	if err != nil {
		return fmt.Errorf("soulseek: no se pudo conectar a %s: %w", destino, err)
	}
	_ = conn.SetDeadline(time.Now().Add(timeout))
	if _, err := conn.Write(codificarLogin(c.usuario, c.password)); err != nil {
		conn.Close()
		return fmt.Errorf("soulseek: error enviando el login: %w", err)
	}
	lector := bufio.NewReader(conn)
	codigo, cuerpo, err := leerMensaje(lector)
	if err != nil {
		conn.Close()
		return fmt.Errorf("soulseek: error leyendo la respuesta del login: %w", err)
	}
	if codigo != srvLogin {
		conn.Close()
		return fmt.Errorf("soulseek: respuesta inesperada del servidor (código %d)", codigo)
	}
	resultado := decodificarLogin(cuerpo)
	if !resultado.OK {
		conn.Close()
		// El motivo se conserva en el ERROR (no solo en el texto) para que la
		// UI pueda distinguir qué puede arreglar el usuario de qué no: un
		// nombre tomado se resuelve eligiendo otro; una caída de red, no.
		switch resultado.Motivo {
		case "INVALIDPASS":
			// El texto del servidor y el nuestro dicen lo mismo: se conserva
			// el nuestro (más corto y accionable) y no se duplica.
			return ErrNombreTomado
		case "INVALIDUSERNAME":
			// Se conserva el detalle traducido del servidor ("máximo 30
			// caracteres", "caracteres no permitidos", ...) porque es lo
			// único que le dice al usuario QUÉ corregir.
			if resultado.Detalle == "" {
				return ErrNombreInvalido
			}
			return fmt.Errorf("%w: %s", ErrNombreInvalido, traducirDetalle(resultado.Detalle))
		}
		return fmt.Errorf("soulseek: %s", resultado.MensajeUsuario())
	}
	// El login ya pasó: sin deadline, la conexión queda viva para buscar.
	_ = conn.SetDeadline(time.Time{})
	c.conn = conn
	c.lector = lector
	c.muEscritura.Lock()
	c.connEscritura = conn
	c.muEscritura.Unlock()

	// La lectura pasa a un hilo propio: las respuestas del servidor (resultados
	// de búsqueda, direcciones de pares) llegan por el mismo socket y hay que
	// despacharlas sin que un pedido bloquee a los demás.
	c.muRed.Lock()
	c.caido = false
	c.muerto = make(chan struct{})
	c.generacion++
	gen := c.generacion
	iniciarBomba := !c.bombaIniciada
	c.bombaIniciada = true
	c.muRed.Unlock()
	if iniciarBomba {
		go c.bombear(conn, lector, gen)
	}
	// Anunciar el puerto de descarga es best-effort acá: si falla, la búsqueda
	// sigue funcionando y solo la descarga lo va a reclamar.
	_ = c.asegurarEscuchaBloqueado()
	return nil
}

// Cerrar cierra la conexión al servidor.
func (c *Client) Cerrar() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.cerrarBloqueado()
}

func (c *Client) cerrarBloqueado() {
	if c.listener != nil {
		_ = c.listener.Close()
		c.listener = nil
	}
	if c.conn != nil {
		_ = c.conn.Close()
	}
	c.conn = nil
	c.lector = nil
	c.muEscritura.Lock()
	c.connEscritura = nil
	c.muEscritura.Unlock()
	c.muRed.Lock()
	c.bombaIniciada = false
	c.muRed.Unlock()
	c.marcarCaido()
}

// marcarCaido cierra la señal de pérdida una sola vez, para que toda espera en
// curso (búsqueda, dirección, conexión F) falle rápido en vez de agotar su
// propio timeout.
func (c *Client) marcarCaido() {
	c.muRed.Lock()
	defer c.muRed.Unlock()
	if !c.caido {
		c.caido = true
		close(c.muerto)
	}
}

// marcarCaidoSiVigente es marcarCaido para las bombas: solo la bomba de la
// conexión ACTUAL puede declararla caída. Una bomba vieja (la de una conexión
// ya reemplazada) puede morir tarde — al cerrarse su socket — y sin esta
// comprobación mataría la sesión nueva, dejando al cliente reconectando en
// bucle contra un servidor que responde bien.
func (c *Client) marcarCaidoSiVigente(gen uint64) {
	c.muRed.Lock()
	defer c.muRed.Unlock()
	if gen != c.generacion || c.caido {
		return
	}
	c.caido = true
	close(c.muerto)
}

// escribirServidor es el único camino para escribirle al servidor.
func (c *Client) escribirServidor(msg []byte) error {
	c.muEscritura.Lock()
	defer c.muEscritura.Unlock()
	conn := c.connEscritura
	if conn == nil {
		return fmt.Errorf("soulseek: no hay conexión con el servidor")
	}
	_ = conn.SetWriteDeadline(time.Now().Add(30 * time.Second))
	_, err := conn.Write(msg)
	return err
}

// bombear lee del servidor y despacha cada respuesta a quien la espera. Corre
// en un solo hilo (el protocolo no admite otro lector) y NO toma [mu] a
// propósito: las operaciones que esperan respuestas lo tienen tomado.
func (c *Client) bombear(conn net.Conn, lector *bufio.Reader, gen uint64) {
	for {
		codigo, cuerpo, err := leerMensaje(lector)
		if err != nil {
			c.marcarCaidoSiVigente(gen)
			_ = conn.Close()
			return
		}
		switch codigo {
		case srvFileSearchReply:
			_, token, archivos, errP := decodificarFileSearchReply(cuerpo)
			if errP != nil {
				continue
			}
			c.muRed.Lock()
			canal := c.busquedas[token]
			c.muRed.Unlock()
			if canal != nil {
				select {
				case canal <- archivos:
				default: // el que esperaba ya se fue o va lento: se descarta
				}
			}
		case srvGetPeerAddress:
			d, errP := decodificarGetPeerAddress(cuerpo)
			if errP != nil {
				continue
			}
			c.muRed.Lock()
			canal := c.direcciones[d.Usuario]
			c.muRed.Unlock()
			if canal != nil {
				select {
				case canal <- d:
				default:
				}
			}
		}
	}
}

// pedirDireccion pregunta al servidor dónde está un par.
func (c *Client) pedirDireccion(usuario string, espera time.Duration) (direccionPeer, error) {
	if err := c.Conectar(20 * time.Second); err != nil {
		return direccionPeer{}, err
	}
	canal := make(chan direccionPeer, 1)
	c.muRed.Lock()
	if c.caido {
		c.muRed.Unlock()
		return direccionPeer{}, fmt.Errorf("soulseek: la conexión con el servidor se perdió")
	}
	c.direcciones[usuario] = canal
	muerto := c.muerto
	c.muRed.Unlock()
	defer func() {
		c.muRed.Lock()
		delete(c.direcciones, usuario)
		c.muRed.Unlock()
	}()

	if err := c.escribirServidor(codificarGetPeerAddress(usuario)); err != nil {
		return direccionPeer{}, fmt.Errorf("soulseek: no se pudo pedir la dirección del par: %w", err)
	}
	if espera <= 0 {
		espera = 15 * time.Second
	}
	select {
	case d := <-canal:
		return d, nil
	case <-muerto:
		return direccionPeer{}, fmt.Errorf("soulseek: la conexión con el servidor se perdió")
	case <-time.After(espera):
		return direccionPeer{}, fmt.Errorf("soulseek: el servidor no dio la dirección de %q", usuario)
	}
}

// Conectado indica si hay una sesión viva.
func (c *Client) Conectado() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.conn != nil
}

// ProbarCredenciales conecta, verifica y cierra: es la acción del botón
// "Siguiente" en Ajustes, que además es lo que da de alta la cuenta.
func (c *Client) ProbarCredenciales() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.conexionVivaBloqueado(20 * time.Second); err != nil {
		return "", err
	}
	usuario := c.usuario
	c.cerrarBloqueado()
	return usuario, nil
}

// ── Búsqueda ─────────────────────────────────────────────────────────────

// Buscar lanza una búsqueda en la red y junta las respuestas que lleguen
// dentro de `espera`. Devuelve TODOS los resultados (lossy incluidos, con su
// extensión real) para que la capa de matching decida; filtrar acá escondería
// candidatos que sí sirven como respaldo.
func (c *Client) Buscar(consulta string, espera time.Duration) ([]ArchivoEncontrado, error) {
	if strings.TrimSpace(consulta) == "" {
		return nil, fmt.Errorf("soulseek: consulta vacía")
	}
	if espera <= 0 {
		espera = esperaBusquedaPorDefecto
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if err := c.conexionVivaBloqueado(20 * time.Second); err != nil {
		return nil, err
	}
	c.token++
	token := c.token

	// Las respuestas llegan despachadas por la bomba; acá se registra el canal
	// de ESTE token y se espera lo que llegue dentro del plazo. La red no avisa
	// cuándo terminó de responder, así que el corte es el criterio.
	canal := make(chan []ArchivoEncontrado, 64)
	c.muRed.Lock()
	if c.caido {
		c.muRed.Unlock()
		return nil, fmt.Errorf("soulseek: la conexión con el servidor se perdió")
	}
	c.busquedas[token] = canal
	muerto := c.muerto
	c.muRed.Unlock()
	defer func() {
		c.muRed.Lock()
		delete(c.busquedas, token)
		c.muRed.Unlock()
	}()

	if err := c.escribirServidor(codificarFileSearch(token, consulta)); err != nil {
		c.cerrarBloqueado()
		return nil, fmt.Errorf("soulseek: error enviando la búsqueda: %w", err)
	}
	limite := time.After(espera)
	var salida []ArchivoEncontrado
	recogiendo := true
	for recogiendo && len(salida) < maxResultadosBusqueda {
		select {
		case archivos := <-canal:
			salida = append(salida, archivos...)
		case <-muerto:
			recogiendo = false
		case <-limite:
			recogiendo = false
		}
	}
	for _, a := range salida {
		c.ultimos[a.Codigo()] = a
	}
	return salida, nil
}

// BuscarLossless hace la búsqueda y devuelve solo archivos sin pérdida,
// ordenados por MejorCandidato respecto de la duración conocida.
func (c *Client) BuscarLossless(consulta string, duracionSeg, toleranciaSeg int) ([]ArchivoEncontrado, error) {
	todos, err := c.Buscar(consulta, 0)
	if err != nil {
		return nil, err
	}
	var lossless []ArchivoEncontrado
	for _, a := range todos {
		if a.EsLossless() {
			lossless = append(lossless, a)
		}
	}
	if duracionSeg > 0 {
		lossless = OrdenarCandidatos(lossless, duracionSeg, toleranciaSeg)
	} else {
		lossless = OrdenarCandidatos(lossless, 0, 0)
	}
	return lossless, nil
}

// ── Selección de candidatos ──────────────────────────────────────────────

// diferenciaDuración devuelve la distancia en segundos, o -1 si no hay dato.
func diferenciaDuracion(a ArchivoEncontrado, duracionSeg int) int {
	if duracionSeg <= 0 || a.DuracionS <= 0 {
		return -1
	}
	d := a.DuracionS - duracionSeg
	if d < 0 {
		d = -d
	}
	return d
}

// CoincideDuracion dice si el archivo cae dentro de la tolerancia. Es el
// criterio de identidad fuerte del provider: sin ISRC en el protocolo, la
// duración es lo único que confirma que es la misma grabación y no un remix,
// un live o un re-subido acortado.
func CoincideDuracion(a ArchivoEncontrado, duracionSeg, toleranciaSeg int) bool {
	if duracionSeg <= 0 || a.DuracionS <= 0 {
		return false
	}
	if toleranciaSeg <= 0 {
		toleranciaSeg = 3
	}
	return diferenciaDuracion(a, duracionSeg) <= toleranciaSeg
}

// OrdenarCandidatos ordena por preferencia real: primero coincidencia exacta
// de duración, luego bit depth y sample rate (FLAC 24/96 sobre FLAC 16/44),
// luego disponibilidad (slot libre, cola corta, par rápido) y por último
// archivos sin pérdida sobre lossy. Con duracionSeg=0 no se descarta nada por
// duración: solo se prioriza.
func OrdenarCandidatos(archivos []ArchivoEncontrado, duracionSeg, toleranciaSeg int) []ArchivoEncontrado {
	salida := append([]ArchivoEncontrado(nil), archivos...)
	mejor := func(a, b ArchivoEncontrado) bool {
		if duracionSeg > 0 {
			da, db := diferenciaDuracion(a, duracionSeg), diferenciaDuracion(b, duracionSeg)
			// -1 significa "sin duración": se considera peor que cualquier
			// distancia real, porque no se puede verificar.
			if da < 0 && db >= 0 {
				return false
			}
			if db < 0 && da >= 0 {
				return true
			}
			if da >= 0 && db >= 0 && da != db {
				return da < db
			}
		}
		if a.EsLossless() != b.EsLossless() {
			return a.EsLossless()
		}
		if a.BitDepth != b.BitDepth {
			return a.BitDepth > b.BitDepth
		}
		if a.SampleHz != b.SampleHz {
			return a.SampleHz > b.SampleHz
		}
		if a.SlotLibre != b.SlotLibre {
			return a.SlotLibre
		}
		if a.Cola != b.Cola {
			return a.Cola < b.Cola
		}
		return a.Velocidad > b.Velocidad
	}
	// Inserción: listas de búsqueda son cortas (±cientos) y así el orden es
	// estable, que importa para que el desempate sea predecible.
	for i := 1; i < len(salida); i++ {
		for j := i; j > 0 && mejor(salida[j], salida[j-1]); j-- {
			salida[j], salida[j-1] = salida[j-1], salida[j]
		}
	}
	return salida
}

// MejorCandidato devuelve el mejor archivo para esa duración, o nil si la
// lista está vacía. Con duracionSeg > 0 y tolerancia > 0 SOLO acepta
// coincidencias dentro de la tolerancia: es la regla de "match perfecto"
// aplicada del lado de Soulseek.
func MejorCandidato(archivos []ArchivoEncontrado, duracionSeg, toleranciaSeg int) *ArchivoEncontrado {
	orden := OrdenarCandidatos(archivos, duracionSeg, toleranciaSeg)
	if len(orden) == 0 {
		return nil
	}
	elegido := orden[0]
	if duracionSeg > 0 && toleranciaSeg > 0 && !CoincideDuracion(elegido, duracionSeg, toleranciaSeg) {
		return nil
	}
	return &elegido
}

// ── Generación de contraseña ─────────────────────────────────────────────

const alfabetoPassword = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"

// GenerarPassword crea una contraseña aleatoria de verdad (crypto/rand).
//
// OJO: no se deriva del usuario a propósito. El nombre de usuario de
// Soulseek es PUBLICO (aparece en los resultados de búsqueda de toda la red),
// así que una contraseña derivada de él sería una cuenta regalada. Y tiene
// que poder verse/exportarse: Soulseek NO tiene recuperación de contraseña.
func GenerarPassword() string {
	const largo = 24
	var b strings.Builder
	for i := 0; i < largo; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(alfabetoPassword))))
		if err != nil {
			// Sin entropía no se inventa una clave: mejor fallar visible.
			return ""
		}
		b.WriteByte(alfabetoPassword[n.Int64()])
	}
	return b.String()
}

// ErrNombreTomado: el servidor respondió INVALIDPASS, o sea que el nombre ya
// existe en la red con OTRA contraseña. Es el único rechazo que el usuario
// arregla solo —eligiendo otro nombre— y por eso se distingue del resto.
// El texto es el que ve el usuario: no se envuelve con detalle técnico.
var ErrNombreTomado = errors.New("soulseek: ese nombre ya está tomado en la red: elegí otro")

// ErrNombreInvalido: el servidor rechazó el nombre en sí (vacío, muy largo,
// caracteres no permitidos, espacios en los bordes).
var ErrNombreInvalido = errors.New("soulseek: ese nombre de usuario no es válido")

// ValidarUsuario comprueba el nombre contra las reglas que el propio servidor
// aplica (están en el spec, sección "Login Rejection Details"): no vacío, sin
// espacios al principio ni al final, máximo 30 caracteres y solo ASCII
// imprimible. Se valida ANTES de tocar la red para no gastar una conexión en
// un nombre que el servidor va a rechazar igual.
func ValidarUsuario(usuario string) error {
	if usuario == "" {
		return fmt.Errorf("%w: escribí un nombre de usuario", ErrNombreInvalido)
	}
	if strings.TrimSpace(usuario) != usuario {
		return fmt.Errorf("%w: el nombre no puede empezar ni terminar con espacios", ErrNombreInvalido)
	}
	if len([]rune(usuario)) > 30 {
		return fmt.Errorf("%w: el nombre puede tener como máximo 30 caracteres", ErrNombreInvalido)
	}
	for _, r := range usuario {
		if r < 0x20 || r > 0x7E {
			return fmt.Errorf("%w: el nombre solo admite caracteres ASCII imprimibles (sin acentos ni emojis)", ErrNombreInvalido)
		}
	}
	return nil
}

// ─────────────────────────────────────────────────────────────────────────
// provider.Provider
// Soulseek resuelve AUDIO (por búsqueda textual), no catálogo: no tiene
// metadata propia (sin ISRC, sin carátula, sin álbum).
// ─────────────────────────────────────────────────────────────────────────

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	archivos, err := c.Buscar(query, 0)
	if err != nil {
		return nil, err
	}
	orden := OrdenarCandidatos(archivos, 0, 0)
	if limit <= 0 {
		limit = 20
	}
	// Un mismo tema aparece decenas de veces (mismo archivo en muchos pares):
	// se deduplica por tamaño + extensión para que la lista sea legible.
	vistos := map[string]bool{}
	var salida []provider.TrackResult
	for _, a := range orden {
		clave := fmt.Sprintf("%d|%s|%d", a.Bytes, a.Extension, a.DuracionS)
		if vistos[clave] {
			continue
		}
		vistos[clave] = true
		// Artista y título se DERIVAN de la ruta compartida ("Artista - Tema"):
		// sin eso el ranking del repo descarta el candidato por artista ausente
		// y Soulseek pierde un match que tenía servido.
		artista, titulo := parsearNombreCompartido(a.Ruta)
		if titulo == "" {
			titulo = a.NombreArchivo()
		}
		salida = append(salida, provider.TrackResult{
			ID:       a.Codigo(),
			Title:    titulo,
			Artist:   artista,
			Duration: a.DuracionS * 1000, // la API del repo usa milisegundos
			Provider: c.Name(),
		})
		if len(salida) >= limit {
			break
		}
	}
	return salida, nil
}

func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, nil
}
func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, nil
}
func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}

func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	c.mu.Lock()
	a, hay := c.ultimos[id]
	c.mu.Unlock()
	if !hay {
		return nil, fmt.Errorf("soulseek: no hay un archivo con ese id (buscá primero)")
	}
	artista, titulo := parsearNombreCompartido(a.Ruta)
	if titulo == "" {
		titulo = a.NombreArchivo()
	}
	return &provider.TrackResult{
		ID:       a.Codigo(),
		Title:    titulo,
		Artist:   artista,
		Duration: a.DuracionS * 1000,
		Provider: c.Name(),
	}, nil
}

// GetTrackByISRC NO es posible: el protocolo de Soulseek no transporta ISRC y
// los nombres de archivo no lo traen. El puente correcto es al revés —
// resolver el ISRC a artista+título+duración con los catálogos que SÍ lo
// publican gratis (Deezer/Qobuz/Tidal) y verificar el resultado de Soulseek
// por duración con `BuscarLossless`/`CoincideDuracion`.
func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("soulseek: la red no publica ISRC; usá el cruce por duración (BuscarLossless con la duración del catálogo)")
}

func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	return nil, fmt.Errorf("soulseek: no maneja álbumes (solo archivos compartidos)")
}

func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	return nil, fmt.Errorf("soulseek: no maneja artistas (solo archivos compartidos)")
}

// GetStreamURL todavía no está implementado: reproducir requiere la conexión
// PEER A PEER (ConnectToPeer → QueueUpload → TransferRequest → conexión F),
// que es una etapa aparte de la búsqueda. Se devuelve un error explícito en
// vez de una URL que no suena, para que la cadena de fallback siga con la
// siguiente fuente en lugar de romperse en silencio.
func (c *Client) GetStreamURL(id, quality string) (string, error) {
	return "", fmt.Errorf("soulseek: la descarga peer-to-peer todavía no está cableada (la búsqueda sí funciona)")
}
