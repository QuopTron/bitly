// guard.go — la garantía de que lo descargado es AUDIO y nunca un binario.
//
// POR QUÉ EXISTE
// Con las fuentes abiertas (Internet Archive, y sobre todo Soulseek, donde el
// archivo lo comparte un DESCONOCIDO en una red P2P) el contenido que entra al
// disco no es confiable. Este paquete es el único filtro que decide si ese
// archivo puede considerarse una canción.
//
// CÓMO ESTÁ PENSADO (lista blanca, no lista negra)
// El orden es: (1) si la cabecera es un contenedor de audio CONOCIDO → pasa;
// (2) si no, si es un ejecutable o un contenedor genérico (ZIP, GZIP, PDF,
// HTML…) → se rechaza nombrando el motivo; (3) cualquier otra cosa → se rechaza
// por desconocida. O sea: lo que no se reconoce como audio NO pasa. Una lista
// negra de malware siempre pierde; una lista blanca de audio no.
//
// POR QUÉ ESTO IMPORTA AUNQUE NO HAYA UN "EXEC"
// El archivo nunca se ejecuta solo, pero SÍ se le entrega a ffmpeg (para
// descifrar/convertir), que es un parser de formatos: alimentarlo con datos
// hostiles es la superficie de ataque real. Además, un .exe renombrado a .flac
// termina en la carpeta de música del usuario, donde otro programa (o él
// mismo) puede abrirlo por error. Nada de eso entra con este filtro.
//
// Se conecta con: provider/soulseek (transferencia P2P) y download
// (orquestador, que ya validaba con su propio chequeo de cabeceras).
package audioguard

import (
	"fmt"
	"io"
	"os"
	"strings"
)

// BytesMinimos: por debajo de esto no puede haber audio real (una pista corta
// en Opus ronda los KB). Un archivo de 0 bytes no es "audio vacío": es un fallo.
const BytesMinimos = 64

// veredicto es el resultado de revisar un archivo.
type veredicto struct {
	OK      bool
	Formato string // contenedor reconocido (flac, mp3, ogg, wav, mp4, webm…)
	Motivo  string // por qué se rechazó (vacío cuando OK)
	Bytes   int64
}

// Revisar decide si [ruta] es un archivo de audio legítimo.
//
// Devuelve el veredicto en vez de un error para que el mensaje pueda darse al
// usuario tal cual ("se rechazó: es un ejecutable de Windows"), que es más útil
// que un "falló la validación".
func Revisar(ruta string) veredicto {
	f, err := os.Open(ruta)
	if err != nil {
		return veredicto{Motivo: "no se pudo abrir el archivo: " + err.Error()}
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		return veredicto{Motivo: "no se pudo medir el archivo: " + err.Error()}
	}
	tam := info.Size()
	if info.IsDir() {
		return veredicto{Motivo: "es un directorio, no un archivo", Bytes: tam}
	}
	if tam < BytesMinimos {
		return veredicto{
			Motivo: fmt.Sprintf("el archivo es demasiado chico para ser audio (%d bytes)", tam),
			Bytes:  tam,
		}
	}

	// 16 bytes alcanzan para todas las firmas que se miran acá.
	buf := make([]byte, 16)
	n, err := io.ReadFull(f, buf)
	if err != nil && err != io.ErrUnexpectedEOF {
		return veredicto{Motivo: "no se pudo leer la cabecera: " + err.Error(), Bytes: tam}
	}
	buf = buf[:n]
	if n < 4 {
		return veredicto{Motivo: "la cabecera está truncada", Bytes: tam}
	}

	// 1) ¿Es un contenedor de audio conocido? Entonces pasa.
	if formato := formatoAudio(buf); formato != "" {
		return veredicto{OK: true, Formato: formato, Bytes: tam}
	}

	// 2) No es audio: se nombra el motivo cuando es algo reconocible. Esto no
	//    es lo que decide (ya se rechazó arriba), es lo que hace el rechazo
	//    entendible en el log y para el usuario.
	if motivo := firmaPeligrosa(buf); motivo != "" {
		return veredicto{Motivo: motivo, Bytes: tam}
	}

	// 3) Desconocido: se rechaza igual. Es el punto entero de la lista blanca.
	return veredicto{
		Motivo: fmt.Sprintf("la cabecera no corresponde a ningún formato de audio (%s)", hexCorto(buf)),
		Bytes:  tam,
	}
}

// EsAudio es la versión booleana, para llamadas donde solo importa sí/no.
func EsAudio(ruta string) bool { return Revisar(ruta).OK }

// EsAudioErr devuelve nil si el archivo es audio, o un error con el motivo.
func EsAudioErr(ruta string) error {
	v := Revisar(ruta)
	if v.OK {
		return nil
	}
	return fmt.Errorf("audioguard: %s: %s", ruta, v.Motivo)
}

