// transfer.go — la descarga P2P de Soulseek, con el flujo verificado.
//
// CÓMO CONECTA Y POR QUÉ IMPORTA
// El protocolo es contraintuitivo: para BAJAR un archivo, el que SUBE abre la
// conexión de datos. Nosotros hacemos tres cosas:
//  1. Abrimos una conexión P (control) hacia el par y le mandamos QueueUpload.
//  2. El par nos manda TransferRequest; respondemos aceptando con el tamaño.
//  3. El par abre una conexión F HACIA NOSOTROS, en el puerto que le
//     anunciamos al servidor con SetWaitPort.
//
// O sea que sin un puerto alcanzable no hay descarga, por más que la búsqueda
// funcione. En un celular detrás de NAT/CGNAT eso puede no estar disponible: es
// una limitación de la red, no del código, y por eso el error lo dice claro en
// vez de quedarse colgado.
//
// LO QUE ESTA RED NO PUEDE GARANTIZAR
// El archivo lo comparte un desconocido y el protocolo NO tiene checksums (lo
// dice su propia documentación). Contra eso quedan tres controles, todos
// locales: la extensión declarada se filtra ANTES de bajar, el resultado se
// revisa con audioguard (lista blanca de formatos, ejecutables rechazados) y
// —si es FLAC— se compara su duración real contra la del catálogo para
// confirmar que es la grabación pedida y no un remix o un archivo cortado.
package soulseek

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/audioguard"
)

// Tamaños y esperas por defecto de una descarga.
const (
	// Tope duro de bytes. Un FLAC de una canción no llega a esto; un par
	// hostil que declare un tamaño absurdo no puede llenarnos el disco.
	tamanoMaximoPorDefecto   = 2 << 30 // 2 GiB
	esperaDescargaPorDefecto = 3 * time.Minute
	// Sin datos durante este tiempo, la transferencia se corta: un par puede
	// quedarse "conectado" sin mandar nada para siempre.
	silencioMaximo = 45 * time.Second
)

// OpcionesDescarga ajusta la descarga. Todo tiene default usable.
type OpcionesDescarga struct {
	// DuracionEsperadaS es la duración del catálogo (0 = no se pudo saber).
	// Con este dato se verifica que el FLAC sea la grabación pedida.
	DuracionEsperadaS int
	// ToleranciaDuracionS permite diferencias de unos segundos (0 → 3).
	ToleranciaDuracionS int
	// TamanoMaximo acota los bytes aceptados (0 → 2 GiB).
	TamanoMaximo int64
	// Espera es el presupuesto total de la transferencia.
	Espera time.Duration
}

// ResultadoDescarga es lo que quedó en disco y qué se pudo verificar de él.
type ResultadoDescarga struct {
	Ruta               string
	Bytes              int64
	DuracionS          float64
	DuracionVerificada bool
	// Verificacion describe, en castellano, qué se comprobó. Se devuelve para
	// poder mostrarlo: "verificado por duración" y "solo por formato" no son lo
	// mismo y el usuario tiene derecho a saberlo.
	Verificacion string
}

// conexionPar es la conexión P (control) con un par.
type conexionPar struct {
	conn   net.Conn
	lector *bufio.Reader
}

func (p *conexionPar) escribir(msg []byte) error {
	p.conn.SetWriteDeadline(time.Now().Add(30 * time.Second))
	_, err := p.conn.Write(msg)
	return err
}

func (p *conexionPar) cerrar() {
	if p != nil && p.conn != nil {
		_ = p.conn.Close()
	}
}

