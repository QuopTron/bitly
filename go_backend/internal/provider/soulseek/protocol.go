// protocol.go — framing binario del protocolo Soulseek (servidor + peer).
//
// Todo acá sale del documento oficial del protocolo
// (https://nicotine-plus.org/doc/SLSKPROTOCOL.html). Los enteros son
// LITTLE-ENDIAN y los strings van prefijados por su longitud en uint32.
//
// El formato se valida con un test que reproduce EXACTAMENTE el ejemplo en
// bytes del spec (ver protocol_test.go): si el encoder se desvía un solo byte,
// el test falla. Sin eso, este archivo sería una suposición.
//
// Ojo con el parseo: acá entra data de pares de la red, o sea data hostil.
// Por eso TODA lectura está chequeada contra los límites del buffer y
// `decodificarFileSearchReply` nunca confía en los contadores que lee
// (un par puede mentir con "tengo 4 mil millones de resultados").
package soulseek

import (
	"bytes"
	"compress/zlib"
	"crypto/md5"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"io"
	"strings"
)

// Códigos de mensaje. Los del servidor son uint32; el 9 llega del servidor
// pero es un mensaje de peer reenviado (FileSearchResponse).
const (
	srvLogin           uint32 = 1
	srvGetPeerAddress  uint32 = 3
	srvSetWaitPort     uint32 = 2
	srvConnectToPeer   uint32 = 18
	srvFileSearch      uint32 = 26
	srvFileSearchReply uint32 = 9
)

// Versión que declaramos al servidor. 177 es el rango reservado a clientes
// experimentales/desarrollo: no impersona a ningún cliente con número propio
// (157 SoulseekQt, 160 Nicotine+, 170 Soulseek.NET…), que es justo lo que el
// spec pide para no hacerse pasar por otro.
const (
	versionMayor uint32 = 177
	versionMenor uint32 = 1
)

// Tope de un mensaje entrante. Un par hostil puede mandar un uint32 de
// longitud gigante; sin este corte reservaríamos esa memoria antes de validar.
const maxMensaje = 8 << 20

// Tope de resultados por respuesta de un par, para no reservar por un
// contador mentiroso.
const maxResultadosPorRespuesta = 4096

var (
	errMensajeCorto  = errors.New("soulseek: mensaje truncado")
	errMensajeGrande = errors.New("soulseek: mensaje más grande que el tope")
)

// ── Escritura ────────────────────────────────────────────────────────────

type escritor struct{ bytes.Buffer }

func (e *escritor) u8(v byte) { _ = e.WriteByte(v) }
func (e *escritor) u32(v uint32) {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], v)
	e.Write(b[:])
}
func (e *escritor) u64(v uint64) {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], v)
	e.Write(b[:])
}
func (e *escritor) crudo(b []byte) { e.Write(b) }

// str escribe "uint32 longitud + bytes". El protocolo NO usa terminador nulo.
func (e *escritor) str(s string) {
	e.u32(uint32(len(s)))
	e.WriteString(s)
}

// mensajeServidor arma el sobre común: uint32 longitud total + uint32 código.
// La longitud incluye los 4 bytes del código, no los 4 de la longitud.
func mensajeServidor(codigo uint32, cuerpo []byte) []byte {
	e := &escritor{}
	e.u32(uint32(len(cuerpo)) + 4)
	e.u32(codigo)
	e.crudo(cuerpo)
	return e.Bytes()
}

// ── Lectura ──────────────────────────────────────────────────────────────

type lector struct {
	buf []byte
	pos int
	err error
}

func nuevoLector(b []byte) *lector { return &lector{buf: b} }

func (l *lector) u8() byte {
	if l.err != nil {
		return 0
	}
	if l.pos+1 > len(l.buf) {
		l.err = errMensajeCorto
		return 0
	}
	v := l.buf[l.pos]
	l.pos++
	return v
}

func (l *lector) u16() uint16 {
	if l.err != nil {
		return 0
	}
	if l.pos+2 > len(l.buf) {
		l.err = errMensajeCorto
		return 0
	}
	v := binary.LittleEndian.Uint16(l.buf[l.pos:])
	l.pos += 2
	return v
}

func (l *lector) u32() uint32 {
	if l.err != nil {
		return 0
	}
	if l.pos+4 > len(l.buf) {
		l.err = errMensajeCorto
		return 0
	}
	v := binary.LittleEndian.Uint32(l.buf[l.pos:])
	l.pos += 4
	return v
}

