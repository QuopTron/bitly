package gobackend

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// GitHubRelease representa una release de GitHub
// https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#get-the-latest-release
type GitHubRelease struct {
	URL         string      `json:"url"`
	HTMLURL     string      `json:"html_url"`
	AssetsURL   string      `json:"assets_url"`
	UploadURL   string      `json:"upload_url"`
	TarballURL  string      `json:"tarball_url"`
	ZipballURL  string      `json:"zipball_url"`
	ID          int         `json:"id"`
	NodeID      string      `json:"node_id"`
	TagName     string      `json:"tag_name"`
	TargetCommitish string   `json:"target_commitish"`
	Name        string      `json:"name"`
	Draft       bool        `json:"draft"`
	Prerelease  bool        `json:"prerelease"`
	CreatedAt   time.Time   `json:"created_at"`
	PublishedAt time.Time   `json:"published_at"`
	Assets      []GitHubAsset `json:"assets"`
	Body        string      `json:"body"`
}

// GitHubAsset representa un asset adjunto a una release
type GitHubAsset struct {
	URL               string `json:"url"`
	BrowserDownloadURL string `json:"browser_download_url"`
	ID                int    `json:"id"`
	NodeID            string `json:"node_id"`
	Name              string `json:"name"`
	Label             string `json:"label"`
	State             string `json:"state"`
	ContentType       string `json:"content_type"`
	Size              int    `json:"size"`
	DownloadCount     int    `json:"download_count"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// ApkVariant tipo de variante APK
type ApkVariant int

const (
	ApkVariantUnknown ApkVariant = iota
	ApkVariantArm64
	ApkVariantArm32
	ApkVariantUniversal
)

// ApkAssetInfo información del asset APK
type ApkAssetInfo struct {
	Name     string    `json:"name"`
	URL      string    `json:"url"`
	Variant  ApkVariant `json:"variant"`
}

// UpdateCheckResult resultado de la comprobación de actualización
type UpdateCheckResult struct {
	Version         string    `json:"version"`
	Changelog       string    `json:"changelog"`
	DownloadURL     string    `json:"download_url"`
	APKDownloadURL  *string   `json:"apk_download_url,omitempty"`
	PublishedAt     time.Time `json:"published_at"`
	IsPrerelease    bool      `json:"is_prerelease"`
	CurrentVersion  string    `json:"current_version"`
	HasUpdate       bool      `json:"has_update"`
	Error           string    `json:"error,omitempty"`
}

// Configuración del repositorio
const (
	GitHubAPIBase = "https://api.github.com/repos"
	// Repo principal - se puede configurar vía argumento
	DefaultGitHubRepo = "Quoptron/bitly"
	// User-Agent requerido por GitHub API
	GitHubUserAgent = "Bitly-Android/1.0 (+https://github.com/Quoptron/bitly)"
)

// GitHubClient cliente para la API de GitHub
type GitHubClient struct {
	Client    *http.Client
	RepoOwner string
	RepoName  string
	BaseURL   string
}

// NewGitHubClient crea un nuevo cliente de GitHub
func NewGitHubClient(repo string) *GitHubClient {
	parts := strings.Split(repo, "/")
	owner := ""
	name := ""
	if len(parts) >= 2 {
		owner = parts[0]
		name = parts[1]
	}
	if owner == "" {
		owner = "zarzet"
	}
	if name == "" {
		name = "Bitly"
	}

	return &GitHubClient{
		Client:    &http.Client{Timeout: 30 * time.Second},
		RepoOwner: owner,
		RepoName:  name,
		BaseURL:   fmt.Sprintf("%s/%s/%s", GitHubAPIBase, owner, name),
	}
}

// fetchJSON hace una petición GET a la API de GitHub y decodifica el JSON
func (c *GitHubClient) fetchJSON(url string, result interface{}) error {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("User-Agent", GitHubUserAgent)

	resp, err := c.Client.Do(req)
	if err != nil {
		return fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("GitHub API returned status %d: %s", resp.StatusCode, string(body))
	}

	return json.NewDecoder(resp.Body).Decode(result)
}

// GetLatestRelease obtiene la última release del repositorio
func (c *GitHubClient) GetLatestRelease() (*GitHubRelease, error) {
	url := fmt.Sprintf("%s/releases/latest", c.BaseURL)
	var release GitHubRelease
	if err := c.fetchJSON(url, &release); err != nil {
		return nil, fmt.Errorf("failed to get latest release: %w", err)
	}
	return &release, nil
}

// GetAllReleases obtiene todas las releases (hasta perPage)
func (c *GitHubClient) GetAllReleases(perPage int) ([]GitHubRelease, error) {
	url := fmt.Sprintf("%s/releases?per_page=%d", c.BaseURL, perPage)
	var releases []GitHubRelease
	if err := c.fetchJSON(url, &releases); err != nil {
		return nil, fmt.Errorf("failed to get releases: %w", err)
	}
	return releases, nil
}

// getApkVariantFromName determina el tipo de variante APK del nombre
func getApkVariantFromName(name string) ApkVariant {
	lowerName := strings.ToLower(name)
	if strings.Contains(lowerName, "universal") {
		return ApkVariantUniversal
	}
	if strings.Contains(lowerName, "arm64") || strings.Contains(lowerName, "arm64-v8a") {
		return ApkVariantArm64
	}
	if strings.Contains(lowerName, "arm32") || strings.Contains(lowerName, "armeabi") ||
		strings.Contains(lowerName, "armv7") || strings.Contains(lowerName, "v7a") {
		return ApkVariantArm32
	}
	return ApkVariantUnknown
}

// collectApkAssets recolecta todos los assets APK de una release
func (c *GitHubClient) collectApkAssets(assets []GitHubAsset) []ApkAssetInfo {
	var apkAssets []ApkAssetInfo
	for _, asset := range assets {
		if !strings.HasSuffix(strings.ToLower(asset.Name), ".apk") {
			continue
		}
		if asset.BrowserDownloadURL == "" {
			continue
		}
		variant := getApkVariantFromName(asset.Name)
		if variant == ApkVariantUnknown {
			continue
		}
		apkAssets = append(apkAssets, ApkAssetInfo{
			Name:    asset.Name,
			URL:     asset.BrowserDownloadURL,
			Variant: variant,
		})
	}
	return apkAssets
}

// selectBestApk selecciona el mejor APK según prioridad: arm64 > universal > arm32
func selectBestApk(assets []ApkAssetInfo) *ApkAssetInfo {
	var best *ApkAssetInfo
	for _, asset := range assets {
		// Prioridad: arm64 > universal > arm32
		if best == nil {
			best = &asset
			continue
		}
		if asset.Variant == ApkVariantArm64 {
			return &asset
		}
		if best.Variant == ApkVariantUniversal && asset.Variant == ApkVariantArm32 {
			continue
		}
		if best.Variant == ApkVariantArm32 && (asset.Variant == ApkVariantUniversal || asset.Variant == ApkVariantArm64) {
			best = &asset
		}
	}
	return best
}

// isNewerVersion compara si latest > current (versiones semánticas)
// Ej: "4.5.1" vs "4.6.0" devuelve true
func isNewerVersion(latest, current string) bool {
	// Normalizar: quitar prefijo 'v' y pesos
	latest = strings.TrimPrefix(latest, "v")
	current = strings.TrimPrefix(current, "v")
	
	// Dividir por '-' para ignorar sufijos como '-beta'
	latestParts := strings.Split(latest, "-")
	currentParts := strings.Split(current, "-")
	
	latestVersion := latestParts[0]
	currentVersion := currentParts[0]
	
	// Parsear versiones en partes numéricas
	latestNums := parseVersionString(latestVersion)
	currentNums := parseVersionString(currentVersion)
	
	// Normalizar a 3 partes
	for len(latestNums) < 3 {
		latestNums = append(latestNums, 0)
	}
	for len(currentNums) < 3 {
		currentNums = append(currentNums, 0)
	}
	
	// Comparar parte por parte
	for i := 0; i < 3; i++ {
		if latestNums[i] > currentNums[i] {
			return true
		}
		if latestNums[i] < currentNums[i] {
			return false
		}
	}
	
	// Si versiones base son iguales, preferir la que NO tenga sufijo (stable > preview)
	if len(latestParts) == 1 && len(currentParts) > 1 {
		return true
	}
	
	return false
}

// parseVersionString parsea una string de versión en partes numéricas
func parseVersionString(version string) []int {
	var nums []int
	re := regexp.MustCompile(`(\d+)`)
	matches := re.FindAllString(version, -1)
	for _, m := range matches {
		if num, err := strconv.Atoi(m); err == nil {
			nums = append(nums, num)
		}
	}
	if len(nums) == 0 {
		return []int{0}
	}
	return nums
}

// CheckGitHubUpdate verifica si hay una actualización disponible en GitHub
// channel: "stable" o "preview"
// currentVersion: versión actual de la app (ej: "4.5.1")
// repo: repositorio en formato "owner/repo" (opcional, default: DefaultGitHubRepo)
func CheckGitHubUpdate(channel, currentVersion, repo string) (*UpdateCheckResult, error) {
	if repo == "" {
		repo = DefaultGitHubRepo
	}
	
	client := NewGitHubClient(repo)
	
	var release *GitHubRelease
	var err error
	
	if channel == "preview" {
		// Obtener todas las releases y tomar la primera (más reciente)
		releases, err := client.GetAllReleases(10)
		if err != nil {
			return nil, fmt.Errorf("failed to get releases: %w", err)
		}
		if len(releases) == 0 {
			return &UpdateCheckResult{
				CurrentVersion: currentVersion,
				HasUpdate:      false,
				Error:          "No releases found",
			}, nil
		}
		release = &releases[0]
	} else {
		// Obtener la última release (stable)
		release, err = client.GetLatestRelease()
		if err != nil {
			return nil, fmt.Errorf("failed to get latest release: %w", err)
		}
	}
	
	// Parsear versión de la release
	tagName := release.TagName
	if tagName == "" {
		return &UpdateCheckResult{
			CurrentVersion: currentVersion,
			HasUpdate:      false,
			Error:          "Release has no tag name",
		}, nil
	}
	
	version := strings.TrimPrefix(tagName, "v")
	
	// Comprobar si hay actualización
	hasUpdate := isNewerVersion(version, currentVersion)
	
	if !hasUpdate {
		return &UpdateCheckResult{
			Version:        version,
			Changelog:      release.Body,
			DownloadURL:    release.HTMLURL,
			APKDownloadURL: nil,
			PublishedAt:    release.PublishedAt,
			IsPrerelease:   release.Prerelease,
			CurrentVersion: currentVersion,
			HasUpdate:      false,
		}, nil
	}
	
	// Seleccionar el mejor APK
	apkAssets := client.collectApkAssets(release.Assets)
	var apkURL *string
	if len(apkAssets) > 0 {
		bestApk := selectBestApk(apkAssets)
		if bestApk != nil {
			apkURL = &bestApk.URL
		}
	}
	
	return &UpdateCheckResult{
		Version:        version,
		Changelog:      release.Body,
		DownloadURL:    release.HTMLURL,
		APKDownloadURL: apkURL,
		PublishedAt:    release.PublishedAt,
		IsPrerelease:   release.Prerelease,
		CurrentVersion: currentVersion,
		HasUpdate:      true,
	}, nil
}

// checkGitHubUpdateJSON versión interna para ser llamada desde exports
// Recibe JSON: {"channel": "stable", "current_version": "4.5.1", "repo": "owner/repo"}
// Devuelve JSON con el resultado
func checkGitHubUpdateInternal(paramsJSON string) string {
	var params struct {
		Channel       string `json:"channel"`
		CurrentVersion string `json:"current_version"`
		Repo          string `json:"repo"`
	}
	
	if err := json.Unmarshal([]byte(paramsJSON), &params); err != nil {
		result := UpdateCheckResult{
			CurrentVersion: params.CurrentVersion,
			HasUpdate:      false,
			Error:          fmt.Sprintf("Invalid parameters: %v", err),
		}
		data, _ := json.Marshal(result)
		return string(data)
	}
	
	if params.CurrentVersion == "" {
		params.CurrentVersion = "0.0.0"
	}
	if params.Channel == "" {
		params.Channel = "stable"
	}
	
	result, err := CheckGitHubUpdate(params.Channel, params.CurrentVersion, params.Repo)
	if err != nil {
		// Crear resultado de error
		result = &UpdateCheckResult{
			CurrentVersion: params.CurrentVersion,
			HasUpdate:      false,
			Error:          err.Error(),
		}
	}
	
	data, _ := json.Marshal(result)
	return string(data)
}