// Descargar baja [archivo] al [destino] y devuelve qué se verificó.
//
// El archivo se escribe en un temporal y solo se renombra al destino cuando
// pasó la validación: nunca queda un archivo sin revisar con el nombre final.
func (c *Client) Descargar(archivo ArchivoEncontrado, destino string, op OpcionesDescarga) (ResultadoDescarga, error) {
	var res ResultadoDescarga
	if archivo.Usuario == "" || archivo.Ruta == "" {
		return res, fmt.Errorf("soulseek: el archivo no tiene par o ruta")
	}
	// 1) Filtro de extensión ANTES de transferir un solo byte.
	if !audioguard.ExtensionDeAudio(archivo.Extension) {
		return res, fmt.Errorf(
			"soulseek: el par ofrece %q, que no es un formato de audio; por seguridad no se descarga",
			archivo.Extension)
	}
	if op.Espera <= 0 {
		op.Espera = esperaDescargaPorDefecto
	}
	if op.TamanoMaximo <= 0 {
		op.TamanoMaximo = tamanoMaximoPorDefecto
	}
	if op.ToleranciaDuracionS <= 0 {
		op.ToleranciaDuracionS = 3
	}
	limite := time.Now().Add(op.Espera)

	// 2) Conexión al servidor y escucha anunciada.
	if err := c.Conectar(20 * time.Second); err != nil {
		return res, err
	}
	if err := c.asegurarEscucha(); err != nil {
		return res, err
	}

	// 3) Dirección del par.
	direccion, err := c.pedirDireccion(archivo.Usuario, 15*time.Second)
	if err != nil {
		return res, err
	}

	// 4) Conexión P (control) hacia el par.
	par, err := c.conectarPar(direccion, 20*time.Second)
	if err != nil {
		return res, err
	}
	defer par.cerrar()

	// 5) Pedir el archivo a su cola de subida.
	if err := par.escribir(codificarQueueUpload(archivo.Ruta)); err != nil {
		return res, fmt.Errorf("soulseek: no se pudo pedir el archivo: %w", err)
	}

	// 6) El par responde con TransferRequest (o rechaza).
	req, err := esperarTransferRequest(par, archivo.Ruta, limite)
	if err != nil {
		return res, err
	}

	// 7) Registrar la espera de la conexión F ANTES de aceptar: el par puede
	//    abrirla apenas recibe la respuesta, y si no estamos esperando se
	//    descarta y la descarga queda colgada.
	canalF := c.registrarEsperaF(req.Token)
	defer c.olvidarEsperaF(req.Token)
	tamano := req.Tamano
	if tamano <= 0 || tamano > op.TamanoMaximo {
		// El par no declaró tamaño utilizable: se usa el del resultado de la
		// búsqueda y, si tampoco hay, se lee hasta el final con tope.
		tamano = archivo.Bytes
	}
	if err := par.escribir(codificarTransferResponse(req.Token, true, tamano)); err != nil {
		return res, fmt.Errorf("soulseek: no se pudo aceptar la transferencia: %w", err)
	}

	// 8) El par abre la conexión F hacia nosotros.
	connF, err := c.esperarConexionF(canalF, limite)
	if err != nil {
		return res, err
	}
	defer connF.Close()

	// 9) Decirle desde qué byte empezar (0: desde el principio). En la conexión
	//    F no va código de mensaje: son 8 bytes pelados.
	connF.SetWriteDeadline(time.Now().Add(30 * time.Second))
	if _, err := connF.Write(datosFileOffset(0)); err != nil {
		return res, fmt.Errorf("soulseek: no se pudo indicar el offset: %w", err)
	}

	// 10) Bajar a un temporal.
	temporal := destino + ".parcial"
	recibidos, err := copiarTransferencia(connF, temporal, tamano, op.TamanoMaximo, limite)
	if err != nil {
		os.Remove(temporal)
		return res, err
	}
	res.Bytes = recibidos

	// 11) Validar ANTES de dar el archivo por bueno.
	if err := revisarDescarga(temporal, archivo, op, &res); err != nil {
		os.Remove(temporal)
		return res, err
	}

	// 12) Recién ahora toma el nombre final.
	if err := os.Rename(temporal, destino); err != nil {
		os.Remove(temporal)
		return res, fmt.Errorf("soulseek: no se pudo mover el archivo a su lugar: %w", err)
	}
	res.Ruta = destino
	return res, nil
}

// DescargarAArchivo baja a [destinoDir] el archivo de una búsqueda previa.
//
// Es el puente con el orquestador de descargas: Soulseek no expone una URL
// (el audio lo sube un par por una conexión que ÉL abre hacia nosotros), así
// que en vez de GetStreamURL el orquestador le pide el archivo ya escrito y
// validado. Devuelve la ruta final del archivo.
//
// [duracionEsperadaS] es la duración del catálogo (0 si no se sabe): con ese
// dato se confirma que la grabación es la pedida y no un remix o un corte.
func (c *Client) DescargarAArchivo(trackID, quality, destinoDir string, duracionEsperadaS int) (string, error) {
	if strings.TrimSpace(destinoDir) == "" {
		return "", fmt.Errorf("soulseek: falta el directorio de descarga")
	}
	c.mu.RLock()
	archivo, hay := c.ultimos[trackID]
	c.mu.RUnlock()
	if !hay {
		return "", fmt.Errorf("soulseek: no hay un archivo con ese id (buscá primero)")
	}
	destino := filepath.Join(destinoDir, nombreArchivoDescarga(archivo))
	res, err := c.Descargar(archivo, destino, OpcionesDescarga{
		DuracionEsperadaS: duracionEsperadaS,
	})
	if err != nil {
		return "", err
	}
	_ = quality // la calidad la define el archivo elegido en la búsqueda
	return res.Ruta, nil
}

