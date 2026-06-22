package musicbrainz

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
)

func (c *Client) FetchGenreByISRC(isrc string) (string, error) {
	normalizedISRC := strings.ToUpper(strings.TrimSpace(isrc))
	if normalizedISRC == "" {
		return "", fmt.Errorf("no ISRC provided")
	}

	key := inFlightKey{isrc: normalizedISRC, queryType: "genre"}
	return c.dedup(key, func() (string, error) {
		reqURL := fmt.Sprintf("%s/recording?query=%s&fmt=json&inc=tags",
			apiBase, url.QueryEscape("isrc:"+normalizedISRC))

		resp, err := c.doRequestWithRetry(reqURL)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()

		var payload recordingResponse
		if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
			return "", err
		}
		if len(payload.Recordings) == 0 {
			return "", fmt.Errorf("no recordings found for ISRC: %s", normalizedISRC)
		}

		genre := formatGenre(payload.Recordings[0].Tags)
		if genre == "" {
			return "", fmt.Errorf("no MusicBrainz genre tags found for ISRC: %s", normalizedISRC)
		}
		return genre, nil
	})
}

func formatGenre(tags []struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}) string {
	seen := make(map[string]bool)
	var genres []string
	for _, tag := range tags {
		name := strings.TrimSpace(tag.Name)
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		if tag.Count >= 1 {
			genres = append(genres, name)
		}
	}
	return strings.Join(genres, ", ")
}
