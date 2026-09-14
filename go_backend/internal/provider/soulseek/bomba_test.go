// bomba_test.go — la bomba de lectura probada de punta a punta contra un
// servidor FALSO (un net.Listener local), no contra la red real.
//
// Por qué importa: la búsqueda dejó de leer el socket en línea y ahora un hilo
// despacha las respuestas. Si el despacho se equivoca (token, framing, canal),
// el síntoma en producción es "Soulseek no encuentra nada" — indistinguible de
// "esa canción no está en la red". Este test separa las dos cosas.
package soulseek

import (
	"bufio"
	"encoding/binary"
	"net"
	"testing"
	"time"
)

// servidorFalso levanta un servidor que acepta un login y responde a cada
// FileSearch con UN archivo, como haría un par de la red.
func servidorFalso(t *testing.T, archivos []ArchivoEncontrado) (direccion string, cerrar func()) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("no se pudo abrir el servidor falso: %v", err)
	}
	// OJO: no se puede esperar al login acá dentro. El cliente recién marca el
	// dial cuando se llama a Buscar(), que ocurre DESPUÉS de que esta función
	// devuelva la dirección: esperar el login antes sería un abrazo mortal en el
	// propio test.
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		lector := bufio.NewReader(conn)

		codigo, cuerpo, err := leerMensaje(lector)
		if err != nil || codigo != srvLogin {
			return
		}
		// Se valida que el login esté bien formado: si el encoder cambia, el
		// servidor falso deja de reconocerlo y el test falla en vez de pasar
		// de casualidad.
		if campos := nuevoLector(cuerpo); campos.str() == "" || campos.str() == "" {
			t.Error("el servidor falso no pudo leer usuario y contraseña del login")
		}
		respuesta := &escritor{}
		respuesta.u8(1)
		respuesta.str("Bienvenido")
		respuesta.u32(0x0100007F)
		respuesta.str("hash")
		respuesta.u8(0)
		if _, err := conn.Write(mensajeServidor(srvLogin, respuesta.Bytes())); err != nil {
			return
		}

		for {
			codigo, cuerpo, err := leerMensaje(lector)
			if err != nil {
				return
			}
			switch codigo {
			case srvFileSearch:
				// El token sale del pedido: así se prueba que la respuesta se
				// despacha al que la pidió.
				token := nuevoLector(cuerpo).u32()
				_, err := conn.Write(mensajeServidor(
					srvFileSearchReply, armarRespuesta("par1", token, archivos)))
				if err != nil {
					return
				}
			case srvSetWaitPort:
				// El puerto de descarga se ignora en este test.
			}
		}
	}()
	return ln.Addr().String(), func() { _ = ln.Close() }
}

func TestBusquedaContraServidorFalso(t *testing.T) {
	archivos := []ArchivoEncontrado{
		{Usuario: "par1", Ruta: `Music\Daft Punk\Discovery\01 - One More Time.flac`,
			Extension: "flac", Bytes: 41_000_000, DuracionS: 320, BitDepth: 16, SlotLibre: true},
		{Usuario: "par1", Ruta: `Music\Daft Punk\Discovery\02 - Aerodynamic.mp3`,
			Extension: "mp3", Bytes: 9_000_000, DuracionS: 212, Bitrate: 320},
	}
	direccion, cerrar := servidorFalso(t, archivos)
	defer cerrar()

	c := NewClient("tester", "clave-larga-aleatoria")
	c.servidor = direccion

	encontrados, err := c.Buscar("Daft Punk One More Time", 2*time.Second)
	if err != nil {
		t.Fatalf("la búsqueda falló: %v", err)
	}
	if len(encontrados) != 2 {
		t.Fatalf("se esperaban 2 archivos, llegaron %d", len(encontrados))
	}
	if encontrados[0].Extension != "flac" || encontrados[0].DuracionS != 320 {
		t.Fatalf("primer resultado mal: %+v", encontrados[0])
	}

	// Y la lista del provider tiene que salir con artista y título DERIVADOS de
	// la ruta: es lo que hace que el ranking del repo lo acepte.
	pistas, err := c.SearchTracks("Daft Punk One More Time", 10)
	if err != nil {
		t.Fatalf("SearchTracks falló: %v", err)
	}
	if len(pistas) != 2 {
		t.Fatalf("se esperaban 2 pistas, llegaron %d", len(pistas))
	}
	// El orden de SearchTracks prioriza lossless, así que el FLAC va primero.
	if pistas[0].Artist != "Daft Punk" || pistas[0].Title != "One More Time" {
		t.Fatalf("artista/título mal derivados: %q / %q", pistas[0].Artist, pistas[0].Title)
	}
	if pistas[0].Duration != 320*1000 {
		t.Fatalf("la duración debe ir en milisegundos, va en %d", pistas[0].Duration)
	}
	// El id permite volver a describir el resultado concreto.
	track, err := c.GetTrack(pistas[0].ID)
	if err != nil || track.Title != "One More Time" {
		t.Fatalf("GetTrack no devolvió el archivo buscado: %+v %v", track, err)
	}
}

