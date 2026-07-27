package playlist

import (
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Playlist is a high-level playlist entry used by Flutter.
type Playlist struct {
	ID         string         `json:"id"`
	Name       string         `json:"name"`
	Creator    string         `json:"creator"`
	Date       string         `json:"date"`
	TrackCount int            `json:"trackCount"`
	Tracks     []PlaylistTrack `json:"tracks"`
}

// PlaylistTrack is a track within a playlist.
type PlaylistTrack struct {
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	Album    string `json:"album"`
	Duration int    `json:"durationMs"`
	ISRC     string `json:"isrc,omitempty"`
	CoverURL string `json:"coverUrl,omitempty"`
	Provider string `json:"provider,omitempty"`
	TrackID  string `json:"trackId,omitempty"`
	Location string `json:"location,omitempty"` // local file path
}

// New creates a Playlist from a list of tracks.
func New(name, creator string, tracks []PlaylistTrack) *Playlist {
	return &Playlist{
		ID:         fmt.Sprintf("pl_%d", time.Now().UnixNano()),
		Name:       name,
		Creator:    creator,
		Date:       time.Now().UTC().Format(time.RFC3339),
		TrackCount: len(tracks),
		Tracks:     tracks,
	}
}

// FromTrackResults converts provider.TrackResult slices into PlaylistTracks.
func FromTrackResults(results []provider.TrackResult) []PlaylistTrack {
	tracks := make([]PlaylistTrack, 0, len(results))
	for _, r := range results {
		tracks = append(tracks, PlaylistTrack{
			Title:    r.Title,
			Artist:   r.Artist,
			Album:    r.Album,
			Duration: r.Duration,
			ISRC:     r.ISRC,
			CoverURL: r.CoverURL,
			Provider: r.Provider,
			TrackID:  r.ID,
		})
	}
	return tracks
}

// FromXSPF converts an XSPFPlaylist into a Playlist.
func FromXSPF(x *XSPFPlaylist) *Playlist {
	tracks := make([]PlaylistTrack, 0, len(x.TrackList.Track))
	for _, t := range x.TrackList.Track {
		pt := PlaylistTrack{
			Title:    t.Title,
			Artist:   t.Creator,
			Album:    t.Album,
			Duration: t.Duration,
			CoverURL: t.Image,
		}
		if len(t.Location) > 0 {
			pt.Location = t.Location[0]
		}
		if t.Identifier != "" {
			pt.ISRC = t.Identifier
		}
		if t.Extension != nil {
			pt.Provider = t.Extension.Provider
			pt.TrackID = t.Extension.TrackID
			if pt.CoverURL == "" {
				pt.CoverURL = t.Extension.CoverURL
			}
		}
		tracks = append(tracks, pt)
	}

	return &Playlist{
		ID:         "imported_" + fmt.Sprintf("%d", time.Now().UnixNano()),
		Name:       x.Title,
		Creator:    x.Creator,
		Date:       x.Date,
		TrackCount: len(tracks),
		Tracks:     tracks,
	}
}

// ToXSPF converts a Playlist to an XSPFPlaylist.
func (p *Playlist) ToXSPF() *XSPFPlaylist {
	x := &XSPFPlaylist{
		Version:   "1",
		Namespace: NSXSPF,
		Title:     p.Name,
		Creator:   p.Creator,
		Date:      p.Date,
		TrackList: TrackList{},
	}

	for _, t := range p.Tracks {
		xt := XSPFTrack{
			Title:    t.Title,
			Creator:  t.Artist,
			Album:    t.Album,
			Duration: t.Duration,
			Image:    t.CoverURL,
		}
		if t.Location != "" {
			xt.Location = []string{t.Location}
		}
		if t.ISRC != "" {
			xt.Identifier = "isrc:" + t.ISRC
		}
		if t.Provider != "" || t.TrackID != "" {
			xt.Extension = &Extension{
				Application: "bitly",
				Provider:    t.Provider,
				TrackID:     t.TrackID,
				CoverURL:    t.CoverURL,
			}
		}
		x.TrackList.Track = append(x.TrackList.Track, xt)
	}

	return x
}

// ExportXML returns the XSPF XML string for this playlist.
func (p *Playlist) ExportXML() (string, error) {
	return Marshal(p.ToXSPF())
}
