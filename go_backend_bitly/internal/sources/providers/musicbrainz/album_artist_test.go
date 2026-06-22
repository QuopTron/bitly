package musicbrainz

import (
	"testing"
)

func TestBuildArtistCredit(t *testing.T) {
	t.Run("single", func(t *testing.T) {
		credits := []struct {
			Name  string `json:"name"`
			Join  string `json:"joinphrase"`
		}{{Name: "Artist", Join: ""}}
		if got := buildArtistCredit(credits); got != "Artist" {
			t.Errorf("buildArtistCredit() = %q, want %q", got, "Artist")
		}
	})

	t.Run("featuring", func(t *testing.T) {
		credits := []struct {
			Name  string `json:"name"`
			Join  string `json:"joinphrase"`
		}{{Name: "A", Join: " feat. "}, {Name: "B", Join: ""}}
		if got := buildArtistCredit(credits); got != "A feat. B" {
			t.Errorf("buildArtistCredit() = %q, want %q", got, "A feat. B")
		}
	})

	t.Run("empty", func(t *testing.T) {
		if got := buildArtistCredit(nil); got != "" {
			t.Errorf("buildArtistCredit() = %q, want %q", got, "")
		}
	})
}

func TestSelectAlbumArtist(t *testing.T) {
	makeRel := func(title string, artistName string) struct {
		ID           string `json:"id"`
		Title        string `json:"title"`
		ArtistCredit []struct {
			Name  string `json:"name"`
			Join  string `json:"joinphrase"`
		} `json:"artist-credit"`
	} {
		return struct {
			ID           string `json:"id"`
			Title        string `json:"title"`
			ArtistCredit []struct {
				Name  string `json:"name"`
				Join  string `json:"joinphrase"`
			} `json:"artist-credit"`
		}{
			ID: "rel1", Title: title,
			ArtistCredit: []struct {
				Name  string `json:"name"`
				Join  string `json:"joinphrase"`
			}{{Name: artistName, Join: ""}},
		}
	}

	t.Run("match", func(t *testing.T) {
		rels := []struct {
			ID           string `json:"id"`
			Title        string `json:"title"`
			ArtistCredit []struct {
				Name  string `json:"name"`
				Join  string `json:"joinphrase"`
			} `json:"artist-credit"`
		}{makeRel("Album", "ArtistA"), makeRel("Other", "ArtistB")}
		if got := selectAlbumArtist(rels, "Album"); got != "ArtistA" {
			t.Errorf("selectAlbumArtist() = %q, want %q", got, "ArtistA")
		}
	})

	t.Run("no match", func(t *testing.T) {
		rels := []struct {
			ID           string `json:"id"`
			Title        string `json:"title"`
			ArtistCredit []struct {
				Name  string `json:"name"`
				Join  string `json:"joinphrase"`
			} `json:"artist-credit"`
		}{makeRel("Other", "ArtistB")}
		if got := selectAlbumArtist(rels, "Album"); got != "ArtistB" {
			t.Errorf("selectAlbumArtist() = %q, want %q", got, "ArtistB")
		}
	})

	t.Run("nil", func(t *testing.T) {
		if got := selectAlbumArtist(nil, "Album"); got != "" {
			t.Errorf("selectAlbumArtist() = %q, want %q", got, "")
		}
	})
}


