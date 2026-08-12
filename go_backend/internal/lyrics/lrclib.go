package lyrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

type lrcLibProvider struct{ http *http.Client }

func (p *lrcLibProvider) Name() string { return "lrclib" }

func (p *lrcLibProvider) FetchLyrics(trackName, artistName string) (*Lyrics, error) {
	base := "https://lrclib.net/api"
	params := url.Values{}
	params.Set("track_name", trackName)
	params.Set("artist_name", artistName)

	resp, err := p.http.Get(base + "/get?" + params.Encode())
	if err != nil {
		return p.searchFallback(base, trackName, artistName)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return p.searchFallback(base, trackName, artistName)
	}

	var lyrics Lyrics
	if err := json.NewDecoder(resp.Body).Decode(&lyrics); err != nil {
		return nil, err
	}
	lyrics.Source = "lrclib"
	return &lyrics, nil
}

func (p *lrcLibProvider) searchFallback(base, trackName, artistName string) (*Lyrics, error) {
	q := url.QueryEscape(trackName + " " + artistName)
	resp, err := p.http.Get(base + "/search?q=" + q)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var results []Lyrics
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("lrclib: not found")
	}
	lyrics := results[0]
	lyrics.Source = "lrclib"
	return &lyrics, nil
}
