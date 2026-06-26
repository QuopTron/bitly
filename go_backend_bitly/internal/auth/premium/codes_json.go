package premium

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

const (
	codesAPIURL = "https://api.github.com/repos/QuopTron/bitly_codes_premium/contents/codes.json"
)

var (
	githubToken string
	cache       = &codesCache{}
)

type codesCache struct {
	mu        sync.RWMutex
	data      map[string]string
	updatedAt time.Time
}

type githubContent struct {
	Content string `json:"content"`
	SHA     string `json:"sha"`
}

type githubUpdateReq struct {
	Message string `json:"message"`
	Content string `json:"content"`
	SHA     string `json:"sha"`
}

func SetGithubToken(token string) {
	githubToken = token
}

func fetchCodesJSON() (map[string]string, error) {
	if githubToken == "" {
		return nil, fmt.Errorf("token de GitHub no configurado")
	}

	req, err := http.NewRequest("GET", codesAPIURL, nil)
	if err != nil {
		return nil, fmt.Errorf("fetch codes.json: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+githubToken)
	req.Header.Set("Accept", "application/vnd.github.v3.raw")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch codes.json: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fetch codes.json: status %d", resp.StatusCode)
	}

	var data map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil, fmt.Errorf("decode codes.json: %w", err)
	}

	delete(data, "_NOTA")
	return data, nil
}

func getCachedCodes() map[string]string {
	fresh, err := fetchCodesJSON()
	if err == nil {
		cache.mu.Lock()
		cache.data = fresh
		cache.updatedAt = time.Now()
		cache.mu.Unlock()
		return fresh
	}

	cache.mu.RLock()
	data := cache.data
	cache.mu.RUnlock()
	if data != nil {
		return data
	}
	return nil
}

func CheckCodeInRegistry(code string) error {
	codes := getCachedCodes()
	if codes == nil {
		return fmt.Errorf("no se pudo verificar el código en el registro")
	}

	status, exists := codes[code]
	if !exists {
		return fmt.Errorf("código no encontrado en el registro")
	}

	switch status {
	case "activo":
		return nil
	case "usado":
		return fmt.Errorf("código ya usado")
	case "cancelado":
		return fmt.Errorf("código cancelado")
	case "libre":
		return fmt.Errorf("código liberado")
	default:
		return fmt.Errorf("estado desconocido: %s", status)
	}
}

func MarkCodeAsUsed(code string) error {
	if githubToken == "" {
		return nil
	}

	req, err := http.NewRequest("GET", codesAPIURL, nil)
	if err != nil {
		return fmt.Errorf("get codes.json from API: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+githubToken)
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("get codes.json: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("get codes.json: status %d", resp.StatusCode)
	}

	var content githubContent
	if err := json.NewDecoder(resp.Body).Decode(&content); err != nil {
		return fmt.Errorf("decode github response: %w", err)
	}

	decoded, err := base64.StdEncoding.DecodeString(content.Content)
	if err != nil {
		return fmt.Errorf("decode content base64: %w", err)
	}

	var codes map[string]string
	if err := json.Unmarshal(decoded, &codes); err != nil {
		return fmt.Errorf("parse codes.json: %w", err)
	}

	codes[code] = "usado"

	updated, err := json.MarshalIndent(codes, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal codes.json: %w", err)
	}

	newContent := base64.StdEncoding.EncodeToString(updated)

	update := githubUpdateReq{
		Message: fmt.Sprintf("premium: mark code as usado (%s...)",
			code[:min(len(code), 30)]),
		Content: newContent,
		SHA:     content.SHA,
	}

	body, _ := json.Marshal(update)
	putReq, err := http.NewRequest("PUT", codesAPIURL, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create update request: %w", err)
	}
	putReq.Header.Set("Authorization", "Bearer "+githubToken)
	putReq.Header.Set("Content-Type", "application/json")

	putResp, err := http.DefaultClient.Do(putReq)
	if err != nil {
		return fmt.Errorf("update codes.json: %w", err)
	}
	defer putResp.Body.Close()

	if putResp.StatusCode != http.StatusOK && putResp.StatusCode != http.StatusCreated {
		return fmt.Errorf("update codes.json: status %d", putResp.StatusCode)
	}

	cache.mu.Lock()
	if cache.data != nil {
		cache.data[code] = "usado"
	}
	cache.mu.Unlock()

	return nil
}