// nombreArchivoDescarga arma un nombre de archivo seguro para lo que ofrece el
// par. El nombre lo elige un DESCONOCIDO en la red, así que se le quita la ruta
// (un "..\..\algo" no puede escribir fuera de la carpeta), los bytes de control
// y los caracteres que Windows prohíbe. La extensión declarada se respeta: es
// la que el filtro de audioguard valida con los bytes reales.
func nombreArchivoDescarga(archivo ArchivoEncontrado) string {
	base := audioguard.NombreDeArchivoDelPar(archivo.Ruta)
	base = strings.Map(func(r rune) rune {
		switch r {
		case '<', '>', ':', '"', '/', '\\', '|', '?', '*':
			return '_'
		}
		if r < 0x20 {
			return -1
		}
		return r
	}, base)
	base = strings.TrimSpace(base)
	if base == "" {
		base = "pista"
	}
	ext := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(archivo.Extension, ".")))
	if ext != "" && !strings.HasSuffix(strings.ToLower(base), "."+ext) {
		base += "." + ext
	}
	return base
}

// esperarTransferRequest lee de la conexión P hasta que el par pide la
// transferencia, la rechaza, o dice en qué puesto de la cola quedó.
func esperarTransferRequest(par *conexionPar, ruta string, limite time.Time) (transferRequest, error) {
	for {
		restante := time.Until(limite)
		if restante <= 0 {
			return transferRequest{}, fmt.Errorf("soulseek: se agotó el tiempo esperando que el par inicie la subida")
		}
		par.conn.SetReadDeadline(time.Now().Add(min(restante, 60*time.Second)))
		codigo, cuerpo, err := leerMensaje(par.lector)
		if err != nil {
			return transferRequest{}, fmt.Errorf("soulseek: el par no respondió a la petición: %w", err)
		}
		switch codigo {
		case peerTransferRequest:
			req, err := decodificarTransferRequest(cuerpo)
			if err != nil {
				return transferRequest{}, fmt.Errorf("soulseek: petición de transferencia ilegible: %w", err)
			}
			return req, nil
		case peerUploadDenied:
			rutaNegada, razon, _ := decodificarUploadDenied(cuerpo)
			if razon == "" {
				razon = "sin motivo"
			}
			return transferRequest{}, fmt.Errorf("soulseek: el par rechazó %q (%s)", rutaNegada, razon)
		case peerUploadFailed:
			return transferRequest{}, fmt.Errorf("soulseek: el par cerró la subida de %q", ruta)
		case peerPlaceInQueueResponse:
			// Estamos en la cola: se sigue esperando dentro del presupuesto.
			_, puesto, _ := decodificarPlaceInQueue(cuerpo)
			if puesto > 100 {
				return transferRequest{}, fmt.Errorf(
					"soulseek: hay %d personas en la cola de ese par; probá otro resultado", puesto)
			}
		default:
			// Otros mensajes del par no interesan acá.
		}
	}
}

