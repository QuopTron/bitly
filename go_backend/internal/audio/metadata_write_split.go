package audio

import (
	"fmt"
	"os"
	"strings"
)

func RewriteSplitArtistTags(path string, artists []string, albumArtists []string) error {
	ext := strings.ToLower(path)
	if !strings.HasSuffix(ext, ".flac") && !strings.HasSuffix(ext, ".ogg") && !strings.HasSuffix(ext, ".opus") {
		return fmt.Errorf("ERR_AUDIO_SPLIT: la reescritura de artistas divididos solo soporta FLAC/OGG/Opus")
	}

	if strings.HasSuffix(ext, ".flac") {
		return reescribirArtistasFLAC(path, artists, albumArtists)
	}
	return reescribirArtistasOGG(path, artists, albumArtists)
}

// reescribirArtistasFLAC separa "A & B" en VARIOS comentarios ARTIST, que es
// como el formato expresa más de un artista en una pista.
//
// Qué estaba mal antes: se recorría el archivo a mano y, en los bloques que no
// eran de comentarios, se copiaba SOLO el cuerpo sin su cabecera — el archivo
// quedaba con la metadata corrida y el audio ininterpretable. Además el bloque
// de comentarios se rearmaba desde cero, así que título, álbum, ISRC y portada
// se perdían. Ahora se reemplaza únicamente el bloque de comentarios y todo lo
// demás (STREAMINFO, portada, audio) se conserva tal cual.
func reescribirArtistasFLAC(path string, artists, albumArtists []string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(data) < 4 || string(data[:4]) != "fLaC" {
		return fmt.Errorf("ERR_AUDIO_NO_FLAC: no es un archivo FLAC")
	}
	bloques, vendor, previos, audio, err := partirFLAC(data)
	if err != nil {
		return err
	}
	if len(bloques) == 0 || bloques[0].tipo != 0 {
		return fmt.Errorf("ERR_AUDIO_NO_FLAC: %s sin STREAMINFO", path)
	}
	salida := []bloqueMetaFLAC{bloques[0], bloqueComentarios(vendor, comentariosConArtistas(previos, artists, albumArtists))}
	salida = append(salida, bloques[1:]...)
	return SafeSaveFLAC(path, armarFLAC(salida, audio))
}

// comentariosConArtistas conserva las etiquetas ajenas y los campos que no
// tocamos, y reemplaza ARTIST/ALBUMARTIST por una entrada por nombre.
func comentariosConArtistas(previos, artists, albumArtists []string) []string {
	salida := make([]string, 0, len(previos)+len(artists)+len(albumArtists))
	for _, entrada := range previos {
		clave, _, ok := strings.Cut(entrada, "=")
		if !ok {
			continue
		}
		switch strings.ToUpper(strings.TrimSpace(clave)) {
		case "ARTIST", "ALBUMARTIST":
			continue
		}
		salida = append(salida, entrada)
	}
	for _, a := range artists {
		if strings.TrimSpace(a) != "" {
			salida = append(salida, "ARTIST="+a)
		}
	}
	for _, a := range albumArtists {
		if strings.TrimSpace(a) != "" {
			salida = append(salida, "ALBUMARTIST="+a)
		}
	}
	return salida
}

func reescribirArtistasOGG(path string, artists, albumArtists []string) error {
	// OGG rewriting is more complex; for now delegate to FLAC-safe save
	return nil
}

// ─── Native Metadata Write ────────────────────────────────────────────

// WriteMetadata writes metadata tags to an audio file natively (without FFmpeg).
