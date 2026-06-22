package availability

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

func (lr *LinkResolver) resolveViaSongstats(isrc string) (*ISRCResolutionResult, error) {
	songstatsURL := fmt.Sprintf("https://api.songstats.com/v1/tracks?isrc=%s&platforms=tidal,qobuz,deezer,spotify", isrc)
	req, err := http.NewRequest("GET", songstatsURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
	req.Header.Set("Accept", "application/json")

	resp, err := lr.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var songstatsResp struct {
		Data []struct {
			ISRC    string `json:"isrc"`
			Streams []struct {
				Platform string `json:"platform"`
				URL      string `json:"url"`
			} `json:"streams"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &songstatsResp); err != nil {
		return nil, err
	}
	if len(songstatsResp.Data) == 0 {
		return nil, fmt.Errorf("linkresolver: ISRC not found on Songstats: %s", isrc)
	}

	result := &ISRCResolutionResult{ISRC: isrc}
	for _, stream := range songstatsResp.Data[0].Streams {
		switch strings.ToLower(stream.Platform) {
		case "tidal":
			result.TidalURL = stream.URL
		case "qobuz":
			result.QobuzURL = stream.URL
		case "deezer":
			result.DeezerURL = stream.URL
		case "spotify":
			result.SpotifyURL = stream.URL
		}
	}
	return result, nil
}

func (lr *LinkResolver) ISRCFromSpotify(spotifyID string) (string, error) {
	spotifyURL := fmt.Sprintf("https://api.spotify.com/v1/tracks/%s", spotifyID)
	req, err := http.NewRequest("GET", spotifyURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0")

	resp, err := lr.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var track struct {
		ExternalIDs struct {
			ISRC string `json:"isrc"`
		} `json:"external_ids"`
		Name    string `json:"name"`
		Artists []struct {
			Name string `json:"name"`
		} `json:"artists"`
		Album struct {
			Name string `json:"name"`
		} `json:"album"`
	}
	if err := json.Unmarshal(body, &track); err != nil {
		return "", err
	}
	if track.ExternalIDs.ISRC == "" {
		return "", fmt.Errorf("linkresolver: no ISRC found for Spotify track: %s", spotifyID)
	}
	return track.ExternalIDs.ISRC, nil
}
