package manager

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/extensions/manifest"
)

func extractZipFiles(zipReader *zip.ReadCloser, destDir string) error {
	for _, f := range zipReader.File {
		if f.FileInfo().IsDir() {
			continue
		}
		relPath := filepath.Clean(f.Name)
		if strings.HasPrefix(relPath, "..") || filepath.IsAbs(relPath) {
			continue
		}
		destPath := filepath.Join(destDir, relPath)
		destDirPath := filepath.Dir(destPath)
		if err := os.MkdirAll(destDirPath, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", destDirPath, err)
		}
		destFile, err := os.Create(destPath)
		if err != nil {
			return fmt.Errorf("failed to create file %s: %w", destPath, err)
		}
		srcFile, err := f.Open()
		if err != nil {
			destFile.Close()
			return fmt.Errorf("failed to open file in archive: %w", err)
		}
		_, err = io.Copy(destFile, srcFile)
		srcFile.Close()
		destFile.Close()
		if err != nil {
			return fmt.Errorf("failed to extract file: %w", err)
		}
	}
	return nil
}

func (m *Manager) registerExtension(pManifest *manifest.ExtensionManifest, extDir, extDataDir string, enabled bool) *Extension {
	typeStr := ""
	for _, t := range pManifest.Types {
		if typeStr != "" {
			typeStr += ","
		}
		typeStr += string(t)
	}

	caps := copyCapabilities(pManifest.Capabilities)

	ext := &Extension{
		ID:           pManifest.Name,
		Name:         pManifest.DisplayName,
		Version:      pManifest.Version,
		Enabled:      enabled,
		Type:         typeStr,
		SourceDir:    extDir,
		DataDir:      extDataDir,
		Capabilities: caps,
		Manifest:     pManifest,
	}

	m.extensions[pManifest.Name] = ext
	return ext
}

func (m *Manager) upgradeExtension(zipReader *zip.ReadCloser, pManifest *manifest.ExtensionManifest, existing *Extension) (*Extension, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	extDir := existing.SourceDir
	extDataDir := existing.DataDir
	wasEnabled := existing.Enabled

	if extDir != "" {
		os.RemoveAll(extDir)
	}

	if err := os.MkdirAll(extDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create extension directory: %w", err)
	}

	if err := extractZipFiles(zipReader, extDir); err != nil {
		return nil, err
	}

	return m.registerExtension(pManifest, extDir, extDataDir, wasEnabled), nil
}
