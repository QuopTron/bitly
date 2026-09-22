// Package spotify implements a client for the Spotify Web API.
// Note: Spotify does not provide download/stream URLs — this is for
// metadata lookup and search only.
package spotify

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const baseURL = "https://api.spotify.com/v1"

// errSinCredenciales marca "este proveedor no está configurado", que es
// distinto de "la red falló": los caminos de búsqueda lo tratan como source
// no disponible (rápido) en vez de reintentar.
var errSinCredenciales = errors.New("spotify: faltan client_id/client_secret")

// Client is the Spotify API client.
type Client struct {
	http         *http.Client
	clientID     string
	clientSecret string
	token        string
	tokenExp     time.Time
	mu           sync.Mutex
}

// NewClient creates a Spotify client with OAuth app credentials.
func NewClient(httpClient *http.Client, clientID, clientSecret string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{
		http:         httpClient,
		clientID:     clientID,
		clientSecret: clientSecret,
	}
}

// ensureToken obtains a fresh OAuth token if expired.
//
// Si no hay credenciales, falla ANTES de tocar la red: antes se pedía el token
// con Basic Auth vacío, Spotify respondía 400, el token quedaba vacío y la
// llamada siguiente se iba en 401 → eso disparaba el reintento de doGet sin
// freno (ver doGetIntento). Con dos búsquedas en paralelo eso se convertía en
// un bucle infinito de peticiones que además clavaba a la búsqueda entera en el
// timeout global.
func (c *Client) ensureToken() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.token != "" && time.Now().Before(c.tokenExp) {
		return nil
	}
	if strings.TrimSpace(c.clientID) == "" || strings.TrimSpace(c.clientSecret) == "" {
		return errSinCredenciales
	}
	data := url.Values{
		"grant_type": {"client_credentials"},
	}
	req, err := http.NewRequest("POST", "https://accounts.spotify.com/api/token",
		strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(c.clientID, c.clientSecret)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		ExpiresIn   int    `json:"expires_in"`
	}
	// El cuerpo se acota: una respuesta de error no debe poder volcar megabytes
	// a memoria, y solo el caso 2xx trae un token usable.
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 8<<10))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("spotify: token HTTP %d: %s",
			resp.StatusCode, strings.TrimSpace(string(body)))
	}
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return err
	}
	if tokenResp.AccessToken == "" {
		return fmt.Errorf("spotify: token vacío (HTTP %d)", resp.StatusCode)
	}
	c.token = tokenResp.AccessToken
	if tokenResp.ExpiresIn <= 60 {
		// Sin `expires_in` confiable, se fuerza a re-consultar en un minuto en
		// vez de dejar el token vivo para siempre.
		tokenResp.ExpiresIn = 120
	}
	c.tokenExp = time.Now().Add(time.Duration(tokenResp.ExpiresIn-60) * time.Second)
	return nil
}

// Name returns "spotify" for the provider registry.
func (c *Client) Name() string { return "spotify" }

// doGet performs an authenticated GET to the Spotify API.
func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	return c.doGetIntento(path, params, result, true)
}

// doGetIntento es doGet con permiso explícito de re-autenticar UNA vez.
//
// Antes era doGet llamándose a sí misma sin contador: con credenciales vacías
// Spotify responde 401 en cada intento, el token se borraba y la función se
// volvía a llamar indefinidamente. Ese bucle no terminaba nunca, así que la
// búsqueda "Todas" esperaba el timeout global completo (4 s) en CADA consulta,
// y el goroutine quedaba vivo quemando peticiones contra la API de Spotify.
func (c *Client) doGetIntento(path string, params map[string]string, result interface{}, permitirReintento bool) error {
	if err := c.ensureToken(); err != nil {
		return err
	}
	u, _ := url.Parse(baseURL + path)
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("Authorization", "Bearer "+c.token)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 8<<10))
		if resp.StatusCode == 401 && permitirReintento {
			c.mu.Lock()
			c.token = ""
			c.mu.Unlock()
			// Un solo reintento: el segundo 401 es una credencial inválida, no
			// un token vencido, y reintentar más solo alarga la búsqueda.
			return c.doGetIntento(path, params, result, false)
		}
		return fmt.Errorf("spotify: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return json.NewDecoder(resp.Body).Decode(result)
}