// copiarTransferencia baja los bytes a [temporal] con dos topes: el tamaño
// declarado y el máximo permitido. Devuelve cuántos bytes llegaron de verdad.
func copiarTransferencia(conn net.Conn, temporal string, tamanoDeclarado, tamanoMaximo int64, limite time.Time) (int64, error) {
	f, err := os.OpenFile(temporal, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return 0, fmt.Errorf("soulseek: no se pudo crear el archivo temporal: %w", err)
	}
	defer f.Close()

	esperado := tamanoDeclarado
	if esperado <= 0 || esperado > tamanoMaximo {
		esperado = tamanoMaximo
	}
	buf := make([]byte, 64*1024)
	var total int64
	for total < esperado {
		if time.Now().After(limite) {
			return total, fmt.Errorf("soulseek: se agotó el tiempo con %d de %d bytes", total, tamanoDeclarado)
		}
		conn.SetReadDeadline(time.Now().Add(silencioMaximo))
		n, err := conn.Read(buf)
		if n > 0 {
			if _, werr := f.Write(buf[:n]); werr != nil {
				return total, fmt.Errorf("soulseek: no se pudo escribir en disco: %w", werr)
			}
			total += int64(n)
		}
		if err != nil {
			if err == io.EOF {
				break // el par cerró: puede ser una transferencia completa
			}
			return total, fmt.Errorf("soulseek: la transferencia se cortó a los %d bytes: %w", total, err)
		}
	}
	if tamanoDeclarado > 0 && total != tamanoDeclarado {
		return total, fmt.Errorf(
			"soulseek: llegaron %d bytes de %d declarados (archivo incompleto)", total, tamanoDeclarado)
	}
	if total == 0 {
		return 0, fmt.Errorf("soulseek: el par no envió ningún dato")
	}
	return total, nil
}

// revisarDescarga aplica el filtro de seguridad y la verificación de identidad.
//
// Es el punto donde un binario disfrazado, un archivo truncado o un remix con
// el mismo nombre se caen: sin esto, "descargar de un desconocido" sería
// exactamente lo que no queremos que sea.
func revisarDescarga(temporal string, archivo ArchivoEncontrado, op OpcionesDescarga, res *ResultadoDescarga) error {
	v := audioguard.Revisar(temporal)
	if !v.OK {
		return fmt.Errorf("soulseek: se descartó el archivo de %q: %s", archivo.Usuario, v.Motivo)
	}
	res.Verificacion = fmt.Sprintf("formato verificado (%s, %d bytes)", v.Formato, v.Bytes)

	if op.DuracionEsperadaS <= 0 || v.Formato != "flac" {
		// Sin duración conocida, o en un formato del que no podemos leerla
		// barato, la única garantía es el formato. Se dice tal cual en vez de
		// fingir una verificación que no se hizo.
		res.Verificacion += "; identidad no verificada por duración"
		return nil
	}
	duracion, ok := audioguard.DuracionFLAC(temporal)
	if !ok {
		res.Verificacion += "; el FLAC no declara su duración, no se pudo verificar identidad"
		return nil
	}
	res.DuracionS = duracion
	diff := duracion - float64(op.DuracionEsperadaS)
	if diff < 0 {
		diff = -diff
	}
	if diff > float64(op.ToleranciaDuracionS) {
		return fmt.Errorf(
			"soulseek: el archivo de %q dura %.0fs y la canción pedida %ds: no es la misma grabación",
			archivo.Usuario, duracion, op.DuracionEsperadaS)
	}
	res.DuracionVerificada = true
	res.Verificacion = fmt.Sprintf(
		"verificado por formato y por duración (%.0fs vs %ds del catálogo)",
		duracion, op.DuracionEsperadaS)
	return nil
}

// conectarPar abre la conexión P (control) con un par y hace el handshake.
func (c *Client) conectarPar(d direccionPeer, timeout time.Duration) (*conexionPar, error) {
	conn, err := net.DialTimeout("tcp", net.JoinHostPort(d.IP, strconv.Itoa(int(d.Puerto))), timeout)
	if err != nil {
		return nil, fmt.Errorf("soulseek: no se pudo conectar al par %q: %w", d.Usuario, err)
	}
	conn.SetDeadline(time.Now().Add(timeout))
	// PeerInit lleva el código en UN byte (ver transfer_protocol.go).
	if _, err := conn.Write(codificarPeerInit(c.usuarioActual())); err != nil {
		conn.Close()
		return nil, fmt.Errorf("soulseek: no se pudo iniciar la conexión con el par: %w", err)
	}
	lector := bufio.NewReader(conn)
	codigo, cuerpo, err := leerMensajePeerInit(lector)
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("soulseek: el par %q no completó la conexión: %w", d.Usuario, err)
	}
	if codigo == initPierceFirewall {
		conn.Close()
		return nil, fmt.Errorf(
			"soulseek: el par %q no acepta conexiones directas (habría que usar la vía indirecta, todavía no implementada); probá otro resultado",
			d.Usuario)
	}
	if _, _, err := decodificarPeerInit(cuerpo); err != nil {
		conn.Close()
		return nil, fmt.Errorf("soulseek: respuesta de inicio ilegible del par %q: %w", d.Usuario, err)
	}
	conn.SetDeadline(time.Time{})
	return &conexionPar{conn: conn, lector: lector}, nil
}

