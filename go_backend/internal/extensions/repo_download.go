package extensions

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func (es *ExtensionStore) DownloadExtension(ext RepoExtension) (string, error) {
	if ext.DownloadURL == "" {
		return "", fmt.Errorf("ERR_SIN_URL: sin URL de descarga para la extension %s", ext.ID)
	}

	// Verify installed version
	es.mu.RLock()
	if installedVer, ok := es.installed[ext.ID]; ok && installedVer == ext.Version {
		es.mu.RUnlock()
		return "", fmt.Errorf("extension %s v%s is already installed", ext.ID, ext.Version)
	}
	es.mu.RUnlock()

	// Download with size limit
	req, err := http.NewRequest("GET", ext.DownloadURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Bitly/1.0")

	resp, err := es.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("ERR_DESCARGA: fallo la descarga: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ERR_DESCARGA: la descarga devolvio HTTP %d", resp.StatusCode)
	}

	// Comprueba Content-Length si está disponible
	if resp.ContentLength > maxPackageSize {
		return "", fmt.Errorf("package too large: %d bytes (max %d)", resp.ContentLength, maxPackageSize)
	}

	// Lee con límite de tamaño
	limitedReader := io.LimitReader(resp.Body, maxPackageSize+1)
	data, err := io.ReadAll(limitedReader)
	if err != nil {
		return "", fmt.Errorf("ERR_DESCARGA: fallo la descarga: %w", err)
	}
	if int64(len(data)) > maxPackageSize {
		return "", fmt.Errorf("package exceeds size limit")
	}

	// SHA-256 verification
	if ext.SHA256 != "" {
		hash := sha256.Sum256(data)
		actual := hex.EncodeToString(hash[:])
		if !strings.EqualFold(actual, ext.SHA256) {
			return "", fmt.Errorf("SHA-256 mismatch: expected %s, got %s", ext.SHA256, actual)
		}
	}

	// Determine file name from the extension ID.
	extName := ext.ID

	// Save to file
	if err := os.MkdirAll(es.extensionsDir, 0755); err != nil {
		return "", err
	}
	filePath := filepath.Join(es.extensionsDir, extName+".spotiflac-ext")
	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return "", err
	}

	// Record installed version
	es.mu.Lock()
	es.installed[ext.ID] = ext.Version
	es.mu.Unlock()

	log.Printf("[ext-store] downloaded %s v%s (%d bytes, SHA-256 verified: %v)",
		ext.ID, ext.Version, len(data), ext.SHA256 != "")
	return filePath, nil
}

// ClearCache invalidates the local registry cache.
