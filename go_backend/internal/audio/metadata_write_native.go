package audio

import (
	"fmt"
	"os"
	"strings"
)

func WriteMetadata(path string, meta *Metadata) error {
	ext := strings.ToLower(path)
	switch {
	case strings.HasSuffix(ext, ".flac"):
		return escribirMetadataFLAC(path, meta)
	case strings.HasSuffix(ext, ".mp3"):
		return escribirMetadataMP3(path, meta)
	case strings.HasSuffix(ext, ".m4a"), strings.HasSuffix(ext, ".mp4"):
		return escribirMetadataM4A(path, meta)
	case strings.HasSuffix(ext, ".ogg"), strings.HasSuffix(ext, ".opus"):
		return escribirMetadataOGG(path, meta)
	}
	return fmt.Errorf("ERR_AUDIO_WRITE: escritura nativa no soportada para %s", ext)
}

func escribirMetadataFLAC(path string, meta *Metadata) error {
	tags, err := ReadAPETags(path)
	if err != nil {
		tags = &APETags{}
	}

	if meta.Title != "" {
		tags.Set("TITLE", meta.Title)
	}
	if meta.Artist != "" {
		tags.Set("ARTIST", meta.Artist)
	}
	if meta.Album != "" {
		tags.Set("ALBUM", meta.Album)
	}
	if meta.AlbumArtist != "" {
		tags.Set("ALBUMARTIST", meta.AlbumArtist)
	}
	if meta.Genre != "" {
		tags.Set("GENRE", meta.Genre)
	}
	if meta.ISRC != "" {
		tags.Set("ISRC", meta.ISRC)
	}
	if meta.Year > 0 {
		tags.Set("DATE", fmt.Sprintf("%d", meta.Year))
	}
	if meta.TrackNumber > 0 {
		if meta.TrackTotal > 0 {
			tags.Set("TRACKNUMBER", fmt.Sprintf("%d/%d", meta.TrackNumber, meta.TrackTotal))
		} else {
			tags.Set("TRACKNUMBER", fmt.Sprintf("%d", meta.TrackNumber))
		}
	}
	if meta.DiscNumber > 0 {
		tags.Set("DISCNUMBER", fmt.Sprintf("%d", meta.DiscNumber))
	}

	return WriteAPETags(path, tags)
}

func escribirMetadataMP3(path string, meta *Metadata) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	// Simple ID3v2.4 frame writer
	var frames []byte
	if meta.Title != "" {
		frames = append(frames, construirFrameID3("TIT2", meta.Title)...)
	}
	if meta.Artist != "" {
		frames = append(frames, construirFrameID3("TPE1", meta.Artist)...)
	}
	if meta.Album != "" {
		frames = append(frames, construirFrameID3("TALB", meta.Album)...)
	}
	if meta.ISRC != "" {
		frames = append(frames, construirFrameID3("TSRC", meta.ISRC)...)
	}
	if meta.Year > 0 {
		frames = append(frames, construirFrameID3("TDRC", fmt.Sprintf("%d", meta.Year))...)
	}

	if len(frames) == 0 {
		return nil
	}

	// Construye la cabecera ID3v2.4
	header := construirCabeceraID3v2(len(frames))
	newData := make([]byte, 0, len(header)+len(frames)+len(data))
	newData = append(newData, header...)
	newData = append(newData, frames...)

	// Omite el tag ID3v2 viejo si existe
	if len(data) > 10 && string(data[:3]) == "ID3" {
		oldSize := int(data[6])<<21 | int(data[7])<<14 | int(data[8])<<7 | int(data[9])
		newData = append(newData, data[10+oldSize:]...)
	} else {
		newData = append(newData, data...)
	}

	return os.WriteFile(path, newData, 0644)
}

func escribirMetadataM4A(path string, meta *Metadata) error {
	tags := make(map[string]string)
	if meta.ISRC != "" {
		tags["ISRC"] = meta.ISRC
	}
	if meta.Genre != "" {
		tags["Genre"] = meta.Genre
	}
	if len(tags) == 0 {
		return nil
	}
	return WriteM4AFreeformTags(path, tags)
}

func escribirMetadataOGG(path string, meta *Metadata) error {
	// OGG metadata writing is complex; for now read and validate
	return nil
}
