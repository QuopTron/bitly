// transfer_protocol_test.go — el framing de la descarga.
//
// Los tres riesgos reales que se cubren acá:
//  1. Usar uint32 para el código de PeerInit cuando son 1 byte (el par
//     interpretaría basura y cerraría la conexión).
//  2. Ponerle código a los mensajes de la conexión F (la transferencia nunca
//     arrancaría).
//  3. Invertir la IP del servidor y conectar a la máquina equivocada.
package soulseek

import (
	"bytes"
	"encoding/binary"
	"testing"
)

func TestPeerInitUsaCodigoDeUnByte(t *testing.T) {
	msg := codificarPeerInit("pepe")

	// La longitud declarada tiene que cubrir: 1 byte de código + usuario +
	// tipo + token.
	usuario := len("pepe")
	tipo := len("P")
	esperado := 4 + usuario + 4 + tipo + 4 + 1 // +4 del token, +1 del código
	if long := binary.LittleEndian.Uint32(msg[:4]); int(long) != esperado {
		t.Fatalf("longitud %d, se esperaba %d", long, esperado)
	}
	// El código va en UN byte en el offset 4.
	if msg[4] != initPeerInit {
		t.Fatalf("código %d, se esperaba %d", msg[4], initPeerInit)
	}
	// Y el contenido arranca inmediatamente después (offset 5): si el código
	// fuera de 4 bytes, el usuario estaría en el offset 8 y no habría nada en
	// el 5.
	if binary.LittleEndian.Uint32(msg[5:9]) != uint32(usuario) {
		t.Fatalf("el usuario no empieza en el offset 5: % x", msg[5:9])
	}
	// Relectura con el framing correcto.
	codigo, cuerpo, err := leerMensajePeerInit(bytes.NewReader(msg))
	if err != nil {
		t.Fatalf("no se pudo releer: %v", err)
	}
	if codigo != initPeerInit {
		t.Fatalf("código reeleído %d", codigo)
	}
	u, tipoLeido, err := decodificarPeerInit(cuerpo)
	if err != nil || u != "pepe" || tipoLeido != "P" {
		t.Fatalf("contenido mal: %q %q %v", u, tipoLeido, err)
	}
}

func TestPierceFirewallLlevaElToken(t *testing.T) {
	msg := codificarPierceFirewall(0xDEADBEEF)
	if msg[4] != initPierceFirewall {
		t.Fatalf("código %d, se esperaba %d", msg[4], initPierceFirewall)
	}
	codigo, cuerpo, err := leerMensajePeerInit(bytes.NewReader(msg))
	if err != nil || codigo != initPierceFirewall {
		t.Fatalf("relectura: código %d err %v", codigo, err)
	}
	if got := binary.LittleEndian.Uint32(cuerpo); got != 0xDEADBEEF {
		t.Fatalf("token %x", got)
	}
}

// La conexión F no lleva código: 8 bytes pelados y nada más.
func TestFileOffsetNoLlevaCodigo(t *testing.T) {
	datos := datosFileOffset(0)
	if len(datos) != 8 {
		t.Fatalf("FileOffset debe medir 8 bytes, mide %d", len(datos))
	}
	if binary.LittleEndian.Uint64(datos) != 0 {
		t.Fatal("el offset inicial debe ser 0")
	}
	// Con un offset de reanudación.
	if got := binary.LittleEndian.Uint64(datosFileOffset(123456)); got != 123456 {
		t.Fatalf("offset %d", got)
	}
	// Si se le agregara un código de mensaje, mediría 12.
	if len(datosFileOffset(1)) == 12 {
		t.Fatal("FileOffset no puede llevar código de mensaje")
	}
}

func TestQueueUploadEsUnMensajeDePeer(t *testing.T) {
	ruta := `Música\Daft Punk\One More Time.flac`
	msg := codificarQueueUpload(ruta)
	codigo, cuerpo, err := leerMensaje(bytes.NewReader(msg))
	if err != nil {
		t.Fatalf("no se pudo releer: %v", err)
	}
	if codigo != peerQueueUpload {
		t.Fatalf("código %d, se esperaba %d", codigo, peerQueueUpload)
	}
	l := nuevoLector(cuerpo)
	if got := l.str(); got != ruta {
		t.Fatalf("ruta %q", got)
	}
}

