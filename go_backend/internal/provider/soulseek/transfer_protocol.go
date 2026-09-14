// transfer_protocol.go — los mensajes de la DESCARGA, con el formato verificado
// contra la documentación oficial del protocolo.
//
// TRES FRAMINGS DISTINTOS QUE NO SE PUEDEN MEZCLAR
//  1. Servidor y peer:      uint32 longitud + uint32 código + contenido.
//  2. Inicio de peer:       uint32 longitud + **uint8** código + contenido
//     (PeerInit / PierceFireWall). Un byte, no cuatro.
//  3. Conexión F:           SIN código. Sus mensajes son el contenido pelado
//     (FileTransferInit = uint32 token; FileOffset = uint64 offset). Por eso no
//     se puede reusar el lector de los otros dos.
//
// FLUJO DE DESCARGA (el documentado, y el que implementamos)
//
//	QueueUpload(43) → el par responde TransferRequest(40) → aceptamos con
//	TransferResponse(41) → el PAR abre la conexión F hacia nosotros → leemos el
//	token → mandamos FileOffset → llegan los bytes.
//
// Ojo con el punto 3 del flujo: es el par (el que sube) quien inicia la
// conexión de datos, así que el downloader tiene que estar ESCUCHANDO en un
// puerto y haberlo anunciado al servidor con SetWaitPort.
package soulseek

import (
	"encoding/binary"
	"fmt"
)

// Códigos de mensaje de peer usados en la descarga.
const (
	peerTransferRequest      uint32 = 40
	peerTransferResponse     uint32 = 41
	peerQueueUpload          uint32 = 43
	peerPlaceInQueueResponse uint32 = 44
	peerUploadFailed         uint32 = 46
	peerUploadDenied         uint32 = 50
	peerPlaceInQueueRequest  uint32 = 51
)

// Direcciones de transferencia.
const (
	direccionDescarga uint32 = 0 // pedimos bajar
	direccionSubida   uint32 = 1 // nos ofrecen subir
)

// Códigos de inicio de peer (framing de 1 byte).
const (
	initPierceFirewall uint8 = 0
	initPeerInit       uint8 = 1
)

// Tipos de conexión.
type tipoConexion string

const (
	conexionPeer    tipoConexion = "P"
	conexionArchivo tipoConexion = "F"
)

// ── Mensajes que enviamos ────────────────────────────────────────────────

// codificarPeerInit arma el inicio de una conexión P (framing de 1 byte).
// El token va en 0: hoy se ignora, lo usaba el obsoleto SendConnectToken.
func codificarPeerInit(usuario string) []byte {
	e := &escritor{}
	e.str(usuario)
	e.str(string(conexionPeer))
	e.u32(0)
	return mensajePeerInit(initPeerInit, e.Bytes())
}

// codificarPierceFirewall responde una conexión indirecta con el token que
// mandó el servidor.
func codificarPierceFirewall(token uint32) []byte {
	e := &escritor{}
	e.u32(token)
	return mensajePeerInit(initPierceFirewall, e.Bytes())
}

// mensajePeerInit arma el sobre de inicio: uint32 longitud + uint8 código.
func mensajePeerInit(codigo uint8, cuerpo []byte) []byte {
	e := &escritor{}
	e.u32(uint32(len(cuerpo)) + 1)
	e.u8(codigo)
	e.crudo(cuerpo)
	return e.Bytes()
}

// codificarQueueUpload pide al par que ponga el archivo en su cola de subida.
func codificarQueueUpload(ruta string) []byte {
	e := &escritor{}
	e.str(ruta)
	return mensajeServidor(peerQueueUpload, e.Bytes())
}

// codificarTransferResponse acepta (o rechaza) una TransferRequest. Como
// descargadores aceptamos e informamos el tamaño que esperamos.
func codificarTransferResponse(token uint32, permitido bool, tamano int64) []byte {
	e := &escritor{}
	e.u32(token)
	if permitido {
		e.u8(1)
		e.u64(uint64(tamano))
	} else {
		e.u8(0)
		e.str("Cancelled")
	}
	return mensajeServidor(peerTransferResponse, e.Bytes())
}

// codificarSetWaitPort anuncia al servidor el puerto donde escuchamos las
// conexiones F. Sin esto el par no sabe dónde conectarse y la descarga nunca
// arranca.
func codificarSetWaitPort(puerto uint16) []byte {
	e := &escritor{}
	e.u32(uint32(puerto))
	return mensajeServidor(srvSetWaitPort, e.Bytes())
}

// codificarGetPeerAddress pide la dirección de un par.
func codificarGetPeerAddress(usuario string) []byte {
	e := &escritor{}
	e.str(usuario)
	return mensajeServidor(srvGetPeerAddress, e.Bytes())
}

// ── Mensajes que recibimos ───────────────────────────────────────────────

// datosFileOffset serializa el offset de la conexión F: 8 bytes pelados, sin
// código (ver el encabezado del archivo).
func datosFileOffset(offset uint64) []byte {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], offset)
	return b[:]
}