// formatoAudio devuelve el nombre del contenedor si la cabecera es de audio
// conocido, o "" si no lo es.
//
// Todas las firmas están puestas por formato; el orden importa solo en un caso:
// "#!AMR" (AMR) empieza como un script ("#!"), así que se reconoce acá ANTES de
// que firmaPeligrosa vea el "#!".
func formatoAudio(b []byte) string {
	if len(b) < 4 {
		return ""
	}
	switch {
	case tiene(b, "fLaC"):
		return "flac"
	case tiene(b, "ID3"):
		return "mp3"
	case tiene(b, "OggS"):
		return "ogg" // Vorbis / Opus / FLAC-in-Ogg
	case tiene(b, "#!AMR"):
		return "amr"
	case tiene(b, "MAC "):
		return "ape"
	case tiene(b, "wvpk"):
		return "wavpack"
	case tiene(b, "MPCK"), tiene(b, "MP+"):
		return "musepack"
	case tiene(b, "DSD "):
		return "dsf"
	// AIFF: ["FORM":4][tamaño:4]["AIFF"|"AIFC":4] — el formato va en el offset 8.
	case tiene(b, "FORM") && len(b) >= 12 && string(b[8:12]) == "AIFF":
		return "aiff"
	case tiene(b, "FORM") && len(b) >= 12 && string(b[8:12]) == "AIFC":
		return "aiff"
	case tiene(b, "RIFF") && len(b) >= 12 && b[8] == 'W' && b[9] == 'A' && b[10] == 'V' && b[11] == 'E':
		return "wav"
	// MP4/M4A: [tamaño:4][ftyp:4][marca:4] — el ftyp no está en el offset 0.
	case len(b) >= 12 && b[4] == 'f' && b[5] == 't' && b[6] == 'y' && b[7] == 'p':
		return "mp4"
	// Matroska / WebM (el .opus de TIDAL).
	case len(b) >= 4 && b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3:
		return "webm"
	// MP3 sin etiqueta: sync word de trama (0xFF 0xE0..0xFF).
	case b[0] == 0xFF && (b[1]&0xE0) == 0xE0:
		return "mp3"
	}
	return ""
}

// firmaPeligrosa nombra ejecutables y contenedores genéricos. Se llama SOLO
// cuando la cabecera ya no es audio, así que su única función es explicar el
// rechazo (y dejar rastro claro de un intento de colar un binario).
func firmaPeligrosa(b []byte) string {
	switch {
	case tiene(b, "MZ"):
		return "rechazado: es un ejecutable de Windows (firma MZ/PE)"
	case len(b) >= 4 && b[0] == 0x7F && b[1] == 'E' && b[2] == 'L' && b[3] == 'F':
		return "rechazado: es un ejecutable de Linux (ELF)"
	case len(b) >= 4 && b[0] == 0xCF && b[1] == 0xFA && b[2] == 0xED && b[3] == 0xFE:
		return "rechazado: es un binario de macOS (Mach-O)"
	case len(b) >= 4 && b[0] == 0xFE && b[1] == 0xED && b[2] == 0xFA:
		return "rechazado: es un binario de macOS (Mach-O)"
	case len(b) >= 4 && b[0] == 0xCA && b[1] == 0xFE && b[2] == 0xBA && b[3] == 0xBE:
		return "rechazado: es un binario de macOS (Mach-O universal)"
	case tiene(b, "#!"):
		return "rechazado: es un script ejecutable (shebang #!)"
	case tiene(b, "PK\x03\x04"):
		return "rechazado: es un archivo comprimido (ZIP/JAR/APK)"
	case len(b) >= 2 && b[0] == 0x1F && b[1] == 0x8B:
		return "rechazado: es un archivo comprimido (GZIP)"
	case tiene(b, "Rar!"):
		return "rechazado: es un archivo comprimido (RAR)"
	case tiene(b, "7z\xBC\xAF"):
		return "rechazado: es un archivo comprimido (7z)"
	case tiene(b, "%PDF"):
		return "rechazado: es un PDF"
	case tiene(b, "<?php"), tiene(b, "<!DOCTYPE"), tiene(b, "<html"), tiene(b, "<HTML"):
		return "rechazado: es una página web, no un archivo de audio"
	case tiene(b, "SQLite"):
		return "rechazado: es una base de datos SQLite"
	}
	return ""
}

func tiene(b []byte, firma string) bool {
	return len(b) >= len(firma) && string(b[:len(firma)]) == firma
}

func hexCorto(b []byte) string {
	var sb strings.Builder
	for i, c := range b {
		if i >= 8 {
			break
		}
		fmt.Fprintf(&sb, "%02x ", c)
	}
	return strings.TrimSpace(sb.String())
}