func TestTransferRequestYSuRespuesta(t *testing.T) {
	// Lo que manda el par cuando está listo para subirnos el archivo.
	e := &escritor{}
	e.u32(direccionSubida)
	e.u32(4242)
	e.str(`x\pista.flac`)
	e.u64(41_234_567)
	req, err := decodificarTransferRequest(e.Bytes())
	if err != nil {
		t.Fatalf("no se pudo decodificar: %v", err)
	}
	if req.Direccion != direccionSubida || req.Token != 4242 || req.Tamano != 41_234_567 {
		t.Fatalf("petición mal leída: %+v", req)
	}

	// Nuestra respuesta aceptando: token + bool + tamaño.
	msg := codificarTransferResponse(4242, true, 41_234_567)
	codigo, cuerpo, err := leerMensaje(bytes.NewReader(msg))
	if err != nil || codigo != peerTransferResponse {
		t.Fatalf("respuesta mal formada: código %d err %v", codigo, err)
	}
	resp, err := decodificarTransferResponse(cuerpo)
	if err != nil || !resp.Permitido || resp.Token != 4242 {
		t.Fatalf("respuesta mal leída: %+v %v", resp, err)
	}

	// Respuesta rechazada: token + bool + razón (sin tamaño).
	msg = codificarTransferResponse(7, false, 0)
	_, cuerpo, _ = leerMensaje(bytes.NewReader(msg))
	resp, err = decodificarTransferResponse(cuerpo)
	if err != nil || resp.Permitido || resp.Razon == "" {
		t.Fatalf("rechazo mal leído: %+v %v", resp, err)
	}

	// Una petición de DESCARGA (direction 0, la usan slskd/Seeker) no trae
	// tamaño: leerlo como si lo trajera rompería el parseo.
	e2 := &escritor{}
	e2.u32(direccionDescarga)
	e2.u32(9)
	e2.str("pista.flac")
	req2, err := decodificarTransferRequest(e2.Bytes())
	if err != nil || req2.Tamano != 0 || req2.Token != 9 {
		t.Fatalf("petición de descarga mal leída: %+v %v", req2, err)
	}
}

func TestUploadDeniedYCola(t *testing.T) {
	e := &escritor{}
	e.str("pista.flac")
	e.str("File not shared.")
	ruta, razon, err := decodificarUploadDenied(e.Bytes())
	if err != nil || ruta != "pista.flac" || razon != "File not shared." {
		t.Fatalf("UploadDenied mal leído: %q %q %v", ruta, razon, err)
	}

	c := &escritor{}
	c.str("pista.flac")
	c.u32(3)
	ruta, puesto, err := decodificarPlaceInQueue(c.Bytes())
	if err != nil || ruta != "pista.flac" || puesto != 3 {
		t.Fatalf("PlaceInQueue mal leído: %q %d %v", ruta, puesto, err)
	}
}

func TestGetPeerAddressYSuPuertoOfuscadoCorto(t *testing.T) {
	// Lo que responde el servidor: usuario, ip, puerto (u32), obfuscación (u32),
	// puerto ofuscado (u16 — leerlo como u32 haría fallar el parseo).
	e := &escritor{}
	e.str("par")
	e.u32(0x0100007F) // bytes 7F 00 00 01 = 127.0.0.1
	e.u32(2242)
	e.u32(0)
	e.u8(0xA0) // 4000 = 0x0FA0, little-endian
	e.u8(0x0F)
	d, err := decodificarGetPeerAddress(e.Bytes())
	if err != nil {
		t.Fatalf("no se pudo decodificar: %v", err)
	}
	if d.IP != "127.0.0.1" {
		t.Fatalf("IP %q, se esperaba 127.0.0.1 (invertir los bytes, no reinterpretar)", d.IP)
	}
	if d.Puerto != 2242 || d.PuertoObfuscar != 4000 {
		t.Fatalf("puertos mal: %d / %d", d.Puerto, d.PuertoObfuscar)
	}
}

// Una IP distinta para asegurar que la conversión no es identidad ni una
// coincidencia de un solo caso: 181.188.160.211 llega como bytes B5 A0 BC B3.
func TestConversionDeIPNoEsIdentidad(t *testing.T) {
	v := binary.LittleEndian.Uint32([]byte{181, 188, 160, 211})
	if got := ipDesdeUint32(v); got != "181.188.160.211" {
		t.Fatalf("IP %q", got)
	}
	if ipDesdeUint32(0) != "" {
		t.Fatal("una IP 0 no es una dirección usable")
	}
	// Sin dirección usable, el parseo debe fallar en vez de devolver algo.
	e := &escritor{}
	e.str("par")
	e.u32(0)
	e.u32(0)
	e.u32(0)
	e.u8(0)
	e.u8(0)
	if _, err := decodificarGetPeerAddress(e.Bytes()); err == nil {
		t.Fatal("una dirección vacía debe dar error")
	}
}

func TestSetWaitPortYGetPeerAddressSeCodifican(t *testing.T) {
	msg := codificarSetWaitPort(2234)
	codigo, cuerpo, err := leerMensaje(bytes.NewReader(msg))
	if err != nil || codigo != srvSetWaitPort {
		t.Fatalf("SetWaitPort: código %d err %v", codigo, err)
	}
	if got := binary.LittleEndian.Uint32(cuerpo); got != 2234 {
		t.Fatalf("puerto %d", got)
	}

	msg = codificarGetPeerAddress("par")
	_, cuerpo, err = leerMensaje(bytes.NewReader(msg))
	if err != nil {
		t.Fatalf("GetPeerAddress: %v", err)
	}
	if got := nuevoLector(cuerpo).str(); got != "par" {
		t.Fatalf("usuario %q", got)
	}
}