// transferRequest es la petición de transferencia que manda el par.
type transferRequest struct {
	Direccion uint32
	Token     uint32
	Ruta      string
	Tamano    int64 // solo cuando la dirección es subida
}

func decodificarTransferRequest(cuerpo []byte) (transferRequest, error) {
	l := nuevoLector(cuerpo)
	r := transferRequest{
		Direccion: l.u32(),
		Token:     l.u32(),
		Ruta:      l.str(),
	}
	if r.Direccion == direccionSubida {
		r.Tamano = int64(l.u64())
	}
	if l.err != nil {
		return r, l.err
	}
	return r, nil
}

// transferResponse es la respuesta a una TransferRequest.
type transferResponse struct {
	Token     uint32
	Permitido bool
	Razon     string
}

func decodificarTransferResponse(cuerpo []byte) (transferResponse, error) {
	l := nuevoLector(cuerpo)
	r := transferResponse{Token: l.u32()}
	if l.err != nil {
		return r, l.err
	}
	r.Permitido = l.u8() == 1
	if !r.Permitido {
		r.Razon = l.str()
	}
	return r, nil
}

// uploadDenied explica por qué el par rechazó la subida.
func decodificarUploadDenied(cuerpo []byte) (ruta, razon string, err error) {
	l := nuevoLector(cuerpo)
	ruta = l.str()
	razon = l.str()
	return ruta, razon, l.err
}

// placeInQueue dice el puesto en la cola (1 = siguiente).
func decodificarPlaceInQueue(cuerpo []byte) (ruta string, puesto uint32, err error) {
	l := nuevoLector(cuerpo)
	ruta = l.str()
	puesto = l.u32()
	return ruta, puesto, l.err
}

// decodificarPeerInit lee la respuesta de inicio de una conexión P.
func decodificarPeerInit(cuerpo []byte) (usuario string, tipo string, err error) {
	l := nuevoLector(cuerpo)
	usuario = l.str()
	tipo = l.str()
	return usuario, tipo, l.err
}

// direccionPeer es la dirección de un par tal como la devuelve el servidor.
type direccionPeer struct {
	Usuario        string
	IP             string
	Puerto         uint16
	Obfuscacion    uint32
	PuertoObfuscar uint16
}

func decodificarGetPeerAddress(cuerpo []byte) (direccionPeer, error) {
	l := nuevoLector(cuerpo)
	d := direccionPeer{
		Usuario: l.str(),
		IP:      ipDesdeUint32(l.u32()),
		Puerto:  uint16(l.u32()),
	}
	d.Obfuscacion = l.u32()
	// El puerto ofuscado es uint16 en el protocolo (2 bytes), no uint32:
	// leer 4 rompería el parseo por quedar corto el mensaje.
	d.PuertoObfuscar = l.u16()
	if l.err != nil {
		return d, l.err
	}
	if d.IP == "" || d.Puerto == 0 {
		return d, fmt.Errorf("el servidor no dio una dirección usable para %q", d.Usuario)
	}
	return d, nil
}

// ipDesdeUint32 convierte la IP del protocolo a texto.
//
// El protocolo escribe los 4 bytes de la IP tal cual, y nosotros los leemos
// como un entero little-endian (igual que todos los demás enteros). O sea que
// los bytes quedaron invertidos: 127.0.0.1 llega como 0x0100007F. Se deshace
// esa inversión en vez de reinterpretar el valor, que daría una IP distinta
// (y conectaríamos a la máquina equivocada).
func ipDesdeUint32(v uint32) string {
	if v == 0 {
		return ""
	}
	return fmt.Sprintf("%d.%d.%d.%d", v&0xFF, (v>>8)&0xFF, (v>>16)&0xFF, (v>>24)&0xFF)
}

// leerMensajePeerInit lee un mensaje con el framing de inicio: uint32 longitud
// + uint8 código.
func leerMensajePeerInit(r interface{ Read([]byte) (int, error) }) (uint8, []byte, error) {
	var cab [4]byte
	if _, err := leerLleno(r, cab[:]); err != nil {
		return 0, nil, err
	}
	long := binary.LittleEndian.Uint32(cab[:])
	if long < 1 {
		return 0, nil, errMensajeCorto
	}
	if long > maxMensaje {
		return 0, nil, errMensajeGrande
	}
	buf := make([]byte, long)
	if _, err := leerLleno(r, buf); err != nil {
		return 0, nil, err
	}
	return buf[0], buf[1:], nil
}

// leerLleno es io.ReadFull local, para aceptar cualquier lector sin arrastrar
// el import de io a este archivo.
func leerLleno(r interface{ Read([]byte) (int, error) }, buf []byte) (int, error) {
	total := 0
	for total < len(buf) {
		n, err := r.Read(buf[total:])
		total += n
		if err != nil {
			return total, err
		}
	}
	return total, nil
}
