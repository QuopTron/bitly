package store

import (
	"archive/zip"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
)

func (s *Store) DownloadExtension(extensionID, destPath string) error {
	registry, err := s.FetchRegistry(false)
	if err != nil {
		return err
	}

	var ext *storeExtension
	for _, e := range registry.Extensions {
		if e.ID == extensionID {
			ext = &e
			break
		}
	}
	if ext == nil {
		return fmt.Errorf("extension %s not found in store", extensionID)
	}

	downloadURL := ext.getDownloadURL()
	if err := requireHTTPSURL(downloadURL, "extension download"); err != nil {
		return err
	}

	body, statusCode, err := httpGet(downloadURL, downloadTimeout)
	if err != nil {
		return fmt.Errorf("download failed: %w", err)
	}
	if statusCode != http.StatusOK {
		return fmt.Errorf("download returned HTTP %d", statusCode)
	}

	if len(body) == 0 {
		return fmt.Errorf("downloaded file is empty")
	}

	destDir := filepath.Dir(destPath)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	tmpPath := destPath + ".part"
	if err := os.WriteFile(tmpPath, body, 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}
	if err := os.Rename(tmpPath, destPath); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("failed to rename downloaded file: %w", err)
	}

	zipReader, zipErr := zip.OpenReader(destPath)
	if zipErr != nil {
		os.Remove(destPath)
		return fmt.Errorf("downloaded file is not a valid zip package: %w", zipErr)
	}

	foundManifest := false
	foundIndex := false
	for _, f := range zipReader.File {
		name := filepath.Base(f.Name)
		if name == "manifest.json" {
			foundManifest = true
		}
		if name == "index.js" {
			foundIndex = true
		}
	}
	zipReader.Close()

	if !foundManifest || !foundIndex {
		os.Remove(destPath)
		return fmt.Errorf("downloaded file is not a valid .bitly-ext package: missing manifest.json or index.js")
	}
	return nil
}
