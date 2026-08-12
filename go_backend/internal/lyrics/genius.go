package lyrics

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

type geniusProvider struct {
	http  *http.Client
	token string
}

func (p *geniusProvider) Name() string { return "genius" }

func (p *geniusProvider) FetchLyrics(trackName, artistName string) (*Lyrics, error) {
	q := url.QueryEscape(trackName + " " + artistName)
	searchURL := fmt.Sprintf("https://api.genius.com/search?q=%s", q)

	req, _ := http.NewRequest("GET", searchURL, nil)
	req.Header.Set("Authorization", "Bearer "+p.token)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := p.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Response struct {
			Hits []struct {
				Result struct {
					ID    int    `json:"id"`
					Title string `json:"title"`
					URL   string `json:"url"`
				} `json:"result"`
			} `json:"hits"`
		} `json:"response"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if len(result.Response.Hits) == 0 {
		return nil, fmt.Errorf("genius: not found")
	}

	plain, err := scrapeGeniusLyrics(p.http, result.Response.Hits[0].Result.URL)
	if err != nil {
		return nil, err
	}
	return &Lyrics{PlainLyrics: plain, Source: "genius"}, nil
}

func scrapeGeniusLyrics(client *http.Client, pageURL string) (string, error) {
	req, _ := http.NewRequest("GET", pageURL, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	start := strings.Index(html, `data-lyrics-container="true"`)
	if start < 0 {
		return "", fmt.Errorf("genius: container not found")
	}
	containerStart := strings.Index(html[start:], ">")
	if containerStart < 0 {
		return "", fmt.Errorf("genius: no content")
	}
	contentStart := start + containerStart + 1
	contentEnd := strings.Index(html[contentStart:], "</div>")
	if contentEnd < 0 {
		return "", fmt.Errorf("genius: no end div")
	}

	raw := html[contentStart : contentStart+contentEnd]
	raw = strings.ReplaceAll(raw, "<br/>", "\n")
	raw = strings.ReplaceAll(raw, "<br>", "\n")
	raw = strings.ReplaceAll(raw, "&amp;", "&")
	raw = strings.ReplaceAll(raw, "&quot;", "\"")
	raw = stripHTMLTags(raw)
	return strings.TrimSpace(raw), nil
}

func stripHTMLTags(s string) string {
	var b strings.Builder
	inTag := false
	for _, r := range s {
		if r == '<' {
			inTag = true
			continue
		}
		if r == '>' {
			inTag = false
			continue
		}
		if !inTag {
			b.WriteRune(r)
		}
	}
	return b.String()
}
