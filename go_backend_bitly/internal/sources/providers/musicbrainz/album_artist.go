package musicbrainz

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
)

func (c *Client) FetchAlbumArtistByISRC(isrc string, albumName string) (string, error) {
	normalizedISRC := strings.ToUpper(strings.TrimSpace(isrc))
	if normalizedISRC == "" {
		return "", fmt.Errorf("no ISRC provided")
	}

	key := inFlightKey{isrc: normalizedISRC, queryType: "album_artist"}
	return c.dedup(key, func() (string, error) {
		reqURL := fmt.Sprintf("%s/recording?query=%s&fmt=json&inc=releases+artist-credits",
			apiBase, url.QueryEscape("isrc:"+normalizedISRC))

		resp, err := c.doRequestWithRetry(reqURL)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()

		var payload albumArtistResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			return "", err
		}
		for _, recording := range payload.Recordings {
			if albumArtist := selectAlbumArtist(recording.Releases, albumName); albumArtist != "" {
				return albumArtist, nil
			}
		}
		return "", fmt.Errorf("no MusicBrainz album artist found for ISRC: %s", normalizedISRC)
	})
}

func selectAlbumArtist(releases []struct {
	ID           string `json:"id"`
	Title        string `json:"title"`
	ArtistCredit []struct {
		Name  string `json:"name"`
		Join  string `json:"joinphrase"`
	} `json:"artist-credit"`
}, albumName string) string {
	for _, rel := range releases {
		if strings.EqualFold(rel.Title, albumName) {
			return buildArtistCredit(rel.ArtistCredit)
		}
	}
	if len(releases) > 0 {
		return buildArtistCredit(releases[0].ArtistCredit)
	}
	return ""
}

func buildArtistCredit(credits []struct {
	Name  string `json:"name"`
	Join  string `json:"joinphrase"`
}) string {
	var parts []string
	for _, c := range credits {
		parts = append(parts, c.Name+c.Join)
	}
	return strings.Join(parts, "")
}