func (l *lector) u64() uint64 {
	if l.err != nil {
		return 0
	}
	if l.pos+8 > len(l.buf) {
		l.err = errMensajeCorto
		return 0
	}
	v := binary.LittleEndian.Uint64(l.buf[l.pos:])
	l.pos += 8
	return v
}

// str lee longitud + bytes, validando SIEMPRE contra el buffer. Nunca
// reserva memoria basándose en la longitud declarada sin comprobar antes
// que esos bytes existen de verdad.
func (l *lector) str() string {
	if l.err != nil {
		return ""
	}
	n := int(l.u32())
	if l.err != nil {
		return ""
	}
	if n < 0 || l.pos+n > len(l.buf) {
		l.err = errMensajeCorto
		return ""
	}
	s := string(l.buf[l.pos : l.pos+n])
	l.pos += n
	return s
}

func (l *lector) quedan() int { return len(l.buf) - l.pos }

// ── Mensajes que enviamos ────────────────────────────────────────────────

// codificarLogin arma el Server Code 1. El hash es el MD5 en hex de la
// concatenación usuario+contraseña (no lleva separador).
func codificarLogin(usuario, password string) []byte {
	e := &escritor{}
	e.str(usuario)
	e.str(password)
	e.u32(versionMayor)
	suma := md5.Sum([]byte(usuario + password))
	e.str(hex.EncodeToString(suma[:]))
	e.u32(versionMenor)
	return mensajeServidor(srvLogin, e.Bytes())
}

// codificarFileSearch arma el Server Code 26 (búsqueda en toda la red).
func codificarFileSearch(token uint32, consulta string) []byte {
	e := &escritor{}
	e.u32(token)
	e.str(consulta)
	return mensajeServidor(srvFileSearch, e.Bytes())
}

// ── Respuestas que decodificamos ─────────────────────────────────────────

// resultadoLogin es la respuesta al Server Code 1.
type resultadoLogin struct {
	OK      bool
	Saludo  string
	Hash    string // MD5 de la contraseña, según el spec
	Motivo  string // p. ej. INVALIDPASS, INVALIDUSERNAME
	Detalle string // solo cuando el motivo es INVALIDUSERNAME
}

// MotivoDeRechazo traduce el código de rechazo a algo mostrable.
func (r resultadoLogin) MensajeUsuario() string {
	switch r.Motivo {
	case "INVALIDUSERNAME":
		if r.Detalle != "" {
			return "Ese nombre de usuario no es válido: " + traducirDetalle(r.Detalle)
		}
		return "Ese nombre de usuario no es válido."
	case "INVALIDPASS":
		return "Ese nombre de usuario ya está tomado por otra cuenta con otra contraseña."
	case "EMPTYPASSWORD":
		return "La contraseña quedó vacía."
	case "INVALIDVERSION":
		return "El servidor pide una versión de cliente más nueva."
	case "SVRFULL":
		return "El servidor no acepta conexiones nuevas ahora mismo."
	case "SVRPRIVATE":
		return "El servidor no acepta registros nuevos ahora mismo."
	}
	if r.Motivo != "" {
		return "El servidor rechazó la conexión (" + r.Motivo + ")."
	}
	return "El servidor rechazó la conexión."
}

func traducirDetalle(d string) string {
	switch strings.TrimRight(d, ".") {
	case "Nick empty":
		return "está vacío"
	case "Nick too long":
		return "es demasiado largo (máximo 30 caracteres)"
	case "Invalid characters in nick":
		return "tiene caracteres no permitidos (solo ASCII imprimible)"
	case "No leading and trailing spaces allowed in nick":
		return "no puede empezar ni terminar con espacios"
	}
	return d
}

func decodificarLogin(cuerpo []byte) resultadoLogin {
	l := nuevoLector(cuerpo)
	r := resultadoLogin{}
	r.OK = l.u8() == 1
	if r.OK {
		r.Saludo = l.str()
		l.u32() // IP propia
		r.Hash = l.str()
		l.u8() // supporter
		return r
	}
	r.Motivo = l.str()
	if r.Motivo == "INVALIDUSERNAME" {
		r.Detalle = l.str()
	}
	return r
}

// ArchivoEncontrado es un archivo compartido por un par que coincide con la
// búsqueda. En Soulseek el "match" es textual sobre la ruta: el ISRC no
// existe en el protocolo, así que la identidad se confirma por DURACIÓN (el
// atributo 1), que es justo lo que hace el pipeline de matching del repo.
type ArchivoEncontrado struct {
	Usuario   string
	Ruta      string // carpeta\archivo.flac, como lo comparte el par
	Extension string
	Bytes     int64
	DuracionS int // atributo 1
	Bitrate   int // atributo 0
	SampleHz  int // atributo 4
	BitDepth  int // atributo 5
	SlotLibre bool
	Velocidad uint32
	Cola      uint32
}

