// Package redacted implementa un provider para REDacted (RED), el tracker
// privado de música más grande del mundo (~3M torrents FLAC/FLAC24).
//
// La API de RED es JSON en https://redacted.ch/ajax.php y devuelve:
//   - Búsqueda por ISRC/título → lista de torrents con info_hash
//   - Detalle de torrent → archivos FLAC, tamaño, seeders
//   - Download → .torrent file (se puede convertir a magnet)
//
// Este provider NO descarga torrents directamente — devuelve un
// "stream URL" que el frontend resuelve vía libtorrent_flutter
// (streaming HTTP mientras descarga).
package redacted

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Client es el cliente para la API de REDacted.
type Client struct {
	username string
	password string
	authKey  string
	passKey  string
	userID   int
	session  *http.Client
	baseURL  string
	lastReq  time.Time
}

// NewClient crea un nuevo cliente REDacted.
func NewClient(username, password string) *Client {
	return &Client{
		username: username,
		password: password,
		session: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: "https://redacted.ch",
	}
}

// Name retorna el nombre del provider.
func (c *Client) Name() string { return "redacted" }

// Login autentica contra la API de RED y obtiene authkey + passkey.
func (c *Client) Login() error {
	if c.username == "" || c.password == "" {
		return fmt.Errorf("redacted: se requiere username y password")
	}

	// Login via POST
	loginURL := c.baseURL + "/login.php"
	data := url.Values{
		"username": {c.username},
		"password": {c.password},
	}

	resp, err := c.session.Post(loginURL, "application/x-www-form-urlencoded", strings.NewReader(data.Encode()))
	if err != nil {
		return fmt.Errorf("redacted: login failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("redacted: login returned %d", resp.StatusCode)
	}

	// Extract session cookie
	for _, cookie := range resp.Cookies() {
		if cookie.Name == "session" {
			c.session.Jar = &simpleJar{cookies: map[string]*http.Cookie{"session": cookie}}
		}
	}

	// Get authkey + passkey from index
	var indexResp struct {
		Status   string `json:"status"`
		Response struct {
			Authkey string `json:"authkey"`
			Passkey string `json:"passkey"`
			ID      int    `json:"id"`
		} `json:"response"`
	}

	if err := c.apiGet("index", nil, &indexResp); err != nil {
		return fmt.Errorf("redacted: index failed: %w", err)
	}

	if indexResp.Status != "success" {
		return fmt.Errorf("redacted: index status %s", indexResp.Status)
	}

	c.authKey = indexResp.Response.Authkey
	c.passKey = indexResp.Response.Passkey
	c.userID = indexResp.Response.ID

	return nil
}

// SearchByISRC busca tracks por ISRC en RED.
func (c *Client) SearchByISRC(isrc string) ([]TorrentResult, error) {
	return c.search(isrc)
}

// SearchByTitle busca tracks por título + artista en RED.
func (c *Client) SearchByTitle(query string) ([]TorrentResult, error) {
	return c.search(query)
}

func (c *Client) search(query string) ([]TorrentResult, error) {
	params := url.Values{
		"action":     {"search"},
		"searchterm": {query},
		"format":     {"FLAC"},
		"media":      {"CD", "Vinyl", "Soundboard", "SACD", "DAT", "WEB", "Blu-ray"},
	}

	var searchResp struct {
		Status   string `json:"status"`
		Response struct {
			Results []struct {
				GroupId   int    `json:"groupId"`
				GroupName string `json:"groupName"`
				Artist    string `json:"artist"`
				Year      int    `json:"year"`
				CoverURL  string `json:"coverUrl"`
				Torrents  []struct {
					ID           int    `json:"id"`
					RemasterYear int    `json:"remasterYear"`
					Format       string `json:"format"`
					Encoding     string `json:"encoding"`
					Media        string `json:"media"`
					Size         int64  `json:"size"`
					Seeders      int    `json:"seeders"`
					Leechers     int    `json:"leechers"`
					Snatched     int    `json:"snatched"`
					InfoHash     string `json:"infoHash"`
					FilePath     string `json:"filePath"`
				} `json:"torrents"`
			} `json:"results"`
		} `json:"response"`
	}

	if err := c.apiGet("search", params, &searchResp); err != nil {
		return nil, err
	}

	if searchResp.Status != "success" {
		return nil, fmt.Errorf("redacted: search status %s", searchResp.Status)
	}

	var results []TorrentResult
	for _, g := range searchResp.Response.Results {
		for _, t := range g.Torrents {
			if t.Encoding != "Lossless" {
				continue
			}
			results = append(results, TorrentResult{
				TorrentID: t.ID,
				InfoHash:  t.InfoHash,
				GroupName: g.GroupName,
				Artist:    g.Artist,
				Year:      g.Year,
				CoverURL:  g.CoverURL,
				Format:    t.Format,
				Encoding:  t.Encoding,
				Size:      t.Size,
				Seeders:   t.Seeders,
				Leechers:  t.Leechers,
				Snatched:  t.Snatched,
				FilePath:  t.FilePath,
				MagnetURL: fmt.Sprintf("magnet:?xt=urn:btih:%s&dn=%s", t.InfoHash, url.QueryEscape(g.GroupName)),
			})
		}
	}

	return results, nil
}

// GetTorrentFiles retorna los archivos de un torrent específico.
func (c *Client) GetTorrentFiles(torrentID int) ([]TorrentFile, error) {
	params := url.Values{
		"action": {"torrent"},
		"id":     {fmt.Sprintf("%d", torrentID)},
	}

	var torrentResp struct {
		Status   string `json:"status"`
		Response struct {
			Name     string `json:"name"`
			Size     int64  `json:"size"`
			FileList []struct {
				Name string `json:"name"`
				Size int64  `json:"size"`
			} `json:"fileList"`
			Seeders  int `json:"seeders"`
			Leechers int `json:"leechers"`
		} `json:"response"`
	}

	if err := c.apiGet("torrent", params, &torrentResp); err != nil {
		return nil, err
	}

	if torrentResp.Status != "success" {
		return nil, fmt.Errorf("redacted: torrent status %s", torrentResp.Status)
	}

	var files []TorrentFile
	for _, f := range torrentResp.Response.FileList {
		files = append(files, TorrentFile{
			Name: f.Name,
			Size: f.Size,
		})
	}

	return files, nil
}

// GetMagnetLink retorna el magnet link para un torrent.
func (c *Client) GetMagnetLink(torrentID int, infoHash, name string) string {
	return fmt.Sprintf("magnet:?xt=urn:btih:%s&dn=%s&tr=http://tracker.opentrackr.org:1337/announce&tr=udp://open.stealth.si:80/announce&tr=udp://tracker.openbittorrent.com:6969/announce",
		infoHash, url.QueryEscape(name))
}

// apiGet ejecuta un GET a la API de RED con rate limiting.
func (c *Client) apiGet(action string, params url.Values, target interface{}) error {
	// Rate limit: 2s between requests
	elapsed := time.Since(c.lastReq)
	if elapsed < 2*time.Second {
		time.Sleep(2*time.Second - elapsed)
	}

	if params == nil {
		params = url.Values{}
	}
	params.Set("action", action)
	if c.authKey != "" {
		params.Set("auth", c.authKey)
	}

	reqURL := c.baseURL + "/ajax.php?" + params.Encode()
	resp, err := c.session.Get(reqURL)
	if err != nil {
		return fmt.Errorf("redacted: request failed: %w", err)
	}
	defer resp.Body.Close()

	c.lastReq = time.Now()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("redacted: read body failed: %w", err)
	}

	if err := json.Unmarshal(body, target); err != nil {
		return fmt.Errorf("redacted: json parse failed: %w", err)
	}

	return nil
}

