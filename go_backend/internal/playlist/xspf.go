// Package playlist provides XSPF playlist import/export.
//
// XSPF (XML Shareable Playlist Format) is the standard format
// for exchanging playlists between music applications.
package playlist

import (
	"encoding/xml"
	"fmt"
	"time"
)

// XSPFNamespaces
const (
	NSXSPF = "http://xspf.org/ns/0/"
)

// XSPFPlaylist is the root XSPF document.
type XSPFPlaylist struct {
	XMLName   xml.Name   `xml:"playlist"`
	Version   string     `xml:"version,attr"`
	Namespace string     `xml:"xmlns,attr"`
	Title     string     `xml:"title,omitempty"`
	Creator   string     `xml:"creator,omitempty"`
	Date      string     `xml:"date,omitempty"`
	Annotation string    `xml:"annotation,omitempty"`
	Info      string     `xml:"info,omitempty"`
	Location  string     `xml:"location,omitempty"`
	Identifier string    `xml:"identifier,omitempty"`
	Image     string     `xml:"image,omitempty"`
	License   string     `xml:"license,omitempty"`
	Attribution *Link    `xml:"attribution,omitempty"`
	Link      []Link     `xml:"link,omitempty"`
	Meta      []Meta     `xml:"meta,omitempty"`
	Extension *Extension `xml:"extension,omitempty"`
	TrackList  TrackList `xml:"trackList"`
}

// TrackList holds the tracks in an XSPF playlist.
type TrackList struct {
	Track []XSPFTrack `xml:"track"`
}

// XSPFTrack represents a single track in XSPF format.
type XSPFTrack struct {
	Location    []string   `xml:"location,omitempty"`
	Identifier  string     `xml:"identifier,omitempty"`
	Title       string     `xml:"title,omitempty"`
	Creator     string     `xml:"creator,omitempty"`
	Album       string     `xml:"album,omitempty"`
	TrackNum    int        `xml:"trackNum,omitempty"`
	Duration    int        `xml:"duration,omitempty"` // milliseconds
	Image       string     `xml:"image,omitempty"`
	Annotation  string     `xml:"annotation,omitempty"`
	Info        string     `xml:"info,omitempty"`
	Link        []Link     `xml:"link,omitempty"`
	Meta        []Meta     `xml:"meta,omitempty"`
	Extension   *Extension `xml:"extension,omitempty"`
}

// Link is a URI with a relationship.
type Link struct {
	Rel  string `xml:"rel,attr,omitempty"`
	Content string `xml:",chardata"`
}

// Meta is a key-value metadata entry.
type Meta struct {
	Rel  string `xml:"rel,attr"`
	Content string `xml:",chardata"`
}

// Extension holds provider-specific metadata.
type Extension struct {
	Application string     `xml:"application,attr"`
	Provider    string     `xml:"provider,omitempty"`
	TrackID     string     `xml:"trackId,omitempty"`
	ISRC        string     `xml:"isrc,omitempty"`
	CoverURL    string     `xml:"coverUrl,omitempty"`
}

// Marshal returns the XSPF XML string for a playlist.
func Marshal(p *XSPFPlaylist) (string, error) {
	if p.Version == "" {
		p.Version = "1"
	}
	if p.Namespace == "" {
		p.Namespace = NSXSPF
	}
	if p.Date == "" {
		p.Date = time.Now().UTC().Format(time.RFC3339)
	}

	data, err := xml.MarshalIndent(p, "", "  ")
	if err != nil {
		return "", fmt.Errorf("xspf marshal: %w", err)
	}

	return xml.Header + string(data) + "\n", nil
}

// Unmarshal parses an XSPF XML string into a playlist.
func Unmarshal(data string) (*XSPFPlaylist, error) {
	var p XSPFPlaylist
	if err := xml.Unmarshal([]byte(data), &p); err != nil {
		return nil, fmt.Errorf("xspf unmarshal: %w", err)
	}
	return &p, nil
}