// NombreArchivo devuelve solo el nombre del archivo, sin la carpeta.
func (a ArchivoEncontrado) NombreArchivo() string {
	if i := strings.LastIndexAny(a.Ruta, `\/`); i >= 0 {
		return a.Ruta[i+1:]
	}
	return a.Ruta
}

// Codigo identifica el archivo dentro del provider (usuario + ruta).
func (a ArchivoEncontrado) Codigo() string {
	return "slsk:" + a.Usuario + ":" + a.Ruta
}

// EsLossless marca los formatos sin pérdida que nos interesan.
func (a ArchivoEncontrado) EsLossless() bool {
	switch strings.ToLower(a.Extension) {
	case "flac", "ape", "wav", "alac", "m4a":
		return true
	}
	return false
}

// decodificarFileSearchReply parsea un FileSearchResponse (peer code 9).
// El cuerpo llega comprimido con zlib; si la descompresión falla se intenta
// parsear crudo, porque hay clientes que no comprimen.
func decodificarFileSearchReply(cuerpo []byte) (usuario string, token uint32, archivos []ArchivoEncontrado, err error) {
	if descomprimido, errZ := descomprimir(cuerpo); errZ == nil && len(descomprimido) > 0 {
		cuerpo = descomprimido
	}
	l := nuevoLector(cuerpo)
	usuario = l.str()
	token = l.u32()
	total := int(l.u32())
	if l.err != nil {
		return "", 0, nil, l.err
	}
	if total > maxResultadosPorRespuesta {
		total = maxResultadosPorRespuesta
	}
	for i := 0; i < total; i++ {
		if l.quedan() <= 0 {
			break
		}
		l.u8() // código fijo 1
		ruta := l.str()
		tam := l.u64()
		ext := l.str()
		nAtrib := int(l.u32())
		var duracion, bitrate, sampleHz, bitDepth int
		if nAtrib > 64 { // un par no puede declarar más atributos que esto
			nAtrib = 64
		}
		for j := 0; j < nAtrib; j++ {
			cod := l.u32()
			val := l.u32()
			switch cod {
			case 0:
				bitrate = int(val)
			case 1:
				duracion = int(val)
			case 4:
				sampleHz = int(val)
			case 5:
				bitDepth = int(val)
			}
		}
		slotLibre := l.u8() == 1
		velocidad := l.u32()
		cola := l.u32()
		l.u32() // desconocido, siempre 0
		if l.err != nil {
			break
		}
		archivos = append(archivos, ArchivoEncontrado{
			Usuario:   usuario,
			Ruta:      ruta,
			Extension: ext,
			Bytes:     int64(tam),
			DuracionS: duracion,
			Bitrate:   bitrate,
			SampleHz:  sampleHz,
			BitDepth:  bitDepth,
			SlotLibre: slotLibre,
			Velocidad: velocidad,
			Cola:      cola,
		})
	}
	return usuario, token, archivos, nil
}

func descomprimir(b []byte) ([]byte, error) {
	if len(b) < 2 {
		return nil, io.ErrUnexpectedEOF
	}
	zr, err := zlib.NewReader(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	defer zr.Close()
	// Tope de descompresión: un "zip bomb" chico puede expandirse a GB.
	salida, err := io.ReadAll(io.LimitReader(zr, maxMensaje))
	if err != nil {
		return nil, err
	}
	return salida, nil
}

// leerMensaje lee un mensaje del servidor: uint32 longitud + cuerpo.
func leerMensaje(r io.Reader) (codigo uint32, cuerpo []byte, err error) {
	var cabecera [4]byte
	if _, err := io.ReadFull(r, cabecera[:]); err != nil {
		return 0, nil, err
	}
	long := binary.LittleEndian.Uint32(cabecera[:])
	if long < 4 {
		return 0, nil, errMensajeCorto
	}
	if long > maxMensaje {
		return 0, nil, errMensajeGrande
	}
	cuerpo = make([]byte, long)
	if _, err := io.ReadFull(r, cuerpo); err != nil {
		return 0, nil, err
	}
	codigo = binary.LittleEndian.Uint32(cuerpo[:4])
	return codigo, cuerpo[4:], nil
}

// empaquetarMensajeServidor se expone para los tests.
func empaquetarMensajeServidor(codigo uint32, cuerpo []byte) []byte {
	return mensajeServidor(codigo, cuerpo)
}