// La bomba es un solo lector: dos búsquedas seguidas tienen que funcionar y no
// pisarse los tokens.
func TestDosBusquedasSeguidas(t *testing.T) {
	direccion, cerrar := servidorFalso(t, []ArchivoEncontrado{
		{Usuario: "par1", Ruta: `a\b\Tema.flac`, Extension: "flac", Bytes: 1000, DuracionS: 100},
	})
	defer cerrar()

	c := NewClient("tester", "clave-larga-aleatoria")
	c.servidor = direccion

	for i := 0; i < 2; i++ {
		encontrados, err := c.Buscar("tema", 1500*time.Millisecond)
		if err != nil {
			t.Fatalf("búsqueda %d falló: %v", i+1, err)
		}
		if len(encontrados) != 1 {
			t.Fatalf("búsqueda %d: se esperaba 1 archivo, llegaron %d", i+1, len(encontrados))
		}
	}
	// Cada búsqueda consume un token distinto.
	c.mu.Lock()
	token := c.token
	c.mu.Unlock()
	if token < 2 {
		t.Fatalf("se esperaban al menos 2 tokens usados, hay %d", token)
	}
}

// Si el servidor cierra la conexión, la espera en curso tiene que fallar rápido
// (no agotar su propio plazo) y la búsqueda SIGUIENTE tiene que reconectar en
// vez de quedar muerta para siempre.
//
// Lo segundo es lo que de verdad importa: un socket muerto que sigue guardado
// hace que TODAS las búsquedas posteriores devuelvan "se perdió la conexión",
// que desde afuera se ve igual que "esa canción no está en la red".
func TestCaidaDelServidorReconecta(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	// La PRIMERA conexión se corta apenas el cliente se loguea; a partir de la
	// segunda el servidor se comporta bien y responde la búsqueda.
	go func() {
		n := 0
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			n++
			cortar := n == 1
			go servirFalso(conn, cortar)
		}
	}()

	c := NewClient("tester", "clave-larga-aleatoria")
	c.servidor = ln.Addr().String()

	inicio := time.Now()
	if _, err := c.Buscar("tema", 10*time.Second); err != nil {
		t.Logf("la primera búsqueda falló, como puede pasar tras una caída: %v", err)
	}
	if transcurrido := time.Since(inicio); transcurrido > 3*time.Second {
		t.Fatalf("la caída no cortó la espera (%v): la señal de conexión perdida no está funcionando", transcurrido)
	}

	encontrados, err := c.Buscar("tema", 2*time.Second)
	if err != nil {
		t.Fatalf("no reconectó tras la caída: %v", err)
	}
	if len(encontrados) != 1 {
		t.Fatalf("tras reconectar se esperaba 1 archivo, llegaron %d", len(encontrados))
	}
}

// servirFalso atiende una conexión del servidor falso: valida el login,
// responde la bienvenida y —si [cortar] es true— cierra sin más, simulando la
// caída. Si no, responde cada búsqueda con un archivo.
func servirFalso(conn net.Conn, cortar bool) {
	defer conn.Close()
	lector := bufio.NewReader(conn)
	codigo, cuerpo, err := leerMensaje(lector)
	if err != nil || codigo != srvLogin {
		return
	}
	if campos := nuevoLector(cuerpo); campos.str() == "" {
		return
	}
	respuesta := &escritor{}
	respuesta.u8(1)
	respuesta.str("Bienvenido")
	respuesta.u32(0)
	respuesta.str("hash")
	respuesta.u8(0)
	if _, err := conn.Write(mensajeServidor(srvLogin, respuesta.Bytes())); err != nil {
		return
	}
	if cortar {
		return // el servidor cierra la conexión sin avisar
	}
	for {
		codigo, cuerpo, err := leerMensaje(lector)
		if err != nil {
			return
		}
		if codigo != srvFileSearch {
			continue
		}
		token := nuevoLector(cuerpo).u32()
		archivos := []ArchivoEncontrado{
			{Usuario: "par1", Ruta: `a\b\Tema.flac`, Extension: "flac", Bytes: 1000, DuracionS: 100},
		}
		if _, err := conn.Write(mensajeServidor(srvFileSearchReply, armarRespuesta("par1", token, archivos))); err != nil {
			return
		}
	}
}

// El offset de la conexión F no lleva código: si se le agregara, el par
// interpretaría el código como parte del número.
func TestOffsetSinCodigoEnLaPractica(t *testing.T) {
	datos := datosFileOffset(0)
	if len(datos) != 8 || binary.LittleEndian.Uint64(datos) != 0 {
		t.Fatalf("FileOffset debe ser un uint64 de 8 bytes en cero, es % x", datos)
	}
}
