package download

import (
	"log"
	"os"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/audioguard"
)

func esArchivoAudioPlano(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 12)
	n, _ := f.Read(buf)
	if n < 4 {
		return false
	}
	head := string(buf[:4])
	switch {
	case strings.HasPrefix(head, "fLaC"),
		strings.HasPrefix(head, "ID3"),
		strings.HasPrefix(head, "OggS"),
		strings.HasPrefix(head, "RIFF"):
		return true
	}
	// MP4/M4A container: [size:4][ftyp:4][brand:...] — ftyp is at offset 4.
	if n >= 8 && string(buf[4:8]) == "ftyp" {
		return true
	}
	return false
}

// esArchivoAudioReproducible valida que un archivo recién descargado sea un
// contenedor de audio real. Rechaza streams MPEG-TS disfrazados de .mp3
// (SoundCloud HLS), archivos vacíos o diminutos, y cualquier otra cosa.
//
// DELEGA EN audioguard a propósito. Es el mismo filtro que protege la descarga
// P2P de Soulseek, y hacerlo compartido es el punto: el archivo descargado de
// Internet Archive pasa por acá igual que el que sube un par, así que los dos
// quedan cubiertos por la MISMA lista blanca. Si cada ruta tuviera su propio
// chequeo, la próxima fuente nueva volvería a abrir el agujero.
//
// Es lista blanca, no lista negra: lo que no se reconoce como audio NO pasa.
// Un .exe renombrado a .flac se rechaza nombrando el motivo (firma MZ/PE), y
// con él cualquier otro binario. Importa más allá de "ejecutarse": el archivo
// se le entrega a ffmpeg para convertir o descifrar, y un parser de formatos
// alimentado con datos hostiles es la superficie de ataque real.
//
// Se llama después de finalizar el archivo (renombrado desde .tmp), cuando ya
// está completo.
func esArchivoAudioReproducible(path string) bool {
	v := audioguard.Revisar(path)
	if v.OK {
		log.Printf("[playable-check] %s: ACCEPTED (formato=%s, %d bytes)", path, v.Formato, v.Bytes)
		return true
	}
	log.Printf("[playable-check] %s: REJECTED (%s)", path, v.Motivo)
	return false
}

// isHLSManifest checks if a file is an M3U8/HLS playlist manifest instead of
// actual audio. SoundCloud sometimes returns HLS streams whose URL points to a
// text manifest (starting with #EXTM3U or #EXT-X-) rather than binary audio.
// These must NOT be marked as "encrypted for client decrypt" because they are
// not DRM content — they're just playlists pointing to separate segments.
func esManifiestoHLS(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 16)
	n, _ := f.Read(buf)
	if n < 7 {
		return false
	}
	// Busca #EXTM3U (cabecera M3U8) — primeros 7 bytes
	if string(buf[:7]) == "#EXTM3U" {
		return true
	}
	// Busca #EXT-X- (etiquetas de lista HLS variante)
	if n >= 7 && string(buf[:7]) == "#EXT-X-" {
		return true
	}
	return false
}

// decryptStream decrypts an encrypted/DRM stream file ([inputPath]) with
// ffmpeg's -decryption_key into a playable file in [outDir], returning the
// decrypted path. [outExt] selects the output container (".flac" for flac
// content, ".mp4" for eac3/ac4/opus); empty defaults to ".mp4". [inFormat]
// forces the MOV/MP4 demuxer (the input may carry a .flac name while actually
// holding an encrypted MP4), so any provider's encrypted download decrypts
// correctly. On any failure it removes partial output and returns an error so
// el caller puede fall back (reject este proveedor, try el siguiente uno).