// --- Provider interface implementation ---

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	results, err := c.SearchByTitle(query)
	if err != nil {
		return nil, err
	}

	var tracks []provider.TrackResult
	for i, r := range results {
		if i >= limit {
			break
		}
		tracks = append(tracks, provider.TrackResult{
			ID:       fmt.Sprintf("red:%d", r.TorrentID),
			Title:    r.GroupName,
			Artist:   r.Artist,
			Album:    r.GroupName,
			Duration: 0, // RED no da duración en search
			CoverURL: r.CoverURL,
			Provider: "redacted",
		})
	}

	return tracks, nil
}

func (c *Client) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, nil // Implementar si se necesita
}

func (c *Client) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	return nil, nil
}

func (c *Client) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}

func (c *Client) GetTrack(id string) (*provider.TrackResult, error) {
	return nil, fmt.Errorf("redacted: GetTrack not implemented")
}

func (c *Client) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	results, err := c.SearchByISRC(isrc)
	if err != nil || len(results) == 0 {
		return nil, fmt.Errorf("redacted: no results for ISRC %s", isrc)
	}

	r := results[0]
	return &provider.TrackResult{
		ID:       fmt.Sprintf("red:%d", r.TorrentID),
		Title:    r.GroupName,
		Artist:   r.Artist,
		Album:    r.GroupName,
		CoverURL: r.CoverURL,
		Provider: "redacted",
	}, nil
}

func (c *Client) GetAlbum(id string) (*provider.AlbumResult, error) {
	return nil, fmt.Errorf("redacted: GetAlbum not implemented")
}

func (c *Client) GetArtist(id string) (*provider.ArtistResult, error) {
	return nil, fmt.Errorf("redacted: GetArtist not implemented")
}

func (c *Client) GetStreamURL(id, quality string) (string, error) {
	// El "stream URL" es el magnet link — el frontend lo resuelve
	// vía libtorrent_flutter
	var torrentID int
	if _, err := fmt.Sscanf(id, "red:%d", &torrentID); err != nil {
		return "", fmt.Errorf("redacted: invalid ID format: %s", id)
	}

	// Buscar el torrent para obtener infoHash
	params := url.Values{
		"action": {"torrent"},
		"id":     {fmt.Sprintf("%d", torrentID)},
	}

	var resp struct {
		Status   string `json:"status"`
		Response struct {
			Name     string `json:"name"`
			InfoHash string `json:"infoHash"`
		} `json:"response"`
	}

	if err := c.apiGet("torrent", params, &resp); err != nil {
		return "", err
	}

	if resp.Status != "success" {
		return "", fmt.Errorf("redacted: torrent not found")
	}

	return c.GetMagnetLink(torrentID, resp.Response.InfoHash, resp.Response.Name), nil
}

// simpleJar es un jar de cookies simple para la sesión.
type simpleJar struct {
	cookies map[string]*http.Cookie
}

func (j *simpleJar) SetCookies(u *url.URL, cookies []*http.Cookie) {
	for _, c := range cookies {
		j.cookies[c.Name] = c
	}
}

func (j *simpleJar) Cookies(u *url.URL) []*http.Cookie {
	var cookies []*http.Cookie
	for _, c := range j.cookies {
		cookies = append(cookies, c)
	}
	return cookies
}

// TorrentResult es el resultado de una búsqueda en RED.
type TorrentResult struct {
	TorrentID int
	InfoHash  string
	GroupName string
	Artist    string
	Year      int
	CoverURL  string
	Format    string
	Encoding  string
	Size      int64
	Seeders   int
	Leechers  int
	Snatched  int
	FilePath  string
	MagnetURL string
}

// TorrentFile es un archivo dentro de un torrent.
type TorrentFile struct {
	Name string
	Size int64
}
