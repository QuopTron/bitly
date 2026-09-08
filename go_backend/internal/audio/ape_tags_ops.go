package audio

import (
	"fmt"
	"strings"
)

func (t *APETags) Get(key string) string {
	key = strings.ToUpper(key)
	for _, item := range t.Items {
		if item.Key == key && item.Flag == 0 { // UTF-8 only
			return string(item.Value)
		}
	}
	return ""
}

// Set agrega o reemplaza un tag de texto en los items del APE.
func (t *APETags) Set(key, value string) {
	key = strings.ToUpper(key)
	for i, item := range t.Items {
		if item.Key == key {
			t.Items[i].Value = []byte(value)
			t.Items[i].Flag = 0
			return
		}
	}
	t.Items = append(t.Items, APETagItem{
		Key:   key,
		Value: []byte(value),
		Flag:  0,
	})
}

// SetBinary adds or replaces a binary tag item (e.g. cover art).
func (t *APETags) SetBinary(key string, data []byte) {
	key = strings.ToUpper(key)
	for i, item := range t.Items {
		if item.Key == key {
			t.Items[i].Value = data
			t.Items[i].Flag = 1
			return
		}
	}
	t.Items = append(t.Items, APETagItem{
		Key:   key,
		Value: data,
		Flag:  1,
	})
}

// ToAudioMetadata converts APE tags to the standard Metadata struct.
func (t *APETags) ToAudioMetadata() *Metadata {
	m := &Metadata{}
	m.Title = t.Get("TITLE")
	m.Artist = t.Get("ARTIST")
	m.Album = t.Get("ALBUM")
	m.AlbumArtist = t.Get("ALBUMARTIST")
	m.Genre = t.Get("GENRE")
	m.ISRC = t.Get("ISRC")

	if v := t.Get("TRACK"); v != "" {
		fmt.Sscanf(v, "%d", &m.TrackNumber)
	}
	if v := t.Get("DISC"); v != "" {
		fmt.Sscanf(v, "%d", &m.DiscNumber)
	}
	if v := t.Get("DATE"); v != "" {
		fmt.Sscanf(v, "%d", &m.Year)
	}
	if v := t.Get("YEAR"); v != "" && m.Year == 0 {
		fmt.Sscanf(v, "%d", &m.Year)
	}
	return m
}

// WriteAPETags writes APEv2 tags to a file (header + footer).
