package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"time"
)

type googleTokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	TokenType    string `json:"token_type"`
	Error        string `json:"error"`
	ErrorDesc    string `json:"error_description"`
}

func llamadaTokenGoogle(form url.Values) (map[string]interface{}, error) {
	client := &http.Client{Timeout: 25 * time.Second}
	resp, err := client.PostForm("https://oauth2.googleapis.com/token", form)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var tr googleTokenResponse
	if err := json.Unmarshal(body, &tr); err != nil {
		return nil, fmt.Errorf("respuesta inválida (%d)", resp.StatusCode)
	}
	if tr.Error != "" {
		return nil, fmt.Errorf("%s: %s", tr.Error, tr.ErrorDesc)
	}
	if tr.AccessToken == "" {
		return nil, fmt.Errorf("sin access_token (HTTP %d)", resp.StatusCode)
	}
	return map[string]interface{}{
		"ok":            true,
		"access_token":  tr.AccessToken,
		"refresh_token": tr.RefreshToken,
		"expires_in":    tr.ExpiresIn,
		"token_type":    tr.TokenType,
	}, nil
}

// logYouTubeOAuth is a tiny helper so future debugging does not leak secrets.
func logYoutubeOAuth(format string, args ...interface{}) {
	log.Printf("[youtube-oauth] "+format, args...)
}