// ── Despacho del servidor y escucha de la conexión F ─────────────────────

func (c *Client) usuarioActual() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.usuario
}

// asegurarEscucha levanta el puerto donde el par abre la conexión F y lo
// anuncia al servidor. Sin esto la descarga no puede empezar nunca.
func (c *Client) asegurarEscucha() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.asegurarEscuchaBloqueado()
}

func (c *Client) asegurarEscuchaBloqueado() error {
	if c.conn == nil {
		return fmt.Errorf("soulseek: no hay conexión con el servidor")
	}
	if c.listener == nil {
		puerto := int(c.puertoAnunciado)
		if puerto == 0 {
			puerto = puertoPorDefecto
		}
		ln, err := net.Listen("tcp", fmt.Sprintf(":%d", puerto))
		if err != nil {
			// Puerto ocupado: se le pide uno libre al sistema. Sirve igual,
			// porque el puerto que queda es el que se anuncia.
			ln, err = net.Listen("tcp", ":0")
			if err != nil {
				return fmt.Errorf("soulseek: no se pudo abrir el puerto de descarga: %w", err)
			}
		}
		c.listener = ln
		go c.aceptarConexionesF(ln)
	}
	direccion, ok := c.listener.Addr().(*net.TCPAddr)
	if !ok {
		return fmt.Errorf("soulseek: el puerto de descarga no tiene dirección utilizable")
	}
	if err := c.escribirServidor(codificarSetWaitPort(uint16(direccion.Port))); err != nil {
		return fmt.Errorf("soulseek: no se pudo anunciar el puerto de descarga: %w", err)
	}
	return nil
}

// aceptarConexionesF recibe las conexiones F que abren los pares y las entrega
// al que está esperando ese token.
func (c *Client) aceptarConexionesF(ln net.Listener) {
	for {
		conn, err := ln.Accept()
		if err != nil {
			return // el listener se cerró: se termina el ciclo
		}
		go c.recibirConexionF(conn)
	}
}

func (c *Client) recibirConexionF(conn net.Conn) {
	// El primer mensaje de la conexión F es FileTransferInit: uint32 pelado con
	// el token, SIN código (ver transfer_protocol.go).
	var cab [4]byte
	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	if _, err := leerLleno(conn, cab[:]); err != nil {
		conn.Close()
		return
	}
	token := binary.LittleEndian.Uint32(cab[:])
	c.muRed.Lock()
	canal := c.esperandoF[token]
	c.muRed.Unlock()
	if canal == nil {
		// Nadie espera ese token: no es una transferencia nuestra.
		conn.Close()
		return
	}
	select {
	case canal <- conn:
	default:
		conn.Close()
	}
}

func (c *Client) registrarEsperaF(token uint32) chan net.Conn {
	canal := make(chan net.Conn, 1)
	c.muRed.Lock()
	c.esperandoF[token] = canal
	c.muRed.Unlock()
	return canal
}

func (c *Client) olvidarEsperaF(token uint32) {
	c.muRed.Lock()
	delete(c.esperandoF, token)
	c.muRed.Unlock()
}

func (c *Client) esperarConexionF(canal chan net.Conn, limite time.Time) (net.Conn, error) {
	restante := time.Until(limite)
	if restante <= 0 {
		return nil, fmt.Errorf("soulseek: se agotó el tiempo esperando la conexión de datos")
	}
	c.muRed.Lock()
	muerto := c.muerto
	c.muRed.Unlock()
	select {
	case conn := <-canal:
		return conn, nil
	case <-muerto:
		return nil, fmt.Errorf("soulseek: se perdió la conexión con el servidor durante la descarga")
	case <-time.After(min(restante, 90*time.Second)):
		// Puede ser NAT: el par intenta conectarse y no llega. Se explica en
		// vez de dejar un timeout mudo.
		return nil, fmt.Errorf(
			"soulseek: el par no pudo abrir la conexión de datos (¿puerto cerrado por NAT/firewall?); probá otro resultado")
	}
}

func min(a, b time.Duration) time.Duration {
	if a < b {
		return a
	}
	return b
}
