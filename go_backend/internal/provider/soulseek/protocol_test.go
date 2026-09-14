// protocol_test.go — el framing del protocolo Soulseek se valida contra el
// ejemplo en bytes del DOCUMENTO OFICIAL, no contra lo que yo creo recordar.
//
// El spec publica el hex exacto del mensaje de login para
// usuario="username" / contraseña="password" / versión 177.1. Si el encoder
// se desvía un solo byte, TestLoginCoincideConElSpec del spec falla.
package soulseek

import (
	"bytes"
	"compress/zlib"
	"encoding/binary"
	"encoding/hex"
	"strings"
	"testing"
)

// Vector literal del spec (Server Code 1 → "Message as Hex Stream").
const loginHexDelSpec = "48000000" + "01000000" +
	"08000000" + "757365726e616d65" +
	"08000000" + "70617373776f7264" +
	"b1000000" +
	"20000000" + "6435316339613765393335333734366136303230663936303264343532393239" +
	"01000000"

func TestLoginCoincideConElSpec(t *testing.T) {
	got := codificarLogin("username", "password")
	want, err := hex.DecodeString(loginHexDelSpec)
	if err != nil {
		t.Fatalf("vector del spec ilegible: %v", err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("el login no coincide con el spec\n got: %x\nwant: %x", got, want)
	}
	// La longitud declarada tiene que cubrir el resto del mensaje.
	if long := binary.LittleEndian.Uint32(got[:4]); int(long) != len(got)-4 {
		t.Fatalf("longitud declarada %d, bytes reales %d", long, len(got)-4)
	}
}

func TestFileSearchCodificaTokenYConsulta(t *testing.T) {
	msg := codificarFileSearch(7, "Daft Punk")
	codigo, cuerpo, err := leerMensaje(bytes.NewReader(msg))
	if err != nil {
		t.Fatalf("no se pudo releer el mensaje: %v", err)
	}
	if codigo != srvFileSearch {
		t.Fatalf("código %d, se esperaba %d", codigo, srvFileSearch)
	}
	l := nuevoLector(cuerpo)
	if tok := l.u32(); tok != 7 {
		t.Fatalf("token %d, se esperaba 7", tok)
	}
	if q := l.str(); q != "Daft Punk" {
		t.Fatalf("consulta %q", q)
	}
}

// armarRespuesta construye un FileSearchResponse (peer code 9) tal como lo
// manda un par, para probar el parseo del lado que recibe.
func armarRespuesta(usuario string, token uint32, resultados []ArchivoEncontrado) []byte {
	e := &escritor{}
	e.str(usuario)
	e.u32(token)
	e.u32(uint32(len(resultados)))
	for _, r := range resultados {
		e.u8(1)
		e.str(r.Ruta)
		e.u64(uint64(r.Bytes))
		e.str(r.Extension)
		// Atributos del par: los que usa un cliente para FLAC son
		// duración, sample rate y bit depth (0=bitrate solo en lossy).
		e.u32(3)
		e.u32(0)
		e.u32(uint32(r.Bitrate))
		e.u32(1)
		e.u32(uint32(r.DuracionS))
		e.u32(5)
		e.u32(uint32(r.BitDepth))
		if r.SlotLibre {
			e.u8(1)
		} else {
			e.u8(0)
		}
		e.u32(r.Velocidad)
		e.u32(r.Cola)
		e.u32(0)
	}
	// El cuerpo viaja comprimido con zlib.
	var buf bytes.Buffer
	zw := zlib.NewWriter(&buf)
	_, _ = zw.Write(e.Bytes())
	_ = zw.Close()
	return buf.Bytes()
}

func TestParseoDeRespuestaComprimida(t *testing.T) {
	esperados := []ArchivoEncontrado{
		{Usuario: "par1", Ruta: `Música\Daft Punk\One More Time.flac`, Extension: "flac",
			Bytes: 41234567, DuracionS: 320, BitDepth: 16, SampleHz: 44100, SlotLibre: true, Velocidad: 900, Cola: 0},
		{Usuario: "par1", Ruta: `Música\Daft Punk\One More Time.mp3`, Extension: "mp3",
			Bytes: 6000000, DuracionS: 320, Bitrate: 320, SlotLibre: false, Velocidad: 900, Cola: 12},
	}
	cuerpo := armarRespuesta("par1", 42, esperados)

	usuario, token, archivos, err := decodificarFileSearchReply(cuerpo)
	if err != nil {
		t.Fatalf("error de parseo: %v", err)
	}
	if usuario != "par1" || token != 42 {
		t.Fatalf("usuario/token mal: %q %d", usuario, token)
	}
	if len(archivos) != 2 {
		t.Fatalf("se esperaban 2 archivos, llegaron %d", len(archivos))
	}
	flac := archivos[0]
	if flac.Ruta != esperados[0].Ruta || flac.Extension != "flac" || flac.DuracionS != 320 {
		t.Fatalf("flac mal parseado: %+v", flac)
	}
	if flac.Bytes != 41234567 || flac.BitDepth != 16 || !flac.SlotLibre {
		t.Fatalf("atributos del flac mal parseados: %+v", flac)
	}
	if !flac.EsLossless() || archivos[1].EsLossless() {
		t.Fatal("EsLossless mal clasificado")
	}
	if flac.NombreArchivo() != "One More Time.flac" {
		t.Fatalf("nombre de archivo mal derivado: %q", flac.NombreArchivo())
	}
	if archivos[1].Cola != 12 || archivos[1].Bitrate != 320 {
		t.Fatalf("mp3 mal parseado: %+v", archivos[1])
	}
}

// El parseo corre sobre data de terceros: un contador mentiroso no puede
// hacer que la app reserve memoria ni que entre en pánico.
func TestRespuestaHostilNoRompe(t *testing.T) {
	e := &escritor{}
	e.str("parmalo")
	e.u32(1)
	e.u32(0xFFFFFFFF) // "tengo 4 mil millones de resultados"
	// …y ningún resultado detrás.
	usuario, _, archivos, err := decodificarFileSearchReply(e.Bytes())
	if err != nil {
		t.Fatalf("no debería fallar, solo cortar: %v", err)
	}
	if len(archivos) != 0 {
		t.Fatalf("se inventaron %d archivos", len(archivos))
	}
	if usuario != "parmalo" {
		t.Fatalf("usuario %q", usuario)
	}

	// String que declara un largo imposible: debe cortar, no reservar.
	hostil := &escritor{}
	hostil.u32(999999) // largo de string mayor que el buffer
	hostil.str("x")
	if _, _, _, err := decodificarFileSearchReply(hostil.Bytes()); err == nil {
		t.Fatal("un string con largo imposible debería dar error")
	}

	// Cuerpo vacío.
	if _, _, _, err := decodificarFileSearchReply(nil); err == nil {
		t.Fatal("cuerpo vacío debería dar error")
	}
}

func TestOrdenPreferenciaFlacDuracionYCaldad(t *testing.T) {
	flac16 := ArchivoEncontrado{Usuario: "a", Ruta: `x\A.flac`, Extension: "flac", DuracionS: 320, BitDepth: 16, SampleHz: 44100, Cola: 0, SlotLibre: true}
	flac24 := ArchivoEncontrado{Usuario: "b", Ruta: `y\A.flac`, Extension: "flac", DuracionS: 320, BitDepth: 24, SampleHz: 96000, Cola: 5, SlotLibre: false}
	mp3 := ArchivoEncontrado{Usuario: "c", Ruta: `z\A.mp3`, Extension: "mp3", DuracionS: 320, Bitrate: 320, SlotLibre: true}
	otraDuracion := ArchivoEncontrado{Usuario: "d", Ruta: `w\A (Live).flac`, Extension: "flac", DuracionS: 420, BitDepth: 24, SampleHz: 96000}

	orden := OrdenarCandidatos([]ArchivoEncontrado{mp3, otraDuracion, flac16, flac24}, 320, 3)
	if orden[0].Usuario != "b" {
		t.Fatalf("con duración exacta debe ganar el FLAC 24/96; ganó %q", orden[0].Usuario)
	}
	if orden[len(orden)-1].Usuario != "d" {
		t.Fatalf("el live de 420s debe quedar último; quedó %q", orden[len(orden)-1].Usuario)
	}

	// Con tolerancia estricta, el live (420 vs 320) no es un match válido.
	m := MejorCandidato([]ArchivoEncontrado{otraDuracion}, 320, 3)
	if m != nil {
		t.Fatalf("un live de 420s no puede pasar el match por duración: %+v", m)
	}
	// Sin dato de duración no se puede verificar identidad: se ordena por
	// calidad pero no se descarta nada.
	sinDuracion := OrdenarCandidatos([]ArchivoEncontrado{mp3, flac16}, 0, 0)
	if !sinDuracion[0].EsLossless() {
		t.Fatal("sin duración, el orden debe priorizar lossless sobre lossy")
	}
	if m := MejorCandidato([]ArchivoEncontrado{mp3, flac16}, 0, 0); m == nil || !m.EsLossless() {
		t.Fatal("sin duración, el mejor candidato debe ser el lossless")
	}
	if !CoincideDuracion(flac16, 320, 3) || CoincideDuracion(flac16, 320, 0) == false {
		t.Fatal("CoincideDuracion mal evaluado en el caso límite")
	}
	if CoincideDuracion(ArchivoEncontrado{DuracionS: 0}, 320, 3) {
		t.Fatal("un archivo sin duración no puede declararse coincidente")
	}
}

func TestPasswordAleatoriaYUsable(t *testing.T) {
	primera := GenerarPassword()
	if len(primera) != 24 {
		t.Fatalf("largo inesperado: %d", len(primera))
	}
	for _, r := range primera {
		if !strings.ContainsRune(alfabetoPassword, r) {
			t.Fatalf("carácter fuera del alfabeto seguro: %q", r)
		}
	}
	// No se repite (en 2^24 intentos aleatorios reales, dos iguales sería un
	// fallo de la fuente de entropía, no mala suerte).
	if segunda := GenerarPassword(); segunda == primera || segunda == "" {
		t.Fatal("GenerarPassword devolvió el mismo valor o vacío")
	}
}

func TestLoginDecodificaRechazoYExito(t *testing.T) {
	// Rechazo por contraseña incorrecta.
	r := decodificarLogin(armarLoginRechazo("INVALIDPASS", ""))
	if r.OK || !strings.Contains(r.MensajeUsuario(), "tomado") {
		t.Fatalf("rechazo mal decodificado: %+v → %q", r, r.MensajeUsuario())
	}
	// Rechazo por nombre inválido: trae detalle y se traduce.
	r = decodificarLogin(armarLoginRechazo("INVALIDUSERNAME", "Invalid characters in nick."))
	if r.OK || !strings.Contains(r.MensajeUsuario(), "caracteres no permitidos") {
		t.Fatalf("detalle de usuario inválido no traducido: %q", r.MensajeUsuario())
	}
	// Éxito: saludo + hash de la contraseña + supporter.
	e := &escritor{}
	e.u8(1)
	e.str("Welcome")
	e.u32(12345)
	e.str("5f4dcc3b5aa765d61d8327deb882cf99")
	e.u8(0)
	ok := decodificarLogin(e.Bytes())
	if !ok.OK || ok.Saludo != "Welcome" || ok.Hash == "" {
		t.Fatalf("login exitoso mal decodificado: %+v", ok)
	}
}

func armarLoginRechazo(motivo, detalle string) []byte {
	e := &escritor{}
	e.u8(0)
	e.str(motivo)
	if motivo == "INVALIDUSERNAME" {
		e.str(detalle)
	}
	return e.Bytes()
}

// Sin credenciales el cliente queda inerte: no intenta red ni en el registro
// ni al recibir ajustes vacíos.
func TestClienteSinCredencialesNoConecta(t *testing.T) {
	c := NewClient("", "")
	if c.Conectado() {
		t.Fatal("un cliente sin credenciales no debe estar conectado")
	}
	c.SetSettings(map[string]string{})
	if c.Conectado() {
		t.Fatal("ajustes vacíos no deben abrir conexión")
	}
	if _, hay := c.Credenciales(); hay {
		t.Fatal("no debería reportar contraseña configurada")
	}
	if _, err := c.Buscar("", 0); err == nil {
		t.Fatal("una búsqueda vacía debe fallar antes de tocar la red")
	}
	c.SetSettings(map[string]string{"usuario": "pepe"})
	usuario, hayPass := c.Credenciales()
	if usuario != "pepe" || hayPass {
		t.Fatalf("estado de credenciales inesperado: %q %v", usuario, hayPass)
	}
}
