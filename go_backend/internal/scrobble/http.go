package scrobble

import (
	"net/http"
	"net/url"
	"strings"
)

// Helpers HTTP compartidos por lastfm.go y listenbrainz.go: cada servicio
// tiene su propio protocolo (form urlencoded vs JSON) y su propio header
// de autorización, así el resto del paquete solo arma el payload.

// postForm envía un formulario urlencoded (protocolo de Last.fm).
func postForm(c *Client, apiURL string, data url.Values) error {
	req, err := http.NewRequest(http.MethodPost, apiURL, strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// postJSON envía un cuerpo JSON (protocolo de ListenBrainz) con el token de
// autorización opcional.
func postJSON(c *Client, apiURL string, body []byte, authToken string) error {
	req, err := http.NewRequest(http.MethodPost, apiURL, strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if authToken != "" {
		req.Header.Set("Authorization", "Token "+authToken)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}
